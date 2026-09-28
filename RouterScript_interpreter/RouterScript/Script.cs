using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace VerbalCommands.RouterScript
{
	// Brief 17: the C# side of the router language.
	//
	//   ScriptHost host = new ScriptHost();
	//   host.Register("log", 1, args => { ...; return Value.None; });
	//   host.RegisterAsync("ask_router_model", 2, (args, token) => SomethingAsync(args, token));
	//   Script script = Script.Load("router.txt", File.ReadAllText(path), host);
	//   if (!script.Ok) { ...script.errors... }
	//   ScriptResult result = await script.RunAsync("route", new Value[] { order }, token);
	//
	// Load checks the whole file first (syntax, and every call names a known function with the right
	// number of values) and keeps every problem found. RunAsync runs the top-level lines (which give
	// the global variables their values), then calls the entry function. It never throws for script
	// problems: everything, including the limits, comes back as a ScriptResult with plain messages.
	//
	// Threads: RunAsync runs on the calling thread until a host function returns a Task that isn't
	// finished yet; it awaits that Task without blocking, and continues wherever the await resumes
	// (the caller's SynchronizationContext if there is one, otherwise a thread-pool thread). A host
	// that wants the whole script off its main thread calls it inside Task.Run.
	public sealed class Script
	{
		public readonly string fileName;

		// The problems the check found, as "router.txt line 3: ..." lines. Empty when the file is fine.
		public readonly List<string> errors;

		public ScriptOptions options = new ScriptOptions();

		internal readonly CompiledScript program;

		private Script(string fileName, List<string> errors, CompiledScript program)
		{
			this.fileName = fileName;
			this.errors = errors;
			this.program = program;
		}

		public bool Ok
		{
			get { return errors.Count == 0; }
		}

		// fileName is only used in messages ("router.txt line 3: ..."). host may be null (built-ins only).
		public static Script Load(string fileName, string source, ScriptHost host)
		{
			ProblemList problems = new ProblemList();
			CompiledScript program = null;
			try
			{
				List<CodeLine> lines = Lexer.Read(source ?? "", problems);
				List<Stmt> statements = Parser.Parse(lines, problems);
				program = Compiler.Compile(statements, host, problems);
			}
			catch (Exception)
			{
				// Not a script problem: a mistake in the interpreter itself. Still no exception text.
				problems.Add(0, "the file could not be checked because of a problem inside the interpreter.");
			}
			return new Script(fileName, problems.Format(fileName), problems.Count == 0 ? program : null);
		}

		// Whether the script defines this function (for picking an entry point).
		public bool HasFunction(string name)
		{
			return program != null && program.functionIndex.ContainsKey(name);
		}

		// Runs the top level, then entryFunction(args) unless entryFunction is null or empty. The
		// result's value is the entry function's return value (none when there is no entry function).
		public Task<ScriptResult> RunAsync(string entryFunction, IList<Value> args, CancellationToken token)
		{
			if (!Ok)
			{
				return Task.FromResult(ScriptResult.Failed(new List<string>(errors)));
			}
			Runner runner = new Runner(this, options ?? new ScriptOptions(), token);
			return runner.RunAsync(entryFunction, args);
		}

		// "router.txt line 3: " (or "router.txt: " for problems that belong to no line).
		internal static string Where(string fileName, int line)
		{
			return line > 0 ? fileName + " line " + line + ": " : fileName + ": ";
		}
	}

	public sealed class ScriptOptions
	{
		// Evaluated steps (roughly one per operator, value, call or jump) before the script is stopped.
		public long maxSteps = 1000000;

		// Functions running inside each other (recursion counts every level).
		public int maxCallDepth = 200;

		// Wall-clock time for the whole run, host call time included. TimeSpan.Zero = no limit.
		public TimeSpan timeLimit = TimeSpan.Zero;
	}

	public sealed class ScriptResult
	{
		public bool ok;
		public Value value = Value.None;
		public List<string> errors = new List<string>();

		internal static ScriptResult Success(Value value)
		{
			ScriptResult r = new ScriptResult();
			r.ok = true;
			r.value = value ?? Value.None;
			return r;
		}

		internal static ScriptResult Failed(List<string> errors)
		{
			ScriptResult r = new ScriptResult();
			r.ok = false;
			r.errors = errors;
			return r;
		}

		// All errors, one per line.
		public string ErrorText
		{
			get { return string.Join("\n", errors.ToArray()); }
		}
	}

	// Thrown by a host function to fail with a plain message the player can read; the script stops
	// with "router.txt line N: <message>". Any other exception from a host function is reported as
	// "'name' failed." with nothing of the exception shown.
	public sealed class ScriptError : Exception
	{
		public ScriptError(string plainMessage) : base(plainMessage)
		{
		}
	}

	public sealed class HostFunction
	{
		public string name;
		public int minArgs;
		public int maxArgs;
		internal Func<Value[], CancellationToken, Task<Value>> handler;
	}

	// The functions the host (the mod, or the test runner) gives the script. The script can't reach
	// files, network or processes except through these.
	public sealed class ScriptHost
	{
		private readonly Dictionary<string, HostFunction> functions = new Dictionary<string, HostFunction>(StringComparer.Ordinal);

		// A function that answers immediately.
		public void Register(string name, int argCount, Func<Value[], Value> handler)
		{
			Register(name, argCount, argCount, handler);
		}

		public void Register(string name, int minArgs, int maxArgs, Func<Value[], Value> handler)
		{
			if (handler == null)
			{
				throw new ArgumentNullException("handler");
			}
			Add(name, minArgs, maxArgs, (args, token) => Task.FromResult(handler(args)));
		}

		// A function that answers later. The token is cancelled when the run is cancelled or runs
		// out of time; the script stops waiting at that moment either way.
		public void RegisterAsync(string name, int argCount, Func<Value[], CancellationToken, Task<Value>> handler)
		{
			RegisterAsync(name, argCount, argCount, handler);
		}

		public void RegisterAsync(string name, int minArgs, int maxArgs, Func<Value[], CancellationToken, Task<Value>> handler)
		{
			if (handler == null)
			{
				throw new ArgumentNullException("handler");
			}
			Add(name, minArgs, maxArgs, handler);
		}

		public bool Has(string name)
		{
			return functions.ContainsKey(name);
		}

		internal HostFunction Find(string name)
		{
			HostFunction f;
			return functions.TryGetValue(name, out f) ? f : null;
		}

		// Host mistakes (bad names, clashes) throw: they are C# bugs, not script problems.
		private void Add(string name, int minArgs, int maxArgs, Func<Value[], CancellationToken, Task<Value>> handler)
		{
			if (!IsValidName(name))
			{
				throw new ArgumentException("'" + name + "' is not a valid function name");
			}
			if (Lexer.Keywords.Contains(name))
			{
				throw new ArgumentException("'" + name + "' is a word of the language");
			}
			if (Builtins.Find(name) != null)
			{
				throw new ArgumentException("'" + name + "' is a built-in function");
			}
			if (functions.ContainsKey(name))
			{
				throw new ArgumentException("'" + name + "' is already registered");
			}
			if (minArgs < 0 || maxArgs < minArgs)
			{
				throw new ArgumentException("bad argument count for '" + name + "'");
			}
			HostFunction f = new HostFunction();
			f.name = name;
			f.minArgs = minArgs;
			f.maxArgs = maxArgs;
			f.handler = handler;
			functions[name] = f;
		}

		private static bool IsValidName(string name)
		{
			if (string.IsNullOrEmpty(name) || char.IsDigit(name[0]))
			{
				return false;
			}
			foreach (char c in name)
			{
				if (!(c < 128 && char.IsLetterOrDigit(c) || c == '_'))
				{
					return false;
				}
			}
			return true;
		}
	}
}
