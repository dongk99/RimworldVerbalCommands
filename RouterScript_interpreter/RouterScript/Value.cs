using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace VerbalCommands.RouterScript
{
	// Brief 17: one value of the router language: none, true/false, a number, text, a list or a dict.
	// Lists and dicts are shared, not copied: assigning a list to a second name, or passing it to a
	// function, gives both the same list (append through one is seen through the other).
	public enum ValueKind
	{
		None,
		Bool,
		Number,
		Text,
		List,
		Dict
	}

	public sealed class Value
	{
		public static readonly Value None = new Value(ValueKind.None);
		public static readonly Value True = new Value(true);
		public static readonly Value False = new Value(false);

		public readonly ValueKind kind;
		private readonly bool boolValue;
		private readonly double numberValue;
		private readonly string textValue;
		private readonly List<Value> listValue;
		private readonly ScriptDict dictValue;

		private Value(ValueKind kind)
		{
			this.kind = kind;
		}

		private Value(bool b)
		{
			kind = ValueKind.Bool;
			boolValue = b;
		}

		private Value(double d)
		{
			kind = ValueKind.Number;
			numberValue = d;
		}

		private Value(string s)
		{
			kind = ValueKind.Text;
			textValue = s;
		}

		private Value(List<Value> list)
		{
			kind = ValueKind.List;
			listValue = list;
		}

		private Value(ScriptDict dict)
		{
			kind = ValueKind.Dict;
			dictValue = dict;
		}

		// ---- Making values (C# -> script) ----

		public static Value FromBool(bool b)
		{
			return b ? True : False;
		}

		public static Value FromNumber(double d)
		{
			return new Value(d);
		}

		// null becomes none.
		public static Value FromText(string s)
		{
			return s == null ? None : new Value(s);
		}

		public static Value NewList()
		{
			return new Value(new List<Value>());
		}

		// Copies the items into a new script list.
		public static Value FromList(IEnumerable<Value> items)
		{
			List<Value> list = new List<Value>();
			if (items != null)
			{
				foreach (Value v in items)
				{
					list.Add(v ?? None);
				}
			}
			return new Value(list);
		}

		// A new script list of texts (null entries become none).
		public static Value FromStrings(IEnumerable<string> items)
		{
			List<Value> list = new List<Value>();
			if (items != null)
			{
				foreach (string s in items)
				{
					list.Add(FromText(s));
				}
			}
			return new Value(list);
		}

		public static Value NewDict()
		{
			return new Value(new ScriptDict());
		}

		// Uses the given list itself (no copy). For the interpreter.
		internal static Value WrapList(List<Value> list)
		{
			return new Value(list);
		}

		internal static Value WrapDict(ScriptDict dict)
		{
			return new Value(dict);
		}

		// Converts plain C# data: null, Value, string, bool, any number type, IDictionary (keys turned
		// into text), IEnumerable (becomes a list). Anything else is a host programming mistake and
		// throws ArgumentException (this is C# API misuse, never a script problem).
		public static Value From(object o)
		{
			if (o == null)
			{
				return None;
			}
			Value v = o as Value;
			if (v != null)
			{
				return v;
			}
			string s = o as string;
			if (s != null)
			{
				return new Value(s);
			}
			if (o is bool)
			{
				return FromBool((bool)o);
			}
			if (o is double || o is float || o is int || o is long || o is short || o is byte || o is sbyte
				|| o is uint || o is ulong || o is ushort || o is decimal)
			{
				return new Value(Convert.ToDouble(o, CultureInfo.InvariantCulture));
			}
			IDictionary dictionary = o as IDictionary;
			if (dictionary != null)
			{
				ScriptDict dict = new ScriptDict();
				foreach (DictionaryEntry entry in dictionary)
				{
					dict.Set(Convert.ToString(entry.Key, CultureInfo.InvariantCulture), From(entry.Value));
				}
				return new Value(dict);
			}
			IEnumerable enumerable = o as IEnumerable;
			if (enumerable != null)
			{
				List<Value> list = new List<Value>();
				foreach (object item in enumerable)
				{
					list.Add(From(item));
				}
				return new Value(list);
			}
			throw new ArgumentException("Value.From cannot convert " + o.GetType().Name);
		}

		public static implicit operator Value(string s)
		{
			return FromText(s);
		}

		public static implicit operator Value(double d)
		{
			return new Value(d);
		}

		public static implicit operator Value(int i)
		{
			return new Value((double)i);
		}

		public static implicit operator Value(bool b)
		{
			return FromBool(b);
		}

		// ---- Reading values (script -> C#) ----

		public bool IsNone
		{
			get { return kind == ValueKind.None; }
		}

		// false unless this is true.
		public bool AsBool
		{
			get { return kind == ValueKind.Bool && boolValue; }
		}

		// 0 unless this is a number.
		public double AsNumber
		{
			get { return kind == ValueKind.Number ? numberValue : 0; }
		}

		// null unless this is text.
		public string AsText
		{
			get { return kind == ValueKind.Text ? textValue : null; }
		}

		// The list itself (changes are seen by the script), or null unless this is a list.
		public List<Value> AsList
		{
			get { return listValue; }
		}

		// The dict itself, or null unless this is a dict.
		public ScriptDict AsDict
		{
			get { return dictValue; }
		}

		// false, none, 0, "", [] and {} are false; everything else is true.
		public bool IsTruthy
		{
			get
			{
				switch (kind)
				{
					case ValueKind.None:
						return false;
					case ValueKind.Bool:
						return boolValue;
					case ValueKind.Number:
						return numberValue != 0;
					case ValueKind.Text:
						return textValue.Length > 0;
					case ValueKind.List:
						return listValue.Count > 0;
					default:
						return dictValue.Count > 0;
				}
			}
		}

		// Plain C# data: null, bool, double, string, List<object>, Dictionary<string, object> (a new
		// copy; changing it doesn't change the script's value).
		public object ToObject()
		{
			return ToObject(0);
		}

		private object ToObject(int depth)
		{
			if (depth > MaxNesting)
			{
				return null;
			}
			switch (kind)
			{
				case ValueKind.None:
					return null;
				case ValueKind.Bool:
					return boolValue;
				case ValueKind.Number:
					return numberValue;
				case ValueKind.Text:
					return textValue;
				case ValueKind.List:
					List<object> list = new List<object>();
					foreach (Value v in listValue)
					{
						list.Add(v.ToObject(depth + 1));
					}
					return list;
				default:
					Dictionary<string, object> dict = new Dictionary<string, object>();
					foreach (string key in dictValue.Keys)
					{
						dict[key] = dictValue.Get(key).ToObject(depth + 1);
					}
					return dict;
			}
		}

		// A list's items as text (each item as text() shows it); text alone becomes one item; none
		// becomes an empty list.
		public List<string> ToStringList()
		{
			List<string> result = new List<string>();
			if (kind == ValueKind.List)
			{
				foreach (Value v in listValue)
				{
					result.Add(v.ToText());
				}
			}
			else if (kind != ValueKind.None)
			{
				result.Add(ToText());
			}
			return result;
		}

		// What text(x) and print(x) show: text as it is, numbers without a trailing ".0", true/false,
		// none, and lists/dicts written the way the script would write them (["a", 1], {"k": "v"}).
		public string ToText()
		{
			if (kind == ValueKind.Text)
			{
				return textValue;
			}
			StringBuilder sb = new StringBuilder();
			Render(this, sb, 0);
			return sb.ToString();
		}

		public override string ToString()
		{
			return ToText();
		}

		// Lists inside lists (or a list inside itself) stop being written out past this depth.
		private const int MaxNesting = 100;

		private static void Render(Value v, StringBuilder sb, int depth)
		{
			if (depth > MaxNesting)
			{
				sb.Append("...");
				return;
			}
			switch (v.kind)
			{
				case ValueKind.None:
					sb.Append("none");
					break;
				case ValueKind.Bool:
					sb.Append(v.boolValue ? "true" : "false");
					break;
				case ValueKind.Number:
					sb.Append(FormatNumber(v.numberValue));
					break;
				case ValueKind.Text:
					if (depth == 0)
					{
						sb.Append(v.textValue);
					}
					else
					{
						AppendQuoted(v.textValue, sb);
					}
					break;
				case ValueKind.List:
					sb.Append('[');
					for (int i = 0; i < v.listValue.Count; i++)
					{
						if (i > 0)
						{
							sb.Append(", ");
						}
						Render(v.listValue[i], sb, depth + 1);
					}
					sb.Append(']');
					break;
				default:
					sb.Append('{');
					bool first = true;
					foreach (string key in v.dictValue.Keys)
					{
						if (!first)
						{
							sb.Append(", ");
						}
						first = false;
						AppendQuoted(key, sb);
						sb.Append(": ");
						Render(v.dictValue.Get(key), sb, depth + 1);
					}
					sb.Append('}');
					break;
			}
		}

		private static void AppendQuoted(string s, StringBuilder sb)
		{
			sb.Append('"');
			foreach (char c in s)
			{
				if (c == '"')
				{
					sb.Append("\\\"");
				}
				else if (c == '\\')
				{
					sb.Append("\\\\");
				}
				else if (c == '\n')
				{
					sb.Append("\\n");
				}
				else
				{
					sb.Append(c);
				}
			}
			sb.Append('"');
		}

		// Whole numbers without a decimal point ("3"), others as short as they can be written ("0.5").
		public static string FormatNumber(double d)
		{
			if (Math.Floor(d) == d && Math.Abs(d) < 1e15)
			{
				return ((long)d).ToString(CultureInfo.InvariantCulture);
			}
			return d.ToString("R", CultureInfo.InvariantCulture);
		}

		// Plain words for error messages: "a number", "text", "a list", ...
		internal static string Describe(Value v)
		{
			switch (v.kind)
			{
				case ValueKind.None:
					return "none";
				case ValueKind.Bool:
					return v.boolValue ? "true" : "false";
				case ValueKind.Number:
					return "a number";
				case ValueKind.Text:
					return "text";
				case ValueKind.List:
					return "a list";
				default:
					return "a dict";
			}
		}

		// ==: same kind and same content. Lists and dicts compare item by item.
		public static bool AreEqual(Value a, Value b)
		{
			return AreEqual(a, b, 0);
		}

		private static bool AreEqual(Value a, Value b, int depth)
		{
			if (ReferenceEquals(a, b))
			{
				return true;
			}
			if (a.kind != b.kind || depth > MaxNesting)
			{
				return false;
			}
			switch (a.kind)
			{
				case ValueKind.None:
					return true;
				case ValueKind.Bool:
					return a.boolValue == b.boolValue;
				case ValueKind.Number:
					return a.numberValue == b.numberValue;
				case ValueKind.Text:
					return string.Equals(a.textValue, b.textValue, StringComparison.Ordinal);
				case ValueKind.List:
					if (a.listValue.Count != b.listValue.Count)
					{
						return false;
					}
					for (int i = 0; i < a.listValue.Count; i++)
					{
						if (!AreEqual(a.listValue[i], b.listValue[i], depth + 1))
						{
							return false;
						}
					}
					return true;
				default:
					if (a.dictValue.Count != b.dictValue.Count)
					{
						return false;
					}
					foreach (string key in a.dictValue.Keys)
					{
						Value other = b.dictValue.Get(key);
						if (other == null || !AreEqual(a.dictValue.Get(key), other, depth + 1))
						{
							return false;
						}
					}
					return true;
			}
		}
	}

	// A dict of the router language: text keys, values kept in the order the keys were first set
	// (that's the order `for key in dict` and keys(dict) give).
	public sealed class ScriptDict
	{
		private readonly List<string> order = new List<string>();
		private readonly Dictionary<string, Value> map = new Dictionary<string, Value>(StringComparer.Ordinal);

		public int Count
		{
			get { return order.Count; }
		}

		public IList<string> Keys
		{
			get { return order.AsReadOnly(); }
		}

		public bool Has(string key)
		{
			return map.ContainsKey(key);
		}

		// null when the key isn't there.
		public Value Get(string key)
		{
			Value v;
			return map.TryGetValue(key, out v) ? v : null;
		}

		public void Set(string key, Value value)
		{
			if (!map.ContainsKey(key))
			{
				order.Add(key);
			}
			map[key] = value ?? Value.None;
		}
	}
}
