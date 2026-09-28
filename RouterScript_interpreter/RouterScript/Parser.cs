using System;
using System.Collections.Generic;

namespace VerbalCommands.RouterScript
{
	// Brief 17: CodeLines -> statements. Blocks come from indentation: a line ending in ':' owns the
	// following lines that are indented deeper, and every line of one block must have the same
	// indentation. A line with a problem is reported and dropped; parsing carries on with the next
	// line (and still reads the block under a broken header), so one check reports every problem.
	internal sealed class Parser
	{
		private const int MaxBlockDepth = 50;
		private const int MaxExpressionDepth = 60;

		private readonly List<CodeLine> lines;
		private readonly ProblemList problems;
		private int index;

		// The line being parsed.
		private List<Token> tokens;
		private int pos;
		private int lineNumber;
		private int expressionDepth;

		private sealed class LineProblem : Exception
		{
			public LineProblem(string message) : base(message)
			{
			}
		}

		private Parser(List<CodeLine> lines, ProblemList problems)
		{
			this.lines = lines;
			this.problems = problems;
		}

		public static List<Stmt> Parse(List<CodeLine> lines, ProblemList problems)
		{
			Parser parser = new Parser(lines, problems);
			List<Stmt> result = new List<Stmt>();
			parser.ParseBlock(0, result, 0, true);
			return result;
		}

		private void ParseBlock(int indent, List<Stmt> into, int depth, bool topLevel)
		{
			bool lastHadBlock = false;
			IfStmt lastIf = null;
			while (index < lines.Count)
			{
				CodeLine code = lines[index];
				if (code.indent < indent)
				{
					return;
				}
				if (code.broken)
				{
					// Already reported. It may have been a header, so lines indented under it are
					// read as its block (their own problems are still reported), and an elif/else
					// after it is accepted without a second report.
					index++;
					if (index < lines.Count && lines[index].indent > code.indent)
					{
						if (depth + 1 > MaxBlockDepth)
						{
							while (index < lines.Count && lines[index].indent > code.indent)
							{
								index++;
							}
						}
						else
						{
							ParseBlock(lines[index].indent, new List<Stmt>(), depth + 1, false);
						}
					}
					lastIf = new IfStmt();
					lastHadBlock = true;
					continue;
				}
				if (code.indent > indent)
				{
					if (index == 0)
					{
						problems.Add(code.line, "the first line of code is indented; top-level lines start at the left edge.");
					}
					else if (lastHadBlock)
					{
						problems.Add(code.line, "this line's indentation doesn't line up with any block above it.");
					}
					else
					{
						problems.Add(code.line, "this line is indented more than the line above it, but the line above doesn't end in ':'.");
					}
					// One report for the stray line and everything under it.
					index++;
					while (index < lines.Count && lines[index].indent > indent)
					{
						index++;
					}
					continue;
				}

				index++;
				List<Stmt> body = null;
				Stmt stmt = null;
				bool isElseOrElif = false;
				bool lineFailed = false;
				try
				{
					BeginLine(code);
					stmt = ParseLine(topLevel, ref lastIf, out body, out isElseOrElif);
				}
				catch (LineProblem p)
				{
					problems.Add(code.line, p.Message);
					stmt = null;
					lineFailed = true;
					// Lines indented under a broken header are still read as its block (so they aren't
					// reported as badly indented, and their own problems are found).
					body = EndsInColon(code) || IsHeaderKeyword(code.tokens[0]) ? new List<Stmt>() : null;
					// A broken if/elif/else line still counts as one, so the elif/else lines after
					// it aren't reported as well.
					Token first = code.tokens[0];
					isElseOrElif = first.kind == TokenKind.Keyword && (first.text == "elif" || first.text == "else");
					if (first.kind == TokenKind.Keyword && first.text == "if")
					{
						lastIf = new IfStmt();
						isElseOrElif = true;
					}
				}

				if (stmt != null && !isElseOrElif)
				{
					into.Add(stmt);
				}
				if (!isElseOrElif)
				{
					lastIf = stmt as IfStmt;
				}

				lastHadBlock = false;
				if (body != null)
				{
					lastHadBlock = true;
					if (index < lines.Count && lines[index].indent > indent)
					{
						if (depth + 1 > MaxBlockDepth)
						{
							problems.Add(lines[index].line, "blocks are nested too deeply here (more than " + MaxBlockDepth + " levels).");
							while (index < lines.Count && lines[index].indent > indent)
							{
								index++;
							}
						}
						else
						{
							ParseBlock(lines[index].indent, body, depth + 1, false);
						}
					}
					else if (!lineFailed)
					{
						problems.Add(code.line, "the line ending in ':' needs an indented block under it.");
					}
				}
			}
		}

