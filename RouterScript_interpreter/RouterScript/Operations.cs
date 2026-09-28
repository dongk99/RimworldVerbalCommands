using System;
using System.Collections.Generic;
using System.Globalization;

namespace VerbalCommands.RouterScript
{
	// Brief 17: operators and indexing. Problems throw ScriptError with a plain message; the Runner
	// adds the file and line.
	internal static class Operations
	{
		// A broken script must not eat the game's memory: text and lists have a size cap.
		public const int MaxTextLength = 1000000;
		public const int MaxListLength = 1000000;

		public static Value Binary(string op, Value left, Value right, Runner runner)
		{
			switch (op)
			{
				case "+":
					return Add(left, right, runner);
				case "-":
				case "*":
				case "/":
				case "%":
					return Arithmetic(op, left, right);
				case "==":
					return Value.FromBool(Value.AreEqual(left, right));
				case "!=":
					return Value.FromBool(!Value.AreEqual(left, right));
				case "<":
				case ">":
				case "<=":
				case ">=":
					return Compare(op, left, right);
				case "in":
					return Value.FromBool(In(left, right));
				case "not in":
					return Value.FromBool(!In(left, right));
			}
			throw new ScriptError("'" + op + "' is not an operator.");
		}

		private static Value Add(Value left, Value right, Runner runner)
		{
			if (left.kind == ValueKind.Number && right.kind == ValueKind.Number)
			{
				return Value.FromNumber(left.AsNumber + right.AsNumber);
			}
			if (left.kind == ValueKind.Text && right.kind == ValueKind.Text)
			{
				long length = (long)left.AsText.Length + right.AsText.Length;
				CheckTextLength(length);
				runner.Charge(length);
				return Value.FromText(left.AsText + right.AsText);
			}
			if (left.kind == ValueKind.List && right.kind == ValueKind.List)
			{
				long count = (long)left.AsList.Count + right.AsList.Count;
				CheckListLength(count);
				runner.Charge(count);
				List<Value> joined = new List<Value>(left.AsList);
				joined.AddRange(right.AsList);
				return Value.WrapList(joined);
			}
			string message = "'+' can't join " + Value.Describe(left) + " and " + Value.Describe(right);
			if (left.kind == ValueKind.Text || right.kind == ValueKind.Text)
			{
				message += "; use text(...) to turn the other value into text first";
			}
			throw new ScriptError(message + ".");
		}

		private static Value Arithmetic(string op, Value left, Value right)
		{
			if (left.kind != ValueKind.Number || right.kind != ValueKind.Number)
			{
				throw new ScriptError("'" + op + "' needs two numbers, got " + Value.Describe(left) + " and " + Value.Describe(right) + ".");
			}
			double a = left.AsNumber;
			double b = right.AsNumber;
			switch (op)
			{
				case "-":
					return Value.FromNumber(a - b);
				case "*":
					return Value.FromNumber(a * b);
				case "/":
					if (b == 0)
					{
						throw new ScriptError("can't divide by zero.");
					}
					return Value.FromNumber(a / b);
				default:
					if (b == 0)
					{
						throw new ScriptError("can't divide by zero (in '%').");
					}
					return Value.FromNumber(a % b);
			}
		}

		private static Value Compare(string op, Value left, Value right)
		{
			int c;
			if (left.kind == ValueKind.Number && right.kind == ValueKind.Number)
			{
				c = left.AsNumber.CompareTo(right.AsNumber);
			}
			else if (left.kind == ValueKind.Text && right.kind == ValueKind.Text)
			{
				c = string.CompareOrdinal(left.AsText, right.AsText);
			}
			else
			{
				throw new ScriptError("'" + op + "' can only compare two numbers or two texts, got " + Value.Describe(left) + " and " + Value.Describe(right) + ".");
			}
			switch (op)
			{
				case "<":
					return Value.FromBool(c < 0);
				case ">":
					return Value.FromBool(c > 0);
				case "<=":
					return Value.FromBool(c <= 0);
				default:
					return Value.FromBool(c >= 0);
			}
		}

