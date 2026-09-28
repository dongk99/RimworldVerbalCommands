using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Threading;
using System.Threading.Tasks;

namespace VerbalCommands.RouterScript
{
	// Brief 17: runs a checked script. One Runner per RunAsync call, so runs never share variables.
	//
	// The script's own calls don't use the C# stack: every function call is a Frame in a list, and
	// one loop steps through instructions. So deep recursion can't overflow the game's stack (the
	// depth limit stops it first), and waiting on a host function is a single await in that loop.
	internal sealed class Runner
	{
		// How often (in steps) the clock and the cancellation token are looked at.
		private const int CheckEvery = 256;

		private sealed class Frame
		{
			public FunctionCode code;
			public int pc;
			public Value[] locals;
			public List<Value> stack = new List<Value>();
			public List<LoopState> loops = new List<LoopState>();
		}

		private sealed class LoopState
		{
			public List<Value> items;   // a copy taken when the loop starts
			public int next;
		}

		// A script error with its line; only ever caught inside this class.
		private sealed class Stop : Exception
		{
			public readonly int line;

			public Stop(int line, string message) : base(message)
			{
				this.line = line;
			}
		}

		private readonly Script script;
		private readonly CompiledScript program;
		private readonly ScriptOptions options;
		private readonly CancellationToken hostToken;
		private readonly List<Frame> frames = new List<Frame>();
		private Value[] globals;
		private long steps;
		private int callDepth;
		private int currentLine;
		private Stopwatch watch;
		private CancellationTokenSource timeoutSource;
		private CancellationTokenSource runSource;

		public Runner(Script script, ScriptOptions options, CancellationToken token)
		{
			this.script = script;
			program = script.program;
			this.options = options;
			hostToken = token;
		}

		public async Task<ScriptResult> RunAsync(string entryFunction, IList<Value> args)
		{
			watch = Stopwatch.StartNew();
			timeoutSource = options.timeLimit > TimeSpan.Zero ? new CancellationTokenSource(options.timeLimit) : new CancellationTokenSource();
			runSource = CancellationTokenSource.CreateLinkedTokenSource(hostToken, timeoutSource.Token);
			try
			{
				FunctionCode entry = null;
				Value[] entryArgs = new Value[args != null ? args.Count : 0];
				for (int i = 0; i < entryArgs.Length; i++)
				{
					entryArgs[i] = args[i] ?? Value.None;
				}
				if (!string.IsNullOrEmpty(entryFunction))
				{
					int index;
					if (!program.functionIndex.TryGetValue(entryFunction, out index))
					{
						return Fail(0, "there is no function named '" + entryFunction + "' to run.");
					}
					entry = program.functions[index];
					if (entryArgs.Length != entry.paramCount)
					{
						return Fail(entry.line, "'" + entryFunction + "' " + Compiler.NeedsText(entry.paramCount, entry.paramCount) + ", got " + entryArgs.Length + ".");
					}
				}

				globals = new Value[program.globalCount];
				await Execute(program.topLevel, new Value[0]);
				Value result = Value.None;
				if (entry != null)
				{
					result = await Execute(entry, entryArgs);
				}
				return ScriptResult.Success(result);
			}
			catch (Stop stop)
			{
				return Fail(stop.line, stop.Message);
			}
			catch (Exception)
			{
				// A mistake in the interpreter itself; still a plain message, never exception text.
				return Fail(currentLine, "the script stopped because of a problem inside the interpreter.");
			}
			finally
			{
				runSource.Dispose();
				timeoutSource.Dispose();
			}
		}

		private ScriptResult Fail(int line, string message)
		{
			List<string> errors = new List<string>();
			errors.Add(Script.Where(script.fileName, line) + message);
			return ScriptResult.Failed(errors);
		}