		private static bool IsHeaderKeyword(Token t)
		{
			return t.kind == TokenKind.Keyword && (t.text == "if" || t.text == "elif" || t.text == "else" || t.text == "for" || t.text == "while" || t.text == "function");
		}

		private static bool EndsInColon(CodeLine code)
		{
			int n = code.tokens.Count;
			return n >= 2 && code.tokens[n - 2].kind == TokenKind.Symbol && code.tokens[n - 2].text == ":";
		}

		private void BeginLine(CodeLine code)
		{
			tokens = code.tokens;
			pos = 0;
			lineNumber = code.line;
			expressionDepth = 0;
		}

		// One line. Returns the statement (null for elif/else, which join lastIf) and, for a line
		// ending in ':', the list its block goes into.
		private Stmt ParseLine(bool topLevel, ref IfStmt lastIf, out List<Stmt> body, out bool isElseOrElif)
		{
			body = null;
			isElseOrElif = false;
			Token first = Peek();
			if (first.kind == TokenKind.Keyword)
			{
				switch (first.text)
				{
					case "if":
					{
						Next();
						IfStmt s = new IfStmt();
						s.line = lineNumber;
						s.conditions.Add(ParseExpr());
						ExpectColonEnd();
						body = new List<Stmt>();
						s.blocks.Add(body);
						return s;
					}
					case "elif":
					{
						Next();
						Expr condition = ParseExpr();
						ExpectColonEnd();
						if (lastIf == null)
						{
							throw new LineProblem("'elif' must come right after an 'if' block.");
						}
						if (lastIf.elseBlock != null)
						{
							throw new LineProblem("'elif' can't come after 'else'.");
						}
						isElseOrElif = true;
						lastIf.conditions.Add(condition);
						body = new List<Stmt>();
						lastIf.blocks.Add(body);
						return null;
					}
					case "else":
					{
						Next();
						ExpectColonEnd();
						if (lastIf == null)
						{
							throw new LineProblem("'else' must come right after an 'if' or 'elif' block.");
						}
						if (lastIf.elseBlock != null)
						{
							throw new LineProblem("this 'if' already has an 'else'.");
						}
						isElseOrElif = true;
						body = new List<Stmt>();
						lastIf.elseBlock = body;
						return null;
					}
					case "for":
					{
						Next();
						ForStmt s = new ForStmt();
						s.line = lineNumber;
						s.variable = ExpectName("after 'for' comes one name for each item, like: for room in rooms:");
						if (!IsKeyword(Peek(), "in"))
						{
							throw new LineProblem("expected 'in' after 'for " + s.variable + "', but found " + Peek().Describe() + ".");
						}
						Next();
						s.items = ParseExpr();
						ExpectColonEnd();
						body = s.body;
						return s;
					}
					case "while":
					{
						Next();
						WhileStmt s = new WhileStmt();
						s.line = lineNumber;
						s.condition = ParseExpr();
						ExpectColonEnd();
						body = s.body;
						return s;
					}
					case "break":
					case "continue":
					{
						Next();
						ExpectEnd();
						Stmt s = first.text == "break" ? (Stmt)new BreakStmt() : new ContinueStmt();
						s.line = lineNumber;
						return s;
					}
					case "return":
					{
						Next();
						ReturnStmt s = new ReturnStmt();
						s.line = lineNumber;
						if (Peek().kind != TokenKind.End)
						{
							s.value = ParseExpr();
						}
						ExpectEnd();
						return s;
					}
					case "function":
					{
						Next();
						FunctionStmt s = new FunctionStmt();
						s.line = lineNumber;
						s.topLevel = topLevel;
						s.name = ExpectName("after 'function' comes the function's name, like: function route(order):");
						Expect("(", "after the function's name");
						if (!IsSymbol(Peek(), ")"))
						{
							while (true)
							{
								s.parameters.Add(ExpectName("the values a function takes are names, like: function route(order, vocab):"));
								if (IsSymbol(Peek(), ","))
								{
									Next();
									continue;
								}
								break;
							}
						}
						Expect(")", "after the function's values");
						ExpectColonEnd();
						body = s.body;
						return s;
					}
				}
			}

			if (first.kind == TokenKind.Keyword && IsSymbol(PeekAt(1), "="))
			{
				throw new LineProblem("'" + first.text + "' is a word of the language and can't be used as a name.");
			}
			Expr e = ParseExpr();
			if (IsSymbol(Peek(), "="))
			{
				Next();
				if (!(e is NameExpr) && !(e is IndexExpr))
				{
					throw new LineProblem("only a name, or an item like x[i] or d[\"key\"], can be given a value with '='.");
				}
				AssignStmt a = new AssignStmt();
				a.line = lineNumber;
				a.target = e;
				a.value = ParseExpr();
				ExpectEnd();
				return a;
			}
			ExpectEnd();
			ExprStmt es = new ExprStmt();
			es.line = lineNumber;
			es.expr = e;
			return es;
		}

