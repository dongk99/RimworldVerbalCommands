using System.Collections.Generic;

namespace VerbalCommands.RouterScript
{
	internal enum Op
	{
		Const,          // push value
		NewList,        // pop a items, push a new list
		NewDict,        // pop a key/value pairs, push a new dict
		Load,           // push local a (if set), else global b; neither -> "used before it was given a value"
		StoreLocal,     // pop into local a
		StoreGlobal,    // pop into global b
		GetIndex,       // pop index, target; push target[index]
		SetIndex,       // pop value, index, target; target[index] = value
		Binary,         // pop right, left; push left <name> right
		Negate,
		Not,
		ToBool,         // replace the top value with its truthiness
		Jump,           // go to a
		JumpIfFalse,    // pop; go to a when it's false
		Pop,
		CallBuiltin,    // b values
		CallHost,       // b values
		CallScript,     // function a, b values
		Return,         // pop the return value
		ForBegin,       // pop list/dict, start a loop over a copy of its items/keys
		ForNext,        // push the next item, or end the loop and go to a
		ForEnd          // drop the innermost loop
	}

	internal sealed class Instruction
	{
		public Op op;
		public int a;
		public int b;
		public Value value;
		public string name;             // variable name, operator or function name (for messages)
		public BuiltinFunction builtin;
		public HostFunction host;
		public int line;
		public int loopLine;            // header line of the innermost loop around this, 0 if none
	}

	internal sealed class FunctionCode
	{
		public string name;             // null for the top level
		public int line;
		public int paramCount;
		public int localCount;
		public List<Instruction> code = new List<Instruction>();
	}

	internal sealed class CompiledScript
	{
		public FunctionCode topLevel;
		public List<FunctionCode> functions = new List<FunctionCode>();
		public Dictionary<string, int> functionIndex = new Dictionary<string, int>();
		public int globalCount;
	}

	// Brief 17: the check and the compiler in one walk. It reports every call to an unknown function,
	// every wrong number of values, names that are never given a value, and misplaced break /
	// continue / return / function, and turns the statements into instructions for the Runner.
	internal sealed class Compiler
	{
		private sealed class LoopContext
		{
			public int line;
			public int continueTarget;
			public List<Instruction> breaks = new List<Instruction>();
		}

		private readonly ProblemList problems;
		private readonly ScriptHost host;
		private readonly CompiledScript program = new CompiledScript();
		private readonly Dictionary<string, FunctionStmt> functionStmts = new Dictionary<string, FunctionStmt>();
		private readonly Dictionary<string, int> globals = new Dictionary<string, int>();

		// When a line failed to parse, a name given its value on that line looks unassigned; the
		// "never given a value" check is skipped then, so it doesn't report the same mistake twice.
		private bool hadSyntaxProblems;

		// The function being compiled (locals == null at the top level).
		private FunctionCode current;
		private Dictionary<string, int> locals;
		private List<LoopContext> loops;

		private Compiler(ScriptHost host, ProblemList problems)
		{
			this.host = host;
			this.problems = problems;
		}

		public static CompiledScript Compile(List<Stmt> statements, ScriptHost host, ProblemList problems)
		{
			Compiler c = new Compiler(host, problems);
			c.hadSyntaxProblems = problems.Count > 0;
			return c.CompileAll(statements);
		}

		private CompiledScript CompileAll(List<Stmt> statements)
		{
			// Every function is known before any code is compiled, so functions can be called above
			// the line that defines them.
			foreach (Stmt s in statements)
			{
				FunctionStmt f = s as FunctionStmt;
				if (f == null)
				{
					continue;
				}
				if (Builtins.Find(f.name) != null)
				{
					problems.Add(f.line, "'" + f.name + "' is a built-in function; pick another name for this function.");
				}
				else if (host != null && host.Find(f.name) != null)
				{
					problems.Add(f.line, "'" + f.name + "' is a function the mod provides; pick another name for this function.");
				}
				else if (functionStmts.ContainsKey(f.name))
				{
					problems.Add(f.line, "there is already a function named '" + f.name + "' (line " + functionStmts[f.name].line + ").");
				}
				else
				{
					functionStmts[f.name] = f;
					program.functionIndex[f.name] = program.functions.Count;
					FunctionCode code = new FunctionCode();
					code.name = f.name;
					code.line = f.line;
					code.paramCount = f.parameters.Count;
					program.functions.Add(code);
				}
			}

			// Global variables: every name given a value at the top level (not inside functions).
			CollectAssigned(statements, globals);
			program.globalCount = globals.Count;

			program.topLevel = new FunctionCode();
			program.topLevel.line = 1;
			BeginFunction(program.topLevel, null);
			CompileBlock(statements);
			int lastLine = statements.Count > 0 ? statements[statements.Count - 1].line : 1;
			Emit(Op.Const, lastLine).value = Value.None;
			Emit(Op.Return, lastLine);

			foreach (Stmt s in statements)
			{
				FunctionStmt f = s as FunctionStmt;
				if (f != null && functionStmts.ContainsKey(f.name) && functionStmts[f.name] == f)
				{
					CompileFunction(f, program.functions[program.functionIndex[f.name]]);
				}
				else if (f != null)
				{
					// A refused function (duplicate or reserved name): still check its body.
					CompileFunction(f, new FunctionCode());
				}
			}
			return program;
		}