		// Runs code until it returns; nested script calls are frames on the same list.
		private async Task<Value> Execute(FunctionCode code, Value[] args)
		{
			int baseCount = frames.Count;
			PushFrame(code, args);
			try
			{
				while (true)
				{
					Frame f = frames[frames.Count - 1];
					Instruction ins = f.code.code[f.pc++];
					currentLine = ins.line;
					steps++;
					if (steps > options.maxSteps)
					{
						throw StepLimit();
					}
					if (steps % CheckEvery == 0)
					{
						CheckClock();
					}

					List<Value> stack = f.stack;
					switch (ins.op)
					{
						case Op.Const:
							stack.Add(ins.value);
							break;
						case Op.NewList:
						{
							List<Value> items = stack.GetRange(stack.Count - ins.a, ins.a);
							stack.RemoveRange(stack.Count - ins.a, ins.a);
							stack.Add(Value.WrapList(items));
							break;
						}
						case Op.NewDict:
						{
							int start = stack.Count - ins.a * 2;
							ScriptDict dict = new ScriptDict();
							for (int i = 0; i < ins.a; i++)
							{
								Value key = stack[start + i * 2];
								if (key.kind != ValueKind.Text)
								{
									throw new ScriptError("dict keys must be text, got " + Value.Describe(key) + ".");
								}
								dict.Set(key.AsText, stack[start + i * 2 + 1]);
							}
							stack.RemoveRange(start, ins.a * 2);
							stack.Add(Value.WrapDict(dict));
							break;
						}
						case Op.Load:
						{
							Value v = null;
							if (ins.a >= 0)
							{
								v = f.locals[ins.a];
							}
							if (v == null && ins.b >= 0)
							{
								v = globals[ins.b];
							}
							if (v == null)
							{
								throw new ScriptError("'" + ins.name + "' was used before it was given a value.");
							}
							stack.Add(v);
							break;
						}
						case Op.StoreLocal:
							f.locals[ins.a] = Pop(stack);
							break;
						case Op.StoreGlobal:
							globals[ins.b] = Pop(stack);
							break;
						case Op.GetIndex:
						{
							Value index = Pop(stack);
							Value target = Pop(stack);
							stack.Add(Operations.GetItem(target, index));
							break;
						}
						case Op.SetIndex:
						{
							Value value = Pop(stack);
							Value index = Pop(stack);
							Value target = Pop(stack);
							Operations.SetItem(target, index, value);
							break;
						}
						case Op.Binary:
						{
							Value right = Pop(stack);
							Value left = Pop(stack);
							stack.Add(Operations.Binary(ins.name, left, right, this));
							break;
						}
						case Op.Negate:
						{
							Value v = Pop(stack);
							if (v.kind != ValueKind.Number)
							{
								throw new ScriptError("'-' needs a number, got " + Value.Describe(v) + ".");
							}
							stack.Add(Value.FromNumber(-v.AsNumber));
							break;
						}
						case Op.Not:
							stack.Add(Value.FromBool(!Pop(stack).IsTruthy));
							break;
						case Op.ToBool:
							stack.Add(Value.FromBool(Pop(stack).IsTruthy));
							break;
						case Op.Jump:
							f.pc = ins.a;
							break;
						case Op.JumpIfFalse:
							if (!Pop(stack).IsTruthy)
							{
								f.pc = ins.a;
							}
							break;
						case Op.Pop:
							Pop(stack);
							break;
						case Op.CallBuiltin:
							stack.Add(ins.builtin.handler(this, PopArgs(stack, ins.b)) ?? Value.None);
							break;
						case Op.CallHost:
						{
							Value[] hostArgs = PopArgs(stack, ins.b);
							Value result = await CallHost(ins, hostArgs);
							stack.Add(result);
							break;
						}
						case Op.CallScript:
						{
							Value[] callArgs = PopArgs(stack, ins.b);
							if (callDepth + 1 > options.maxCallDepth)
							{
								throw new ScriptError("functions called each other too deeply (more than "
									+ options.maxCallDepth.ToString("N0", CultureInfo.InvariantCulture)
									+ " levels); check '" + ins.name + "', which may keep calling itself.");
							}
							PushFrame(program.functions[ins.a], callArgs);
							break;
						}
						case Op.Return:
						{
							Value result = Pop(stack);
							frames.RemoveAt(frames.Count - 1);
							if (f.code != program.topLevel)
							{
								callDepth--;
							}
							if (frames.Count == baseCount)
							{
								return result;
							}
							frames[frames.Count - 1].stack.Add(result);
							break;
						}
						case Op.ForBegin:
						{
							Value v = Pop(stack);
							LoopState loop = new LoopState();
							if (v.kind == ValueKind.List)
							{
								loop.items = new List<Value>(v.AsList);
							}
							else if (v.kind == ValueKind.Dict)
							{
								loop.items = new List<Value>();
								foreach (string key in v.AsDict.Keys)
								{
									loop.items.Add(Value.FromText(key));
								}
							}
							else
							{
								throw new ScriptError("'for' needs a list or a dict to go through, got " + Value.Describe(v) + ".");
							}
							Charge(loop.items.Count);
							f.loops.Add(loop);
							break;
						}
						case Op.ForNext:
						{
							LoopState loop = f.loops[f.loops.Count - 1];
							if (loop.next < loop.items.Count)
							{
								stack.Add(loop.items[loop.next]);
								loop.next++;
							}
							else
							{
								f.pc = ins.a;
							}
							break;
						}
						case Op.ForEnd:
							f.loops.RemoveAt(f.loops.Count - 1);
							break;
					}
				}
			}
			catch (ScriptError e)
			{
				throw new Stop(currentLine, e.Message);
			}
		}

		private void PushFrame(FunctionCode code, Value[] args)
		{
			Frame frame = new Frame();
			frame.code = code;
			frame.locals = new Value[Math.Max(code.localCount, args.Length)];
			for (int i = 0; i < args.Length; i++)
			{
				frame.locals[i] = args[i];
			}
			if (code != program.topLevel)
			{
				callDepth++;
			}
			frames.Add(frame);
		}

		private static Value Pop(List<Value> stack)
		{
			Value v = stack[stack.Count - 1];
			stack.RemoveAt(stack.Count - 1);
			return v;
		}

		private static Value[] PopArgs(List<Value> stack, int count)
		{
			Value[] args = new Value[count];
			int start = stack.Count - count;
			for (int i = 0; i < count; i++)
			{
				args[i] = stack[start + i];
			}
			stack.RemoveRange(start, count);
			return args;
		}

