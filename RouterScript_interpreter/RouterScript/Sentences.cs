using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;

namespace VerbalCommands.RouterScript
{
	// Brief 17: sentences with slots, the core of the router language.
	//
	// A template is text with {SLOTS} and [optional parts]:
	//   "storage near {BENCH}[ in {ROOM}] holds only {THINGS}."
	// fill() puts values into the slots (a list becomes "a, b and c"); parse() runs the same template
	// backwards over a sentence and gives back the slot texts. One template, two readers: the player
	// reads the filled sentence, and the router reads the model's sentences with it.
	internal static class Sentences
	{
		private enum PartKind
		{
			Literal,
			Slot,
			Optional
		}

		private sealed class Part
		{
			public PartKind kind;
			public string text;                 // Literal: the text; Slot: the slot's name
			public List<Part> children;         // Optional: what's inside the brackets
		}

		private sealed class Template
		{
			public List<Part> forFill;
			public List<Part> forParse;         // trimmed, one trailing '.' removed
		}

		private static readonly Dictionary<string, Template> cache = new Dictionary<string, Template>(StringComparer.Ordinal);
		private const int CacheSize = 256;

		// parse() gives up after this many matching steps (templates with many slots next to each
		// other can take very long on long text).
		private const int MaxMatchSteps = 200000;

		// parse() matches recursively, one level per part, so templates have a size cap.
		private const int MaxParts = 200;

		private static Template GetTemplate(string template)
		{
			lock (cache)
			{
				Template t;
				if (cache.TryGetValue(template, out t))
				{
					return t;
				}
				t = new Template();
				t.forFill = Build(template);
				string p = template.Trim();
				if (p.EndsWith("."))
				{
					p = p.Substring(0, p.Length - 1).TrimEnd();
				}
				t.forParse = Build(p);
				if (cache.Count >= CacheSize)
				{
					cache.Clear();
				}
				cache[template] = t;
				return t;
			}
		}

		private static List<Part> Build(string template)
		{
			List<List<Part>> open = new List<List<Part>>();
			open.Add(new List<Part>());
			StringBuilder literal = new StringBuilder();
			int i = 0;
			while (i < template.Length)
			{
				char c = template[i];
				if (c == '{')
				{
					int close = template.IndexOf('}', i + 1);
					if (close < 0)
					{
						throw new ScriptError("the template \"" + template + "\" has a '{' without a matching '}'.");
					}
					string name = template.Substring(i + 1, close - i - 1);
					if (!IsSlotName(name))
					{
						throw new ScriptError("the template \"" + template + "\" has a bad slot {" + name + "}; slot names are letters, digits and '_'.");
					}
					FlushLiteral(literal, open[open.Count - 1]);
					Part slot = new Part();
					slot.kind = PartKind.Slot;
					slot.text = name;
					open[open.Count - 1].Add(slot);
					i = close + 1;
					continue;
				}
				if (c == '}')
				{
					throw new ScriptError("the template \"" + template + "\" has a '}' without a matching '{'.");
				}
				if (c == '[')
				{
					FlushLiteral(literal, open[open.Count - 1]);
					open.Add(new List<Part>());
					if (open.Count > 20)
					{
						throw new ScriptError("the template has optional parts nested too deeply (more than 19 levels).");
					}
					i++;
					continue;
				}
				if (c == ']')
				{
					if (open.Count == 1)
					{
						throw new ScriptError("the template \"" + template + "\" has a ']' without a matching '['.");
					}
					FlushLiteral(literal, open[open.Count - 1]);
					Part optional = new Part();
					optional.kind = PartKind.Optional;
					optional.children = open[open.Count - 1];
					open.RemoveAt(open.Count - 1);
					open[open.Count - 1].Add(optional);
					i++;
					continue;
				}
				literal.Append(c);
				i++;
			}
			if (open.Count > 1)
			{
				throw new ScriptError("the template \"" + template + "\" has a '[' without a matching ']'.");
			}
			FlushLiteral(literal, open[0]);
			if (CountParts(open[0]) > MaxParts)
			{
				throw new ScriptError("the template is too long (more than " + MaxParts + " slots, brackets and text pieces).");
			}
			return open[0];
		}