		private void CompileFunction(FunctionStmt f, FunctionCode code)
		{
			FunctionCode savedCurrent = current;
			Dictionary<string, int> savedLocals = locals;
			List<LoopContext> savedLoops = loops;

			Dictionary<string, int> names = new Dictionary<string, int>();
			foreach (string p in f.parameters)
			{
				if (names.ContainsKey(p))
				{
					problems.Add(f.line, "the function '" + f.name + "' takes '" + p + "' twice.");
					continue;
				}
				names[p] = names.Count;
			}
			code.paramCount = f.parameters.Count;
			CollectAssigned(f.body, names);
			BeginFunction(code, names);
			CompileBlock(f.body);
			Emit(Op.Const, f.line).value = Value.None;
			Emit(Op.Return, f.line);
			code.localCount = names.Count;

			current = savedCurrent;
			locals = savedLocals;
			loops = savedLoops;
		}

		private void BeginFunction(FunctionCode code, Dictionary<string, int> localNames)
		{
			current = code;
			locals = localNames;
			loops = new List<LoopContext>();
		}

		// Names given a value by '=' or 'for' in these statements and their blocks (not in functions).
		private static void CollectAssigned(List<Stmt> statements, Dictionary<string, int> into)
		{
			foreach (Stmt s in statements)
			{
				AssignStmt a = s as AssignStmt;
				if (a != null)
				{
					NameExpr n = a.target as NameExpr;
					if (n != null && !into.ContainsKey(n.name))
					{
						into[n.name] = into.Count;
					}
					continue;
				}
				ForStmt f = s as ForStmt;
				if (f != null)
				{
					if (!into.ContainsKey(f.variable))
					{
						into[f.variable] = into.Count;
					}
					CollectAssigned(f.body, into);
					continue;
				}
				WhileStmt w = s as WhileStmt;
				if (w != null)
				{
					CollectAssigned(w.body, into);
					continue;
				}
				IfStmt i = s as IfStmt;
				if (i != null)
				{
					foreach (List<Stmt> block in i.blocks)
					{
						CollectAssigned(block, into);
					}
					if (i.elseBlock != null)
					{
						CollectAssigned(i.elseBlock, into);
					}
				}
			}
		}

		// ---- Statements ----

		private void CompileBlock(List<Stmt> statements)
		{
			foreach (Stmt s in statements)
			{
				CompileStatement(s);
			}
		}

