# Value.cs, line by line

File: `src\RouterScript\Value.cs` (558 lines). Source tags: see `..\README.md`.

**What this file is:** the one type every value of the language has, at run time and when crossing to
C#. B17:87-88: "Values crossing to C#: a small `Value` type (none, bool, number, string, list, dict),
plus easy conversion from/to C# strings, numbers, lists and dictionaries." It is `public` because the mod
(the host) builds and reads these when it gives the script data and gets results back (D3).

## L1-7: usings and namespace
- `System` (Convert, Math, ArgumentException), `System.Collections` (non-generic IDictionary /
  IEnumerable for `From`, L165-184), `System.Collections.Generic`, `System.Globalization` (invariant
  number text), `System.Text` (StringBuilder).

## L9-20: `ValueKind`
- Comment L9-11: one value is none, true/false, a number, text, a list or a dict. **Lists and dicts are
  shared, not copied**: giving a list a second name, or passing it to a function, gives both the same
  list. Why: B17 doesn't say; this is the agent's choice, recorded only in this code comment (`code`),
  with no reason given. Consequence: it is the only way a function can change global state, because
  functions can't assign globals (R17-2, R17 missing-list: "state has to go through shared dicts or
  lists").
- L14-19: the six kinds, exactly B17:87-88's list. Why six and no more: `—` beyond B17 (no separate
  integer type: one Number kind, a double).

## L22-68: fields and private constructors
- L24-26: shared single instances for none, true, false (no need to allocate them again).
- L28 `kind`; L29-33 one field per kind; only the one matching `kind` is used.
- L35-68: one private constructor per kind. Private so outside code goes through the `From*` makers
  below (which turn C# null into none, L83-86, and copy lists, L94-105).

## L70-135: making values (C# → script)
- L72-75 `FromBool`: returns the shared True/False.
- L77-80 `FromNumber`.
- L82-86 `FromText`: C# `null` becomes `none` (comment L82), so a host that returns a null string
  never produces a broken value.
- L88-91 `NewList`: an empty script list.
- L93-105 `FromList(items)`: *copies* the items into a new script list (comment L93); a null item
  becomes none (L101).
- L107-119 `FromStrings(items)`: a list of texts (null → none). Used by `split`, `keys`, `split_list`,
  `read_lines` and the lab map.
- L121-124 `NewDict`.
- L126-135 `WrapList` / `WrapDict`: `internal`, **no copy** (comment L126 "For the interpreter"): the
  runner builds a list and hands it over without copying it again (Runner.cs:158, 175).
- L137-186 `From(object o)`: converts plain C# data (comment L137-139):
  - L142-145 null → none; L146-150 already a Value → itself; L151-155 string → text; L156-159 bool;
  - L160-164 any C# number type → a double, via the invariant culture;
  - L165-174 any `IDictionary` → a dict, keys turned into text with `Convert.ToString` (L171), values
    converted recursively. Why keys become text: dict keys are text in the language (B17:35);
  - L175-184 any other `IEnumerable` → a list, items converted recursively (strings are caught first at
    L151, so a string never becomes a list of characters);
  - L185: anything else **throws** `ArgumentException`. Comment L138-139: that is a mistake in the
    host's C# code (a mod bug), never a script problem, so it is allowed to throw (only script problems
    must never throw, B17:101-102).
  - Test: `host_functions` uses `test_from_csharp` (Program.cs:399-409) and `test_convert` (L397).
- L188-206: implicit conversions so C# can write `Value v = "text"`, `= 2.5`, `= 3`, `= true`.
  Convenience for the host (B17:88 "easy conversion"). `—` otherwise.

## L208-266: reading values (script → C#)
- L210-213 `IsNone`.
- L215-219 `AsBool`: false unless this *is* true (not truthiness; see `IsTruthy`).
- L221-225 `AsNumber`: 0 unless a number. L227-231 `AsText`: null unless text.
- L233-237 `AsList`, L239-243 `AsDict`: the live list/dict itself (changes are seen by the script), or
  null. Comments L233, L239.
- L245-266 `IsTruthy`: `false`, `none`, `0`, `""`, `[]` and `{}` are false; everything else is true
  (comment L245). Exactly B17:51. Used by `if`, `while`, `not`, `and`/`or` (Runner.cs:235-247).

