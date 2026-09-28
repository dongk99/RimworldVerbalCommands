using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace VerbalCommands.RouterScript
{
	internal enum TokenKind
	{
		Name,
		Keyword,
		Number,
		Text,
		Symbol,
		End
	}

	internal sealed class Token
	{
		public TokenKind kind;
		public string text;     // name, keyword or symbol as written; the text's content for Text
		public double number;

		// How the token reads in an error message.
		public string Describe()
		{
			switch (kind)
			{
				case TokenKind.End:
					return "the end of the line";
				case TokenKind.Text:
					return "the text \"" + text + "\"";
				case TokenKind.Number:
					return "the number " + Value.FormatNumber(number);
				default:
					return "'" + text + "'";
			}
		}
	}

	// One line of code after lexing: its line number, how far it is indented, and its tokens (ending
	// in an End token). Blank lines and comment-only lines never become a CodeLine.
	internal sealed class CodeLine
	{
		public int line;
		public int indent;
		public List<Token> tokens;
		public bool broken;     // already reported by the lexer; kept so the blocks around it still line up
	}

	// Brief 17: turns the file into CodeLines. Works line by line: a bad line is reported and skipped,
	// and the lines after it are still read (so the check can report every problem).
	// Brief 18: a list, dict or call left open at the end of a line continues on the next lines (one
	// CodeLine, numbered by its first line); indentation inside it is ignored.
	internal static class Lexer
	{
		public static readonly HashSet<string> Keywords = new HashSet<string>
		{
			"if", "elif", "else", "for", "in", "while", "break", "continue", "function", "return",
			"and", "or", "not", "true", "false", "none"
		};

		private static readonly string[] TwoCharSymbols = { "==", "!=", "<=", ">=" };
		private const string OneCharSymbols = "=<>+-*/%()[]{},:";

		public static List<CodeLine> Read(string source, ProblemList problems)
		{
			List<CodeLine> result = new List<CodeLine>();
			if (source.Length > 0 && source[0] == '﻿')
			{
				source = source.Substring(1);
			}
			string[] lines = source.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n');
			for (int i = 0; i < lines.Length; i++)
			{
				int lineNumber = i + 1;
				string text = lines[i];

				int indent = 0;
				bool tabInIndent = false;
				while (indent < text.Length && (text[indent] == ' ' || text[indent] == '\t'))
				{
					if (text[indent] == '\t')
					{
						tabInIndent = true;
					}
					indent++;
				}
				// Blank and comment-only lines are ignored entirely (even if indented with tabs).
				if (indent == text.Length || text[indent] == '#')
				{
					continue;
				}
				if (tabInIndent)
				{
					problems.Add(lineNumber, "this line is indented with a tab; use spaces.");
					result.Add(Broken(lineNumber, indent));
					continue;
				}

				List<Token> tokens = new List<Token>();
				string error = Tokenize(text, indent, tokens);
				if (error != null)
				{
					problems.Add(lineNumber, error);
					result.Add(Broken(lineNumber, indent));
					continue;
				}
				// Brief 18: a '[', '{' or '(' left open continues on the next lines until it closes.
				if (OpenBrackets(tokens) > 0)
				{
					// -1: not closed before a line that can't be part of a value; the line stays alone
					// and the parser reports the missing ']' / '}' / ')' on it.
					int last = JoinContinuation(lines, i, tokens);
					if (last >= 0)
					{
						i = last;
					}
					else if (EndsOpen(tokens))
					{
						// The line ends in '[', '{', '(' or ',': it was meant to go on, so say so.
						string open = LastOpenBracket(tokens);
						problems.Add(lineNumber, "the '" + open + "' on this line is never closed; add its '"
							+ Closer(open) + "' after the last item.");
						result.Add(Broken(lineNumber, indent));
						continue;
					}
				}
				CodeLine code = new CodeLine();
				code.line = lineNumber;
				code.indent = indent;
				code.tokens = tokens;
				result.Add(code);
			}
			return result;
		}

		// How many brackets the tokens open and don't close (negative when more close than open).
		private static int OpenBrackets(List<Token> tokens)
		{
			int depth = 0;
			foreach (Token t in tokens)
			{
				if (t.kind != TokenKind.Symbol)
				{
					continue;
				}
				if (t.text == "(" || t.text == "[" || t.text == "{")
				{
					depth++;
				}
				else if (t.text == ")" || t.text == "]" || t.text == "}")
				{
					depth--;
				}
			}
			return depth;
		}

		// The line at index `first` leaves a bracket open. Reads the following lines (their
		// indentation doesn't matter; blank and comment lines are skipped) until the brackets close,
		// and appends their tokens to `tokens`. Returns the index of the last line used, or -1 (tokens
		// untouched) when the brackets are still open at a line that can't be inside a value (one that
		// starts with a statement word or has a '=' in it, or can't be read), or at the end of the file.
		private static int JoinContinuation(string[] lines, int first, List<Token> tokens)
		{
			List<Token> joined = new List<Token>(tokens);
			int depth = OpenBrackets(tokens);
			for (int i = first + 1; i < lines.Length; i++)
			{
				string text = lines[i];
				int indent = 0;
				while (indent < text.Length && text[indent] == ' ')
				{
					indent++;
				}
				if (indent == text.Length || text[indent] == '#')
				{
					continue;
				}
				List<Token> more = new List<Token>();
				if (Tokenize(text, indent, more) != null || StartsStatement(more))
				{
					return -1;
				}
				joined.RemoveAt(joined.Count - 1);     // the End token of the line before
				joined.AddRange(more);
				depth += OpenBrackets(more);
				if (depth <= 0)
				{
					tokens.Clear();
					tokens.AddRange(joined);
					return i;
				}
			}
			return -1;
		}

		private static bool EndsOpen(List<Token> tokens)
		{
			Token last = tokens[tokens.Count - 2];     // the token before End
			return last.kind == TokenKind.Symbol
				&& (last.text == "(" || last.text == "[" || last.text == "{" || last.text == ",");
		}

		// The innermost bracket still open at the end of the tokens.
		private static string LastOpenBracket(List<Token> tokens)
		{
			List<string> open = new List<string>();
			foreach (Token t in tokens)
			{
				if (t.kind != TokenKind.Symbol)
				{
					continue;
				}
				if (t.text == "(" || t.text == "[" || t.text == "{")
				{
					open.Add(t.text);
				}
				else if ((t.text == ")" || t.text == "]" || t.text == "}") && open.Count > 0)
				{
					open.RemoveAt(open.Count - 1);
				}
			}
			return open.Count > 0 ? open[open.Count - 1] : "(";
		}

		private static string Closer(string open)
		{
			return open == "[" ? "]" : open == "{" ? "}" : ")";
		}

		private static readonly HashSet<string> StatementWords = new HashSet<string>
		{
			"if", "elif", "else", "for", "while", "break", "continue", "function", "return"
		};

		private static bool StartsStatement(List<Token> tokens)
		{
			if (tokens[0].kind == TokenKind.Keyword && StatementWords.Contains(tokens[0].text))
			{
				return true;
			}
			foreach (Token t in tokens)
			{
				if (t.kind == TokenKind.Symbol && t.text == "=")
				{
					return true;
				}
			}
			return false;
		}

		private static CodeLine Broken(int lineNumber, int indent)
		{
			CodeLine code = new CodeLine();
			code.line = lineNumber;
			code.indent = indent;
			code.broken = true;
			return code;
		}

		// Returns null when fine, else the plain problem.
		private static string Tokenize(string text, int start, List<Token> tokens)
		{
			int i = start;
			while (i < text.Length)
			{
				char c = text[i];
				if (c == ' ')
				{
					i++;
					continue;
				}
				if (c == '\t')
				{
					return "this line has a tab in it; use spaces.";
				}
				if (c == '#')
				{
					break;
				}

				Token token = new Token();
				if (char.IsLetter(c) && c < 128 || c == '_')
				{
					int begin = i;
					while (i < text.Length && (text[i] < 128 && char.IsLetterOrDigit(text[i]) || text[i] == '_'))
					{
						i++;
					}
					token.text = text.Substring(begin, i - begin);
					token.kind = Keywords.Contains(token.text) ? TokenKind.Keyword : TokenKind.Name;
				}
				else if (c >= '0' && c <= '9')
				{
					int begin = i;
					while (i < text.Length && text[i] >= '0' && text[i] <= '9')
					{
						i++;
					}
					if (i < text.Length && text[i] == '.')
					{
						i++;
						if (i >= text.Length || text[i] < '0' || text[i] > '9')
						{
							return "a number can't end in '.'; write it like 2 or 2.5.";
						}
						while (i < text.Length && text[i] >= '0' && text[i] <= '9')
						{
							i++;
						}
					}
					if (i < text.Length && (char.IsLetter(text[i]) || text[i] == '_'))
					{
						int wordEnd = i;
						while (wordEnd < text.Length && (char.IsLetterOrDigit(text[wordEnd]) || text[wordEnd] == '_'))
						{
							wordEnd++;
						}
						return "'" + text.Substring(begin, wordEnd - begin) + "' starts with a digit; names can't start with a digit.";
					}
					token.kind = TokenKind.Number;
					token.text = text.Substring(begin, i - begin);
					if (!double.TryParse(token.text, NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out token.number)
						|| double.IsInfinity(token.number))
					{
						return "the number " + token.text + " is too big.";
					}
				}
				else if (c == '"')
				{
					StringBuilder sb = new StringBuilder();
					i++;
					bool closed = false;
					while (i < text.Length)
					{
						char s = text[i];
						if (s == '"')
						{
							closed = true;
							i++;
							break;
						}
						if (s == '\\')
						{
							if (i + 1 >= text.Length)
							{
								break;
							}
							char e = text[i + 1];
							if (e == '"')
							{
								sb.Append('"');
							}
							else if (e == '\\')
							{
								sb.Append('\\');
							}
							else if (e == 'n')
							{
								sb.Append('\n');
							}
							else
							{
								return "'\\" + e + "' is not something text can contain; only \\\", \\\\ and \\n can follow a backslash.";
							}
							i += 2;
							continue;
						}
						sb.Append(s);
						i++;
					}
					if (!closed)
					{
						return "this text is missing its closing '\"'.";
					}
					token.kind = TokenKind.Text;
					token.text = sb.ToString();
				}
				else if (c == '\'')
				{
					return "text goes in double quotes (\"like this\"), not single quotes.";
				}
				else
				{
					string symbol = null;
					if (i + 1 < text.Length)
					{
						string two = text.Substring(i, 2);
						foreach (string s in TwoCharSymbols)
						{
							if (s == two)
							{
								symbol = s;
							}
						}
					}
					if (symbol == null && OneCharSymbols.IndexOf(c) >= 0)
					{
						symbol = c.ToString();
					}
					if (symbol == null)
					{
						if (c == '!')
						{
							return "'!' is not part of the language; use 'not', or '!=' for \"is not equal\".";
						}
						return "the character '" + c + "' is not part of the language.";
					}
					token.kind = TokenKind.Symbol;
					token.text = symbol;
					i += symbol.Length;
				}
				tokens.Add(token);
			}
			Token end = new Token();
			end.kind = TokenKind.End;
			end.text = "";
			tokens.Add(end);
			return null;
		}
	}

	// Problems found while checking a file, each with its line (0 = no line).
	internal sealed class ProblemList
	{
		public readonly List<KeyValuePair<int, string>> items = new List<KeyValuePair<int, string>>();

		public void Add(int line, string message)
		{
			items.Add(new KeyValuePair<int, string>(line, message));
		}

		public int Count
		{
			get { return items.Count; }
		}

		// "router.txt line 3: ..." in line order (a stable sort, so same-line problems keep their order).
		public List<string> Format(string fileName)
		{
			List<KeyValuePair<int, string>> sorted = new List<KeyValuePair<int, string>>(items);
			for (int i = 1; i < sorted.Count; i++)
			{
				KeyValuePair<int, string> item = sorted[i];
				int j = i - 1;
				while (j >= 0 && sorted[j].Key > item.Key)
				{
					sorted[j + 1] = sorted[j];
					j--;
				}
				sorted[j + 1] = item;
			}
			List<string> result = new List<string>();
			foreach (KeyValuePair<int, string> item in sorted)
			{
				result.Add(Script.Where(fileName, item.Key) + item.Value);
			}
			return result;
		}
	}
}