		private void CompileStatement(Stmt s)
		{
			AssignStmt assign = s as AssignStmt;
			if (assign != null)
			{
				NameExpr n = assign.target as NameExpr;
				if (n != null)
				{
					CompileExpr(assign.value);
					StoreName(n.name, s.line);
				}
				else
				{
					IndexExpr ix = (IndexExpr)assign.target;
					CompileExpr(ix.target);
					CompileExpr(ix.index);
					CompileExpr(assign.value);
					Emit(Op.SetIndex, s.line);
				}
				return;
			}

			ExprStmt es = s as ExprStmt;
			if (es != null)
			{
				CompileExpr(es.expr);
				Emit(Op.Pop, s.line);
				return;
			}

			IfStmt ifs = s as IfStmt;
			if (ifs != null)
			{
				List<Instruction> toEnd = new List<Instruction>();
				for (int i = 0; i < ifs.conditions.Count; i++)
				{
					CompileExpr(ifs.conditions[i]);
					Instruction skip = Emit(Op.JumpIfFalse, ifs.conditions[i].line);
					CompileBlock(ifs.blocks[i]);
					if (i < ifs.conditions.Count - 1 || ifs.elseBlock != null)
					{
						toEnd.Add(Emit(Op.Jump, s.line));
					}
					skip.a = Here();
				}
				if (ifs.elseBlock != null)
				{
					CompileBlock(ifs.elseBlock);
				}
				foreach (Instruction j in toEnd)
				{
					j.a = Here();
				}
				return;
			}

			WhileStmt ws = s as WhileStmt;
			if (ws != null)
			{
				LoopContext loop = new LoopContext();
				loop.line = s.line;
				loop.continueTarget = Here();
				loops.Add(loop);
				CompileExpr(ws.condition);
				Instruction exit = Emit(Op.JumpIfFalse, s.line);
				CompileBlock(ws.body);
				Emit(Op.Jump, s.line).a = loop.continueTarget;
				loops.RemoveAt(loops.Count - 1);
				exit.a = Here();
				foreach (Instruction b in loop.breaks)
				{
					b.a = Here();
				}
				return;
			}

			ForStmt fs = s as ForStmt;
			if (fs != null)
			{
				CompileExpr(fs.items);
				Emit(Op.ForBegin, s.line);
				LoopContext loop = new LoopContext();
				loop.line = s.line;
				loop.continueTarget = Here();
				loops.Add(loop);
				Instruction next = Emit(Op.ForNext, s.line);
				StoreName(fs.variable, s.line);
				CompileBlock(fs.body);
				Emit(Op.Jump, s.line).a = loop.continueTarget;
				loops.RemoveAt(loops.Count - 1);
				next.a = Here();
				foreach (Instruction b in loop.breaks)
				{
					b.a = Here();
				}
				Emit(Op.ForEnd, s.line);
				return;
			}

			if (s is BreakStmt || s is ContinueStmt)
			{
				bool isBreak = s is BreakStmt;
				if (loops.Count == 0)
				{
					problems.Add(s.line, "'" + (isBreak ? "break" : "continue") + "' can only be used inside a loop.");
					return;
				}
				LoopContext loop = loops[loops.Count - 1];
				Instruction jump = Emit(Op.Jump, s.line);
				if (isBreak)
				{
					loop.breaks.Add(jump);
				}
				else
				{
					jump.a = loop.continueTarget;
				}
				return;
			}

			ReturnStmt rs = s as ReturnStmt;
			if (rs != null)
			{
				if (locals == null)
				{
					problems.Add(s.line, "'return' can only be used inside a function.");
					return;
				}
				if (rs.value != null)
				{
					CompileExpr(rs.value);
				}
				else
				{
					Emit(Op.Const, s.line).value = Value.None;
				}
				Emit(Op.Return, s.line);
				return;
			}

			FunctionStmt fn = s as FunctionStmt;
			if (fn != null)
			{
				if (!fn.topLevel)
				{
					problems.Add(s.line, "functions can only be made at the top level, not inside a block.");
					// Still check its body, so its problems are reported too.
					CompileFunction(fn, new FunctionCode());
				}
				return;
			}
		}

		private void StoreName(string name, int line)
		{
			if (locals != null)
			{
				Emit(Op.StoreLocal, line).a = locals[name];
			}
			else
			{
				Emit(Op.StoreGlobal, line).b = globals[name];
			}
		}

		// ---- Expressions ----