		private static int CountParts(List<Part> parts)
		{
			int n = parts.Count;
			foreach (Part p in parts)
			{
				if (p.kind == PartKind.Optional)
				{
					n += CountParts(p.children);
				}
			}
			return n;
		}

		private static void FlushLiteral(StringBuilder literal, List<Part> into)
		{
			if (literal.Length == 0)
			{
				return;
			}
			Part p = new Part();
			p.kind = PartKind.Literal;
			p.text = literal.ToString();
			into.Add(p);
			literal.Length = 0;
		}

		private static bool IsSlotName(string name)
		{
			if (name.Length == 0)
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

		// ---- fill ----

		// Every slot outside [...] must be in slots (and not none). An optional part is written only
		// when it has at least one slot of its own and all of its own slots are given.
		public static string Fill(string template, ScriptDict slots)
		{
			StringBuilder sb = new StringBuilder();
			FillParts(GetTemplate(template).forFill, slots, sb);
			return sb.ToString();
		}

		private static void FillParts(List<Part> parts, ScriptDict slots, StringBuilder sb)
		{
			foreach (Part p in parts)
			{
				switch (p.kind)
				{
					case PartKind.Literal:
						sb.Append(p.text);
						break;
					case PartKind.Slot:
					{
						Value v = slots.Get(p.text);
						if (v == null || v.IsNone)
						{
							throw new ScriptError("'fill' needs a value for the slot {" + p.text + "}, but the slots don't have one.");
						}
						sb.Append(SlotText(v));
						Operations.CheckTextLength(sb.Length);
						break;
					}
					case PartKind.Optional:
					{
						bool anySlot = false;
						bool allGiven = true;
						foreach (Part child in p.children)
						{
							if (child.kind == PartKind.Slot)
							{
								anySlot = true;
								Value v = slots.Get(child.text);
								if (v == null || v.IsNone)
								{
									allGiven = false;
								}
							}
						}
						if (anySlot && allGiven)
						{
							FillParts(p.children, slots, sb);
						}
						break;
					}
				}
			}
		}

		private static string SlotText(Value v)
		{
			if (v.kind == ValueKind.List)
			{
				return JoinList(v.AsList);
			}
			return v.ToText();
		}

		// ---- parse ----

		// The slot texts (trimmed, as written in s, in template order), or null when s doesn't fit.
		// work = how many matching steps it took (the Runner counts them as script steps).
		public static ScriptDict Parse(string template, string s, out int work)
		{
			Matcher m = new Matcher();
			m.input = NormalizeSentence(s);
			List<Part> parts = GetTemplate(template).forParse;
			string input = m.input;
			bool ok = m.Sequence(parts, 0, 0, end => end == input.Length);
			work = m.steps;
			if (!ok)
			{
				return null;
			}
			ScriptDict result = new ScriptDict();
			foreach (KeyValuePair<string, string> binding in m.bindings)
			{
				result.Set(binding.Key, Value.FromText(binding.Value));
			}
			return result;
		}

		// Surrounding whitespace, wrapping backticks and one trailing '.' don't count.
		private static string NormalizeSentence(string s)
		{
			s = s.Trim();
			if (s.Length >= 2 && s[0] == '`' && s[s.Length - 1] == '`')
			{
				s = s.Trim('`').Trim();
			}
			if (s.EndsWith("."))
			{
				s = s.Substring(0, s.Length - 1).TrimEnd();
			}
			return s;
		}

		private sealed class Matcher
		{
			public string input;
			public List<KeyValuePair<string, string>> bindings = new List<KeyValuePair<string, string>>();
			public int steps;

			// Matches parts[i..] at pos, then whatever `rest` needs after that. Slots try the shortest
			// text first; optional parts are tried with their content first, then without.
			public bool Sequence(List<Part> parts, int i, int pos, Func<int, bool> rest)
			{
				steps++;
				if (steps > MaxMatchSteps)
				{
					throw new ScriptError("'parse' gave up: this template and text take too long to match.");
				}
				if (i == parts.Count)
				{
					return rest(pos);
				}
				Part p = parts[i];
				switch (p.kind)
				{
					case PartKind.Literal:
					{
						int end = MatchLiteral(p.text, pos);
						return end >= 0 && Sequence(parts, i + 1, end, rest);
					}
					case PartKind.Slot:
					{
						int bound = FindBinding(p.text);
						for (int end = pos + 1; end <= input.Length; end++)
						{
							string value = input.Substring(pos, end - pos).Trim();
							if (value.Length == 0)
							{
								continue;
							}
							if (bound >= 0)
							{
								// The same slot twice: both places must say the same thing.
								if (string.Equals(bindings[bound].Value, value, StringComparison.OrdinalIgnoreCase)
									&& Sequence(parts, i + 1, end, rest))
								{
									return true;
								}
								continue;
							}
							bindings.Add(new KeyValuePair<string, string>(p.text, value));
							if (Sequence(parts, i + 1, end, rest))
							{
								return true;
							}
							bindings.RemoveAt(bindings.Count - 1);
						}
						return false;
					}
					default:
					{
						int mark = bindings.Count;
						if (Sequence(p.children, 0, pos, after => Sequence(parts, i + 1, after, rest)))
						{
							return true;
						}
						bindings.RemoveRange(mark, bindings.Count - mark);
						return Sequence(parts, i + 1, pos, rest);
					}
				}
			}

			private int FindBinding(string name)
			{
				for (int i = 0; i < bindings.Count; i++)
				{
					if (bindings[i].Key == name)
					{
						return i;
					}
				}
				return -1;
			}

			// Case doesn't matter; a run of spaces in the template matches any run of whitespace.
			// Returns the position after the match, or -1.
			private int MatchLiteral(string literal, int pos)
			{
				int j = pos;
				int k = 0;
				while (k < literal.Length)
				{
					if (char.IsWhiteSpace(literal[k]))
					{
						while (k < literal.Length && char.IsWhiteSpace(literal[k]))
						{
							k++;
						}
						if (j >= input.Length || !char.IsWhiteSpace(input[j]))
						{
							return -1;
						}
						while (j < input.Length && char.IsWhiteSpace(input[j]))
						{
							j++;
						}
						continue;
					}
					if (j >= input.Length || char.ToLowerInvariant(input[j]) != char.ToLowerInvariant(literal[k]))
					{
						return -1;
					}
					j++;
					k++;
				}
				return j;
			}
		}

		// ---- lists in sentences ----

		private static readonly Regex ListSeparator = new Regex(@"\s*,\s*(?:and\s+)?|\s+and\s+", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

		// "a, b and c" / "a, b, and c" / "a and b" / "a" -> ["a", "b", "c"]; empty parts are dropped.
		public static List<string> SplitList(string s)
		{
			List<string> result = new List<string>();
			foreach (string part in ListSeparator.Split(s))
			{
				string trimmed = part.Trim();
				if (trimmed.Length > 0)
				{
					result.Add(trimmed);
				}
			}
			return result;
		}

		// ["a", "b", "c"] -> "a, b and c"; ["a", "b"] -> "a and b"; ["a"] -> "a"; [] -> "".
		public static string JoinList(List<Value> items)
		{
			StringBuilder sb = new StringBuilder();
			for (int i = 0; i < items.Count; i++)
			{
				if (i > 0)
				{
					sb.Append(i == items.Count - 1 ? " and " : ", ");
				}
				sb.Append(items[i].ToText());
			}
			return sb.ToString();
		}
	}
}