		// ---- Expressions, lowest priority first: or, and, not, comparisons, + -, * / %, -x ----

		private Expr ParseExpr()
		{
			Enter();
			Expr e = ParseOr();
			expressionDepth--;
			return e;
		}

		private void Enter()
		{
			expressionDepth++;
			if (expressionDepth > MaxExpressionDepth)
			{
				throw new LineProblem("this line nests too deeply (more than " + MaxExpressionDepth + " levels of brackets or operators).");
			}
		}

		private Expr ParseOr()
		{
			Expr left = ParseAnd();
			while (IsKeyword(Peek(), "or"))
			{
				Next();
				left = MakeBinary("or", left, ParseAnd());
			}
			return left;
		}

		private Expr ParseAnd()
		{
			Expr left = ParseNot();
			while (IsKeyword(Peek(), "and"))
			{
				Next();
				left = MakeBinary("and", left, ParseNot());
			}
			return left;
		}

		private Expr ParseNot()
		{
			if (IsKeyword(Peek(), "not"))
			{
				Next();
				Enter();
				UnaryExpr u = new UnaryExpr();
				u.line = lineNumber;
				u.op = "not";
				u.operand = ParseNot();
				expressionDepth--;
				return u;
			}
			return ParseComparison();
		}

		private Expr ParseComparison()
		{
			Expr left = ParseAdd();
			string op = ComparisonAhead();
			if (op == null)
			{
				return left;
			}
			SkipComparison(op);
			Expr result = MakeBinary(op, left, ParseAdd());
			if (ComparisonAhead() != null)
			{
				throw new LineProblem("compare two values at a time; join comparisons with 'and', like: a < b and b < c.");
			}
			return result;
		}

		private string ComparisonAhead()
		{
			Token t = Peek();
			if (t.kind == TokenKind.Symbol && (t.text == "==" || t.text == "!=" || t.text == "<" || t.text == ">" || t.text == "<=" || t.text == ">="))
			{
				return t.text;
			}
			if (IsKeyword(t, "in"))
			{
				return "in";
			}
			if (IsKeyword(t, "not") && IsKeyword(PeekAt(1), "in"))
			{
				return "not in";
			}
			return null;
		}

		private void SkipComparison(string op)
		{
			Next();
			if (op == "not in")
			{
				Next();
			}
		}

		private Expr ParseAdd()
		{
			Expr left = ParseMul();
			while (IsSymbol(Peek(), "+") || IsSymbol(Peek(), "-"))
			{
				string op = Next().text;
				left = MakeBinary(op, left, ParseMul());
			}
			return left;
		}

		private Expr ParseMul()
		{
			Expr left = ParseUnary();
			while (IsSymbol(Peek(), "*") || IsSymbol(Peek(), "/") || IsSymbol(Peek(), "%"))
			{
				string op = Next().text;
				left = MakeBinary(op, left, ParseUnary());
			}
			return left;
		}

		private Expr ParseUnary()
		{
			if (IsSymbol(Peek(), "-"))
			{
				Next();
				Enter();
				UnaryExpr u = new UnaryExpr();
				u.line = lineNumber;
				u.op = "-";
				u.operand = ParseUnary();
				expressionDepth--;
				return u;
			}
			return ParsePostfix();
		}

		private Expr ParsePostfix()
		{
			Expr e = ParseAtom();
			while (true)
			{
				if (IsSymbol(Peek(), "["))
				{
					Next();
					IndexExpr ix = new IndexExpr();
					ix.line = lineNumber;
					ix.target = e;
					ix.index = ParseExpr();
					Expect("]", "to close the '['");
					e = ix;
					continue;
				}
				if (IsSymbol(Peek(), "("))
				{
					throw new LineProblem("only a function name can be called with '(...)', like: len(rooms).");
				}
				return e;
			}
		}