		private void CompileExpr(Expr e)
		{
			LiteralExpr literal = e as LiteralExpr;
			if (literal != null)
			{
				Emit(Op.Const, e.line).value = literal.value;
				return;
			}

			NameExpr n = e as NameExpr;
			if (n != null)
			{
				int localSlot = -1;
				int globalSlot = -1;
				if (locals != null && locals.ContainsKey(n.name))
				{
					localSlot = locals[n.name];
				}
				if (globals.ContainsKey(n.name))
				{
					globalSlot = globals[n.name];
				}
				if (localSlot < 0 && globalSlot < 0)
				{
					if (IsFunctionName(n.name))
					{
						problems.Add(e.line, "'" + n.name + "' is a function; call it with its values in brackets, like " + n.name + "(...).");
					}
					else if (!hadSyntaxProblems)
					{
						problems.Add(e.line, "'" + n.name + "' is never given a value.");
					}
				}
				Instruction load = Emit(Op.Load, e.line);
				load.a = localSlot;
				load.b = globalSlot;
				load.name = n.name;
				return;
			}

			ListExpr list = e as ListExpr;
			if (list != null)
			{
				foreach (Expr item in list.items)
				{
					CompileExpr(item);
				}
				Emit(Op.NewList, e.line).a = list.items.Count;
				return;
			}

			DictExpr dict = e as DictExpr;
			if (dict != null)
			{
				for (int i = 0; i < dict.keys.Count; i++)
				{
					CompileExpr(dict.keys[i]);
					CompileExpr(dict.values[i]);
				}
				Emit(Op.NewDict, e.line).a = dict.keys.Count;
				return;
			}

			IndexExpr ix = e as IndexExpr;
			if (ix != null)
			{
				CompileExpr(ix.target);
				CompileExpr(ix.index);
				Emit(Op.GetIndex, e.line);
				return;
			}

			CallExpr call = e as CallExpr;
			if (call != null)
			{
				CompileCall(call);
				return;
			}

			UnaryExpr u = e as UnaryExpr;
			if (u != null)
			{
				CompileExpr(u.operand);
				Emit(u.op == "-" ? Op.Negate : Op.Not, e.line);
				return;
			}

			BinaryExpr b = (BinaryExpr)e;
			if (b.op == "and")
			{
				// Short-circuit: the right side runs only when the left side is true.
				CompileExpr(b.left);
				Instruction toFalse = Emit(Op.JumpIfFalse, e.line);
				CompileExpr(b.right);
				Emit(Op.ToBool, e.line);
				Instruction toEnd = Emit(Op.Jump, e.line);
				toFalse.a = Here();
				Emit(Op.Const, e.line).value = Value.False;
				toEnd.a = Here();
				return;
			}
			if (b.op == "or")
			{
				// Short-circuit: the right side runs only when the left side is false.
				CompileExpr(b.left);
				Instruction toRight = Emit(Op.JumpIfFalse, e.line);
				Emit(Op.Const, e.line).value = Value.True;
				Instruction toEnd = Emit(Op.Jump, e.line);
				toRight.a = Here();
				CompileExpr(b.right);
				Emit(Op.ToBool, e.line);
				toEnd.a = Here();
				return;
			}
			CompileExpr(b.left);
			CompileExpr(b.right);
			Emit(Op.Binary, e.line).name = b.op;
		}

		private void CompileCall(CallExpr call)
		{
			foreach (Expr arg in call.args)
			{
				CompileExpr(arg);
			}
			int got = call.args.Count;

			int functionIndex;
			if (program.functionIndex.TryGetValue(call.name, out functionIndex))
			{
				FunctionCode target = program.functions[functionIndex];
				CheckCount(call, target.paramCount, target.paramCount);
				Instruction i = Emit(Op.CallScript, call.line);
				i.a = functionIndex;
				i.b = got;
				i.name = call.name;
				return;
			}

			BuiltinFunction builtin = Builtins.Find(call.name);
			if (builtin != null)
			{
				CheckCount(call, builtin.minArgs, builtin.maxArgs);
				Instruction i = Emit(Op.CallBuiltin, call.line);
				i.builtin = builtin;
				i.b = got;
				i.name = call.name;
				return;
			}

			HostFunction hostFunction = host != null ? host.Find(call.name) : null;
			if (hostFunction != null)
			{
				CheckCount(call, hostFunction.minArgs, hostFunction.maxArgs);
				Instruction i = Emit(Op.CallHost, call.line);
				i.host = hostFunction;
				i.b = got;
				i.name = call.name;
				return;
			}

			problems.Add(call.line, "there is no function named '" + call.name + "'.");
			Emit(Op.Const, call.line).value = Value.None;
		}

		private void CheckCount(CallExpr call, int min, int max)
		{
			int got = call.args.Count;
			if (got < min || got > max)
			{
				problems.Add(call.line, "'" + call.name + "' " + NeedsText(min, max) + ", got " + got + ".");
			}
		}

		// "needs 1 value", "needs 2 values", "needs no values", "needs 1 or 2 values", "needs 1 to 3 values".
		internal static string NeedsText(int min, int max)
		{
			if (min == max)
			{
				if (min == 0)
				{
					return "needs no values";
				}
				return "needs " + min + (min == 1 ? " value" : " values");
			}
			if (max == min + 1)
			{
				return "needs " + min + " or " + max + " values";
			}
			return "needs " + min + " to " + max + " values";
		}

		private bool IsFunctionName(string name)
		{
			return program.functionIndex.ContainsKey(name) || Builtins.Find(name) != null
				|| host != null && host.Find(name) != null;
		}

		// ---- Emitting ----

		private int Here()
		{
			return current.code.Count;
		}

		private Instruction Emit(Op op, int line)
		{
			Instruction i = new Instruction();
			i.op = op;
			i.line = line;
			i.loopLine = loops.Count > 0 ? loops[loops.Count - 1].line : 0;
			current.code.Add(i);
			return i;
		}
	}
}
