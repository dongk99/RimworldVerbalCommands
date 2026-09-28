using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace VerbalCommands.RouterScript
{
	internal sealed class BuiltinFunction
	{
		public string name;
		public int minArgs;
		public int maxArgs;
		public Func<Runner, Value[], Value> handler;
	}

	// Brief 17: the built-in functions (the language has no methods; everything is a call).
	// Text functions compare exactly (case matters) unless they say otherwise; parse and
	// find_pattern ignore case.
	internal static class Builtins
	{
		private static readonly Dictionary<string, BuiltinFunction> all = new Dictionary<string, BuiltinFunction>(StringComparer.Ordinal);

		// find_pattern gives up on one match after this long (a badly written pattern can take
		// practically forever on some texts).
		private static readonly TimeSpan PatternTimeout = TimeSpan.FromSeconds(1);
		private static readonly Dictionary<string, Regex> patternCache = new Dictionary<string, Regex>(StringComparer.Ordinal);
		private const int PatternCacheSize = 256;

		public static BuiltinFunction Find(string name)
		{
			BuiltinFunction f;
			return name != null && all.TryGetValue(name, out f) ? f : null;
		}

		static Builtins()
		{
			Add("len", 1, (r, a) =>
			{
				switch (a[0].kind)
				{
					case ValueKind.Text:
						return Value.FromNumber(a[0].AsText.Length);
					case ValueKind.List:
						return Value.FromNumber(a[0].AsList.Count);
					case ValueKind.Dict:
						return Value.FromNumber(a[0].AsDict.Count);
				}
				throw new ScriptError("'len' needs text, a list or a dict, got " + Value.Describe(a[0]) + ".");
			});
			Add("text", 1, (r, a) =>
			{
				string s = a[0].ToText();
				Operations.CheckTextLength(s.Length);
				return Value.FromText(s);
			});
			Add("number", 1, (r, a) =>
			{
				if (a[0].kind == ValueKind.Number)
				{
					return a[0];
				}
				if (a[0].kind != ValueKind.Text)
				{
					return Value.None;
				}
				// Plain decimal numbers only: "12", "-3", "2.5", " 7 ". Not "1e5", "1,000" or "abc".
				double d;
				if (double.TryParse(a[0].AsText, NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint
					| NumberStyles.AllowLeadingWhite | NumberStyles.AllowTrailingWhite, CultureInfo.InvariantCulture, out d)
					&& !double.IsInfinity(d))
				{
					return Value.FromNumber(d);
				}
				return Value.None;
			});
			Add("lower", 1, (r, a) => Value.FromText(Text(a, 0, "lower").ToLowerInvariant()));
			Add("upper", 1, (r, a) => Value.FromText(Text(a, 0, "upper").ToUpperInvariant()));
			Add("trim", 1, (r, a) => Value.FromText(Text(a, 0, "trim").Trim()));
			Add("replace", 3, (r, a) =>
			{
				string s = Text(a, 0, "replace");
				string old = Text(a, 1, "replace");
				string replacement = Text(a, 2, "replace");
				if (old.Length == 0)
				{
					throw new ScriptError("'replace' needs something to replace; its second value is empty text.");
				}
				string result = s.Replace(old, replacement);
				Operations.CheckTextLength(result.Length);
				r.Charge(result.Length);
				return Value.FromText(result);
			});
			Add("split", 2, (r, a) =>
			{
				string s = Text(a, 0, "split");
				string sep = Text(a, 1, "split");
				if (sep.Length == 0)
				{
					throw new ScriptError("'split' needs a separator; its second value is empty text.");
				}
				r.Charge(s.Length);
				return Value.FromStrings(s.Split(new string[] { sep }, StringSplitOptions.None));
			});
			Add("join", 2, (r, a) =>
			{
				List<Value> list = List(a, 0, "join");
				string sep = Text(a, 1, "join");
				StringBuilder sb = new StringBuilder();
				for (int i = 0; i < list.Count; i++)
				{
					if (i > 0)
					{
						sb.Append(sep);
					}
					sb.Append(list[i].ToText());
					Operations.CheckTextLength(sb.Length);
				}
				r.Charge(sb.Length);
				return Value.FromText(sb.ToString());
			});
			Add("starts_with", 2, (r, a) => Value.FromBool(Text(a, 0, "starts_with").StartsWith(Text(a, 1, "starts_with"), StringComparison.Ordinal)));
			Add("ends_with", 2, (r, a) => Value.FromBool(Text(a, 0, "ends_with").EndsWith(Text(a, 1, "ends_with"), StringComparison.Ordinal)));
			Add("contains", 2, (r, a) => Value.FromBool(Text(a, 0, "contains").IndexOf(Text(a, 1, "contains"), StringComparison.Ordinal) >= 0));

			Add("append", 2, (r, a) =>
			{
				List<Value> list = List(a, 0, "append");
				Operations.CheckListLength(list.Count + 1L);
				list.Add(a[1]);
				return Value.None;
			});
			// Removes the item at a position and gives it back.
			Add("remove_at", 2, (r, a) =>
			{
				List<Value> list = List(a, 0, "remove_at");
				int i = Operations.Position(a[1], list.Count, "list", "items");
				Value removed = list[i];
				list.RemoveAt(i);
				r.Charge(list.Count);
				return removed;
			});
			Add("keys", 1, (r, a) =>
			{
				ScriptDict dict = Dict(a, 0, "keys");
				r.Charge(dict.Count);
				return Value.FromStrings(dict.Keys);
			});
			Add("get", 3, (r, a) =>
			{
				ScriptDict dict = Dict(a, 0, "get");
				Value v = dict.Get(Operations.DictKey(a[1]));
				return v ?? a[2];
			});
			Add("has", 2, (r, a) => Value.FromBool(Dict(a, 0, "has").Has(Operations.DictKey(a[1]))));

			Add("find_pattern", 2, (r, a) => FindPattern(Text(a, 0, "find_pattern"), Text(a, 1, "find_pattern")));
			Add("split_list", 1, (r, a) => Value.FromStrings(Sentences.SplitList(Text(a, 0, "split_list"))));
			Add("join_list", 1, (r, a) =>
			{
				string s = Sentences.JoinList(List(a, 0, "join_list"));
				Operations.CheckTextLength(s.Length);
				return Value.FromText(s);
			});
			Add("fill", 2, (r, a) =>
			{
				string s = Sentences.Fill(Text(a, 0, "fill"), Dict(a, 1, "fill"));
				Operations.CheckTextLength(s.Length);
				r.Charge(s.Length);
				return Value.FromText(s);
			});
			Add("parse", 2, (r, a) =>
			{
				string template = Text(a, 0, "parse");
				string s = Text(a, 1, "parse");
				int work;
				ScriptDict slots = Sentences.Parse(template, s, out work);
				r.Charge(work);
				return slots == null ? Value.None : Value.WrapDict(slots);
			});
		}

		private static void Add(string name, int argCount, Func<Runner, Value[], Value> handler)
		{
			BuiltinFunction f = new BuiltinFunction();
			f.name = name;
			f.minArgs = argCount;
			f.maxArgs = argCount;
			f.handler = handler;
			all[name] = f;
		}

		// ---- Argument checks ----

		private static readonly string[] Ordinals = { "first", "second", "third" };

		private static string Which(Value[] args, int i)
		{
			return args.Length == 1 ? "" : " as its " + Ordinals[i] + " value";
		}

		private static string Text(Value[] args, int i, string function)
		{
			if (args[i].kind != ValueKind.Text)
			{
				throw new ScriptError("'" + function + "' needs text" + Which(args, i) + ", got " + Value.Describe(args[i]) + ".");
			}
			return args[i].AsText;
		}

		private static List<Value> List(Value[] args, int i, string function)
		{
			if (args[i].kind != ValueKind.List)
			{
				throw new ScriptError("'" + function + "' needs a list" + Which(args, i) + ", got " + Value.Describe(args[i]) + ".");
			}
			return args[i].AsList;
		}

		private static ScriptDict Dict(Value[] args, int i, string function)
		{
			if (args[i].kind != ValueKind.Dict)
			{
				throw new ScriptError("'" + function + "' needs a dict" + Which(args, i) + ", got " + Value.Describe(args[i]) + ".");
			}
			return args[i].AsDict;
		}

		// ---- find_pattern ----

		// [whole match, group 1, ...] (a group that took no part is none), or none when nothing matches.
		private static Value FindPattern(string pattern, string s)
		{
			Regex regex = GetPattern(pattern);
			Match m;
			try
			{
				m = regex.Match(s);
			}
			catch (RegexMatchTimeoutException)
			{
				throw new ScriptError("the pattern \"" + pattern + "\" took too long to match (over 1 second).");
			}
			if (!m.Success)
			{
				return Value.None;
			}
			List<Value> result = new List<Value>();
			for (int i = 0; i < m.Groups.Count; i++)
			{
				Group g = m.Groups[i];
				result.Add(g.Success ? Value.FromText(g.Value) : Value.None);
			}
			return Value.WrapList(result);
		}

		private static Regex GetPattern(string pattern)
		{
			lock (patternCache)
			{
				Regex regex;
				if (patternCache.TryGetValue(pattern, out regex))
				{
					return regex;
				}
				try
				{
					regex = new Regex(pattern, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant, PatternTimeout);
				}
				catch (ArgumentException)
				{
					throw new ScriptError("\"" + pattern + "\" is not a valid pattern.");
				}
				if (patternCache.Count >= PatternCacheSize)
				{
					patternCache.Clear();
				}
				patternCache[pattern] = regex;
				return regex;
			}
		}
	}
}
