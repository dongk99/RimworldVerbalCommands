# Builtins.cs, line by line

File: `src\RouterScript\Builtins.cs` (284 lines). Source tags: see `..\README.md`.

**What this file is:** the 22 built-in functions every script has, whatever the host provides. Comment
L17-19: "the language has no methods; everything is a call" (B17:50), and "Text functions compare
exactly (case matters) unless they say otherwise; parse and find_pattern ignore case" (R17-7). The list
is exactly B17:55-75. Every argument check throws a plain `ScriptError` that names the function and
which value was wrong (L193-227), and the Runner adds the line.

## L1-15: usings; `BuiltinFunction`
- `System.Text.RegularExpressions` for `find_pattern`.
- L9-15: a built-in's name, its value count (always fixed: min = max, L183-191) and its handler. The
  handler gets the `Runner` so it can charge extra steps for big work (`r.Charge`, Runner.cs:446-454).

## L20-34: the table
- L22 `all`: name → function, exact names.
- L24-26 `PatternTimeout = 1 second`: comment: "find_pattern gives up on one match after this long (a
  badly written pattern can take practically forever on some texts)". Why: B17:90 (never hang the
  game), D7. Test: `err_pattern_too_slow` (`"^(a+)+$"`).
- L27-28: compiled patterns are cached (up to 256; the cache is emptied when full, L274-277), so a
  pattern used in a loop isn't compiled again each time. `—` (performance).
- L30-34 `Find(name)`: used by the compiler (checking calls, Compiler.cs:562) and the host (refusing a
  host function named like a built-in, Script.cs:211).

## L36-181: the built-ins (registered once, in the static constructor)
- L38-50 **`len(x)`**: characters of text, items of a list, keys of a dict; anything else → `'len' needs
  text, a list or a dict, got a number.` (test `err_len_type`). B17:56.
- L51-56 **`text(x)`**: the value as text, exactly as `print` shows it (Value.cs:327-338): `text(3)` is
  "3", `text(["a"])` is `["a"]`. Size cap checked. B17:56. This is how a number becomes a dict key
  (`text(id)`), since dict keys must be text.
- L57-76 **`number(s)`**: a number stays a number; text that is a plain decimal number (`"12"`, `"-3"`,
  `"2.5"`, `" 7 "`) becomes one; anything else gives **none** (not an error). Comment L67: not `"1e5"`,
  `"1,000"` or `"abc"`. Invariant culture (a `.` decimal point on every PC). B17:56 ("`none` if not a
  number"). Because it gives none instead of an error, a script can use it to *test* whether a slot is
  a number: `router_lab\parse_results.txt:92-96` (`whole_number_between`) does exactly that for hours
  and priorities. Test: `builtins_text` lines 6-13.
- L77-79 **`lower(s)`, `upper(s)`, `trim(s)`**: invariant-culture case change (so it behaves the same on
  a Turkish PC); `trim` removes surrounding whitespace. B17:57.
- L80-93 **`replace(s, old, new)`**: every occurrence, case-sensitive. Empty `old` → `'replace' needs
  something to replace; its second value is empty text.` (test `err_replace_empty`). Size cap; charges
  steps for the result's length. B17:57.
- L94-104 **`split(s, sep)`**: splits on the exact separator, keeping empty pieces (`split("a,,b", ",")`
  is `["a", "", "b"]`). Empty separator → error (test `err_split_empty`). B17:57.
- L105-121 **`join(list, sep)`**: each item as `text()` shows it, separated by `sep`; size cap checked
  as it grows. B17:57. (Tests `err_join_not_list`.)
- L122-124 **`starts_with(s, p)`, `ends_with(s, p)`, `contains(s, part)`**: case-sensitive (`Ordinal`).
  B17:58; R17-7.
- L126-132 **`append(list, v)`**: adds to the end of that same list (it changes the list; shared lists
  change everywhere, Value.cs:10-11); returns none; size cap. B17:59. Test: `err_append_not_list`.
- L133-142 **`remove_at(list, i)`**: comment L133: removes the item at a position and gives it back.
  Position checked like `x[i]` (no negatives). Charges steps for the items shifted. B17:59. Test:
  `err_remove_at_range`.
- L143-148 **`keys(dict)`**: a new list of the keys, in first-set order. B17:59.
- L149-154 **`get(dict, key, default)`**: the value, or `default` when the key is missing (a key set to
  none gives none, not the default). B17:59. This and `has` are the safe ways to read a key that may be
  missing (the `d[key]` error message points to them, Operations.cs:181). Test: `err_get_not_dict`.
- L155 **`has(dict, key)`**: true/false. B17:59. Test: `err_has_key_type`.
- L157 **`find_pattern(pattern, s)`** → L232-255. B17:60-61.
- L158 **`split_list(s)`**: "a, b and c" → `["a", "b", "c"]` (Sentences.cs:412-427). B17:62.
- L159-164 **`join_list(list)`**: `["a", "b", "c"]` → "a, b and c" (Sentences.cs:429-442). B17:63.
- L165-171 **`fill(template, slots)`**: Sentences.Fill; size cap; charges steps. B17:65-67.
- L172-180 **`parse(template, s)`**: Sentences.Parse; charges the matching work it took as steps
  (L176-178); no match → none, else the dict of slots. B17:68-75.
- Why sentences are built-ins and not script code: they are "the core of the language" (B17:64), used
  on every order (D4).

## L183-191: `Add(name, count, handler)`
- Registers a built-in with a fixed number of values (no built-in takes a range).

## L193-227: argument checks
- L195-200 `Which(args, i)`: for one-value functions nothing; otherwise " as its first/second/third
  value".
- L202-209 `Text(args, i, fn)`: `'replace' needs text as its second value, got a number.` (tests
  `err_builtin_text_arg`, `err_builtin_second_arg`).
- L211-218 `List(...)`: `'append' needs a list as its first value, got text.`
- L220-227 `Dict(...)`: `'get' needs a dict as its first value, got a list.`
- Why: plain words naming the function and the value (B17:95-99, D5).

## L229-255: `find_pattern`
- Comment L231: `[whole match, group 1, ...]` (a group that took no part is none), or none when nothing
  matches.
- L234: the compiled pattern (cached).
- L236-243: runs **one** match (the first in the text); over 1 second → `the pattern "..." took too long
  to match (over 1 second).`
- L244-247: no match → none.
- L248-254: the whole match and every group, as text (none for a group that didn't take part).
- Only the first match: there is no "find all". A script that needs every match has to loop itself
  (e.g. `numbers_in` in `router_lab\parse_results.txt` walks the order's characters to find every
  number).

## L257-281: `GetPattern(pattern)`
- L259: `lock`: the cache is `static`, shared by every script run in the process, so two runs on two
  threads can't corrupt it. (Nothing runs two at once yet; `—`.)
- L268: .NET regex, **case-insensitive** and culture-invariant, with the 1-second timeout (B17:60
  "`.NET regex, case-insensitive`").
- L270-273: an invalid pattern → `"(abc" is not a valid pattern.` (test `err_pattern_invalid`).
- L274-278: cache full (256) → emptied, then this pattern added.
- Writing patterns: backslashes must be doubled inside script text (`"\\d+"`), because text only knows
  `\"`, `\\`, `\n` (Lexer.cs:344-369); R17 missing-list ("There is no raw text for regex").