## L268-306: `ToObject()`: script value → plain C# data
- Comment L268-269: null, bool, double, string, `List<object>`, `Dictionary<string, object>`, as a
  **new copy** (changing it doesn't change the script's value).
- L275-306: recursive; past `MaxNesting` (100) levels it gives null (L277-280) so a list that contains
  itself can't recurse forever. Why: `—` (safety; a script can build `a = []`, `append(a, a)`).

## L308-325: `ToStringList()`
- Comment L308-309: a list's items as text (each as `text()` would show it); a single text becomes a
  one-item list; none becomes an empty list. Written for the mod ("the list helper the mod will use",
  comment at Program.cs:410); nothing in the mod uses it yet (the mod isn't connected). Test:
  `test_to_strings` in `host_functions`.

## L327-343: `ToText()` / `ToString()`
- Comment L327-328: what `text(x)` and `print(x)` show. Text as it is (L331-334); everything else via
  `Render` (L335-337). `ToString` (L340-343) does the same so C# string concatenation and debuggers show
  the same thing.

## L345-405: `Render`
- L345-346 `MaxNesting = 100` (comment: lists inside lists stop being written out past this depth).
- L350-354: past the depth → `...`.
- L357-365: `none`, `true`/`false`, numbers via `FormatNumber` (no trailing `.0`).
- L366-375: text at the top level is written bare; text *inside* a list or dict is quoted (L373). So
  `text(["a", 1])` is `["a", 1]`, written "the way the script would write them" (comment L328).
- L376-387: a list as `[a, b]`; L388-403: a dict as `{"k": v}` in key order.

## L407-430: `AppendQuoted`
- Writes text in double quotes, escaping `"`, `\` and newline the same three ways the lexer reads them
  (Lexer.cs:351-362), so printed values could be pasted back into a script.

## L432-440: `FormatNumber(d)`
- Comment L432: whole numbers without a decimal point ("3"); others as short as they can be ("0.5").
- L435-438: whole and smaller than 1e15 → written as a long integer. L439: otherwise .NET's round-trip
  format `"R"` (shortest text that reads back as the same double), invariant culture.
- Why: player-facing text must not show "3.0" or "3,0" (D5 plain words); `—` for the exact cut-off.

## L442-460: `Describe(v)`
- Comment L442: plain words for error messages. none → "none", bools → "true"/"false", then "a number",
  "text", "a list", "a dict". Used in every type error (e.g. `'*' needs two numbers, got text and a
  number.`). Why: no C# type names in messages (B17:99, D5).

## L462-516: `AreEqual(a, b)` (what `==` means)
- Comment L462: same kind and same content; lists and dicts compare item by item.
- L470-473: the same object → equal (fast path; also stops a list-inside-itself compare).
- L474-477: different kinds → never equal (so `1 == "1"` is false, no conversion). Past MaxNesting →
  false.
- L480-487: none = none; bools and numbers by value; **text by exact, case-sensitive comparison**
  (`StringComparison.Ordinal`, L487). Why case-sensitive: the agent's choice (R17-7: "`==`, `<`, `in`,
  `starts_with`, `ends_with` and `contains` are case-sensitive. Only `parse` and `find_pattern` ignore
  case."). Consequence for scripts: call `lower()` on both sides to compare names.
- L488-500: lists: same length and every item equal, in order.
- L501-514: dicts: same number of keys and every key's value equal (key order doesn't matter).

## L519-556: `ScriptDict`
- Comment L519-520: text keys; values kept in the order the keys were **first** set; that order is what
  `for key in dict` and `keys(dict)` give. Why: B17:40 ("`for key in dict:` (keys, in insertion
  order)"); R17-4.
- L523 `order`: the keys in first-set order; L524 `map`: key → value, exact (ordinal, case-sensitive)
  keys.
- L526-529 `Count`; L531-534 `Keys`: read-only view of the order.
- L536-539 `Has`.
- L541-546 `Get`: null (C# null, not none) when the key is missing (comment L541), so callers can tell
  "missing" from "set to none". `get(dict, key, default)` relies on that (Builtins.cs:149-154).
- L548-555 `Set`: a new key is added to the end of the order (L550-553); an existing key keeps its place
  and gets the new value. A C# null value is stored as none (L554).
- There is no delete: the language has no way to remove a dict key (R17 missing-list: "delete a dict
  key").