		// ---- Host functions ----

		private async Task<Value> CallHost(Instruction ins, Value[] args)
		{
			HostFunction h = ins.host;
			Task<Value> task;
			try
			{
				task = h.handler(args, runSource.Token);
			}
			catch (Exception e)
			{
				throw HostFailure(ins, e);
			}

			if (task != null && !task.IsCompleted)
			{
				using (CancellationTokenSource waitSource = CancellationTokenSource.CreateLinkedTokenSource(runSource.Token))
				{
					Task delay = Task.Delay(Timeout.Infinite, waitSource.Token);
					Task first = await Task.WhenAny(task, delay);
					waitSource.Cancel();
					if (first != task)
					{
						// Stopped or out of time while the host was still working. Nobody waits for the
						// host's task any more; its failure (if any) is read so it isn't left unobserved.
						Task observed = task.ContinueWith(t => { Exception ignored = t.Exception; }, TaskContinuationOptions.OnlyOnFaulted | TaskContinuationOptions.ExecuteSynchronously);
						throw StoppedOrTooLong(ins.line, " while waiting for '" + h.name + "'");
					}
				}
			}

			// Host time counts: a slow host function that finished can still use up the time limit.
			currentLine = ins.line;
			CheckClock();

			if (task == null)
			{
				return Value.None;
			}
			if (task.IsFaulted)
			{
				Exception e = task.Exception.InnerException ?? task.Exception;
				throw HostFailure(ins, e);
			}
			if (task.IsCanceled)
			{
				if (runSource.IsCancellationRequested)
				{
					throw StoppedOrTooLong(ins.line, " while waiting for '" + h.name + "'");
				}
				throw new Stop(ins.line, "'" + h.name + "' did not finish.");
			}
			return task.Result ?? Value.None;
		}

		private Stop HostFailure(Instruction ins, Exception e)
		{
			ScriptError plain = e as ScriptError;
			if (plain != null && !string.IsNullOrEmpty(plain.Message))
			{
				return new Stop(ins.line, plain.Message);
			}
			if (e is OperationCanceledException && runSource.IsCancellationRequested)
			{
				return StoppedOrTooLong(ins.line, " while waiting for '" + ins.host.name + "'");
			}
			return new Stop(ins.line, "'" + ins.host.name + "' failed.");
		}

		// ---- Limits ----

		// Built-ins and operators that copy a lot of items pay for it: one step per 100 items.
		internal void Charge(long items)
		{
			steps += items / 100;
			if (steps > options.maxSteps)
			{
				throw StepLimit();
			}
		}

		private void CheckClock()
		{
			if (hostToken.IsCancellationRequested)
			{
				throw StoppedOrTooLong(currentLine, "");
			}
			if (options.timeLimit > TimeSpan.Zero && watch.Elapsed > options.timeLimit)
			{
				throw TooLong("");
			}
		}

		private Stop StoppedOrTooLong(int line, string waiting)
		{
			currentLine = line;
			if (hostToken.IsCancellationRequested)
			{
				if (waiting.Length > 0)
				{
					return new Stop(line, "the script was stopped before it finished" + waiting + ".");
				}
				// Point at the running loop (a stable line) rather than wherever in it the stop landed.
				int loopLine = RunningLoopLine();
				if (loopLine > 0)
				{
					return new Stop(loopLine, "the script was stopped before it finished; it was in the loop that starts here.");
				}
				return new Stop(line, "the script was stopped before it finished.");
			}
			return TooLong(waiting);
		}

		private Stop TooLong(string waiting)
		{
			string message = "the script ran too long (over " + FormatSeconds(options.timeLimit) + ")" + waiting;
			return WithLoopHint(message);
		}

		private Stop StepLimit()
		{
			return WithLoopHint("the script ran too long (over " + options.maxSteps.ToString("N0", CultureInfo.InvariantCulture) + " steps)");
		}

		// Points at the innermost loop that is running (in this function or any caller), since that
		// is almost always what ran away.
		private Stop WithLoopHint(string message)
		{
			int loopLine = RunningLoopLine();
			if (loopLine > 0)
			{
				return new Stop(loopLine, message + "; check the loop that starts here.");
			}
			return new Stop(currentLine, message + ".");
		}

		// Header line of the innermost loop running now, in this function or any caller; 0 if none.
		private int RunningLoopLine()
		{
			for (int i = frames.Count - 1; i >= 0; i--)
			{
				Frame f = frames[i];
				int at = Math.Max(0, Math.Min(f.pc - 1, f.code.code.Count - 1));
				int loopLine = f.code.code.Count > 0 ? f.code.code[at].loopLine : 0;
				if (loopLine > 0)
				{
					return loopLine;
				}
			}
			return 0;
		}

		private static string FormatSeconds(TimeSpan t)
		{
			double seconds = Math.Round(t.TotalSeconds, 3);
			return Value.FormatNumber(seconds) + (seconds == 1 ? " second" : " seconds");
		}
	}
}