		private Expr ParseAtom()
		{
			Token t = Peek();
			switch (t.kind)
			{
				case TokenKind.Number:
				{
					Next();
					return MakeLiteral(Value.FromNumber(t.number));
				}
				case TokenKind.Text:
				{
					Next();
					return MakeLiteral(Value.FromText(t.text));
				}
				case TokenKind.Keyword:
					if (t.text == "true" || t.text == "false" || t.text == "none")
					{
						Next();
						return MakeLiteral(t.text == "true" ? Value.True : t.text == "false" ? Value.False : Value.None);
					}
					throw new LineProblem("expected a value but found '" + t.text + "'.");
				case TokenKind.Name:
				{
					Next();
					if (IsSymbol(Peek(), "("))
					{
						Next();
						CallExpr call = new CallExpr();
						call.line = lineNumber;
						call.name = t.text;
						if (!IsSymbol(Peek(), ")"))
						{
							while (true)
							{
								call.args.Add(ParseExpr());
								if (IsSymbol(Peek(), ","))
								{
									Next();
									continue;
								}
								break;
							}
						}
						Expect(")", "to close the call to '" + t.text + "'");
						return call;
					}
					NameExpr n = new NameExpr();
					n.line = lineNumber;
					n.name = t.text;
					return n;
				}
				case TokenKind.Symbol:
					if (t.text == "(")
					{
						Next();
						Expr inner = ParseExpr();
						Expect(")", "to close the '('");
						return inner;
					}
					if (t.text == "[")
					{
						Next();
						ListExpr list = new ListExpr();
						list.line = lineNumber;
						if (!IsSymbol(Peek(), "]"))
						{
							while (true)
							{
								list.items.Add(ParseExpr());
								if (IsSymbol(Peek(), ","))
								{
									Next();
									// Brief 18: a comma after the last item is allowed (multi-line lists).
									if (IsSymbol(Peek(), "]"))
									{
										break;
									}
									continue;
								}
								break;
							}
						}
						Expect("]", "to close the list");
						return list;
					}
					if (t.text == "{")
					{
						Next();
						DictExpr dict = new DictExpr();
						dict.line = lineNumber;
						if (!IsSymbol(Peek(), "}"))
						{
							while (true)
							{
								dict.keys.Add(ParseExpr());
								Expect(":", "between a key and its value");
								dict.values.Add(ParseExpr());
								if (IsSymbol(Peek(), ","))
								{
									Next();
									if (IsSymbol(Peek(), "}"))
									{
										break;
									}
									continue;
								}
								break;
							}
						}
						Expect("}", "to close the dict");
						return dict;
					}
					if (t.text == "=")
					{
						throw new LineProblem("'=' gives a name a value; to compare two values use '=='.");
					}
					throw new LineProblem("expected a value but found '" + t.text + "'.");
				default:
					throw new LineProblem("a value is missing at the end of the line.");
			}
		}

		private Expr MakeLiteral(Value v)
		{
			LiteralExpr e = new LiteralExpr();
			e.line = lineNumber;
			e.value = v;
			return e;
		}

		private Expr MakeBinary(string op, Expr left, Expr right)
		{
			BinaryExpr b = new BinaryExpr();
			b.line = lineNumber;
			b.op = op;
			b.left = left;
			b.right = right;
			return b;
		}

		// ---- Token helpers ----

		private Token Peek()
		{
			return tokens[pos];
		}

		private Token PeekAt(int ahead)
		{
			int i = pos + ahead;
			return i < tokens.Count ? tokens[i] : tokens[tokens.Count - 1];
		}

		private Token Next()
		{
			Token t = tokens[pos];
			if (t.kind != TokenKind.End)
			{
				pos++;
			}
			return t;
		}

		private static bool IsSymbol(Token t, string symbol)
		{
			return t.kind == TokenKind.Symbol && t.text == symbol;
		}

		private static bool IsKeyword(Token t, string keyword)
		{
			return t.kind == TokenKind.Keyword && t.text == keyword;
		}

		private void Expect(string symbol, string why)
		{
			Token t = Peek();
			if (!IsSymbol(t, symbol))
			{
				throw new LineProblem("expected '" + symbol + "' " + why + ", but found " + t.Describe() + ".");
			}
			Next();
		}

		private string ExpectName(string hint)
		{
			Token t = Peek();
			if (t.kind == TokenKind.Keyword)
			{
				throw new LineProblem("'" + t.text + "' is a word of the language and can't be used as a name.");
			}
			if (t.kind != TokenKind.Name)
			{
				throw new LineProblem("expected a name but found " + t.Describe() + "; " + hint);
			}
			Next();
			return t.text;
		}

		private void ExpectEnd()
		{
			Token t = Peek();
			if (t.kind == TokenKind.End)
			{
				return;
			}
			if (IsSymbol(t, ":") && PeekAt(1).kind == TokenKind.End)
			{
				throw new LineProblem("only lines starting with if, elif, else, for, while or function end in ':'.");
			}
			throw Unexpected(t);
		}

		private void ExpectColonEnd()
		{
			Token t = Peek();
			if (IsSymbol(t, ":"))
			{
				Next();
				if (Peek().kind == TokenKind.End)
				{
					return;
				}
				throw new LineProblem("nothing can follow the ':' on the same line; put the block on the next lines, indented.");
			}
			if (t.kind == TokenKind.End)
			{
				throw new LineProblem("this line must end in ':'.");
			}
			throw Unexpected(t);
		}

		private static LineProblem Unexpected(Token t)
		{
			if (IsSymbol(t, "="))
			{
				return new LineProblem("'=' gives a name a value; to compare two values use '=='.");
			}
			return new LineProblem(t.Describe() + " doesn't belong here.");
		}
	}
}