		// List membership, dict key, or part of a text.
		private static bool In(Value item, Value container)
		{
			switch (container.kind)
			{
				case ValueKind.List:
					foreach (Value v in container.AsList)
					{
						if (Value.AreEqual(v, item))
						{
							return true;
						}
					}
					return false;
				case ValueKind.Dict:
					return container.AsDict.Has(DictKey(item));
				case ValueKind.Text:
					if (item.kind != ValueKind.Text)
					{
						throw new ScriptError("'in' with text on its right needs text on its left, got " + Value.Describe(item) + ".");
					}
					return container.AsText.IndexOf(item.AsText, StringComparison.Ordinal) >= 0;
				default:
					throw new ScriptError("'in' needs a list, a dict or text on its right, got " + Value.Describe(container) + ".");
			}
		}

		public static string DictKey(Value key)
		{
			if (key.kind != ValueKind.Text)
			{
				throw new ScriptError("dict keys are text, got " + Value.Describe(key) + ".");
			}
			return key.AsText;
		}

		// x[i] on a list or text, d["key"] on a dict.
		public static Value GetItem(Value target, Value index)
		{
			switch (target.kind)
			{
				case ValueKind.List:
					return target.AsList[Position(index, target.AsList.Count, "list", "items")];
				case ValueKind.Text:
					return Value.FromText(target.AsText[Position(index, target.AsText.Length, "text", "characters")].ToString());
				case ValueKind.Dict:
				{
					string key = DictKey(index);
					Value v = target.AsDict.Get(key);
					if (v == null)
					{
						throw new ScriptError("the dict has no key \"" + key + "\"; use get(dict, key, default) or has(dict, key) when a key may be missing.");
					}
					return v;
				}
				default:
					throw new ScriptError("can't take an item out of " + Value.Describe(target) + "; only lists, dicts and text have items.");
			}
		}

		public static void SetItem(Value target, Value index, Value value)
		{
			switch (target.kind)
			{
				case ValueKind.List:
					target.AsList[Position(index, target.AsList.Count, "list", "items")] = value;
					return;
				case ValueKind.Dict:
					target.AsDict.Set(DictKey(index), value);
					return;
				case ValueKind.Text:
					throw new ScriptError("text can't be changed one character at a time; make new text with +, replace or join.");
				default:
					throw new ScriptError("can't set an item of " + Value.Describe(target) + "; only lists and dicts can be changed that way.");
			}
		}

		// A checked 0-based position (no negative positions).
		public static int Position(Value index, int count, string what, string unit)
		{
			if (index.kind != ValueKind.Number)
			{
				throw new ScriptError("a " + what + " position must be a number, got " + Value.Describe(index) + ".");
			}
			double d = index.AsNumber;
			if (Math.Floor(d) != d)
			{
				throw new ScriptError("a " + what + " position must be a whole number, got " + Value.FormatNumber(d) + ".");
			}
			if (d < 0)
			{
				throw new ScriptError("position " + Value.FormatNumber(d) + " is before the start of the " + what + "; the first position is 0.");
			}
			if (d >= count)
			{
				throw new ScriptError("position " + Value.FormatNumber(d) + " is past the end of the " + what
					+ " (it has " + count.ToString(CultureInfo.InvariantCulture) + " " + (count == 1 ? unit.TrimEnd('s') : unit) + ").");
			}
			return (int)d;
		}

		public static void CheckTextLength(long length)
		{
			if (length > MaxTextLength)
			{
				throw new ScriptError("the text got too long (over " + MaxTextLength.ToString("N0", CultureInfo.InvariantCulture) + " characters).");
			}
		}

		public static void CheckListLength(long count)
		{
			if (count > MaxListLength)
			{
				throw new ScriptError("the list got too long (over " + MaxListLength.ToString("N0", CultureInfo.InvariantCulture) + " items).");
			}
		}
	}
}
