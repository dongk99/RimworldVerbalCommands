# Operations.cs, line by line

File: `src\RouterScript\Operations.cs` (248 lines). Source tags: see `..\README.md`.

**What this file is:** what each operator and `x[i]` does. Comment L7-8: problems throw `ScriptError`
with a plain message; the Runner adds the file and line (Runner.cs:333-336). Operators are listed in
B17:46-49.

## L1-9: usings, namespace, class.

## L11-13: size caps
- Comment L11: "A broken script must not eat the game's memory: text and lists have a size cap."
  `MaxTextLength` and `MaxListLength` are 1,000,000. Why: B17:90 (a broken router must never crash the
  game), D7; the numbers are the agent's (R17-14). Messages at L231-245.

## L15-41: `Binary(op, left, right, runner)`
- Dispatches by operator name: `+` → `Add`; `- * / %` → `Arithmetic`; `==`/`!=` → `Value.AreEqual`
  (same kind and content, case-sensitive text, Value.cs:462-516); `< > <= >=` → `Compare`; `in` / `not
  in` → `In`.
- L40: an unknown operator name can't come from the parser; the message is a safety net.

## L43-71: `Add` (`+`)
- L45-48: number + number.
- L49-55: text + text joins them (B17:49 "`+` also joins two strings or two lists"); checks the size cap
  and charges steps for the new length (L52-53).
- L56-64: list + list gives a **new** list (the originals are unchanged); size cap and charge.
- L65-70: anything else (e.g. text + number) → `'+' can't join text and a number; use text(...) to turn
  the other value into text first.` — no automatic conversion. The hint is added when one side is text
  (L66-69). Tests: `err_add_types`, `err_add_list_number`.

## L73-100: `Arithmetic` (`- * / %`)
- L75-78: both sides must be numbers: `'*' needs two numbers, got text and a number.` (test
  `err_arith_types`).
- L83-86: `-`, `*`.
- L87-92: `/` by zero → `can't divide by zero.`; otherwise a decimal result (`7 / 2` is `3.5`; R17-6 "`/`
  always gives a decimal"). There is no whole-number division; the agent used `n - n % 1` to drop the
  fraction (R17 missing-list).
- L93-98: `%` by zero → `can't divide by zero (in '%').`; otherwise C#'s remainder, which keeps the sign
  of the left side: `-7 % 3` is `-1` (R17-6). Tests: `err_divide_zero`, `err_modulo_zero`.

## L102-128: `Compare` (`< > <= >=`)
- L105-108: two numbers.
- L109-112: two texts, compared by character code (`CompareOrdinal`): case-sensitive, and all capital
  letters sort before all small letters (`"Zoe" < "adam"` is true). R17-7.
- L113-116: anything else → `'<' can only compare two numbers or two texts, got text and a number.`
  (test `err_compare_types`).
- L117-127: turns the comparison result into true/false for each operator.

## L130-155: `In` (`in`, `not in`)
- Comment L130: list membership, dict key, or part of a text (B17:47-48).
- L135-143: list: any item equal to it (by `AreEqual`).
- L144-145: dict: has that key (the key must be text, `DictKey`).
- L146-151: text: the left side must be text too (`'in' with text on its right needs text on its left,
  got a number.`); true if it appears anywhere, case-sensitive (L151, `Ordinal`).
- L152-153: anything else on the right → `'in' needs a list, a dict or text on its right, got a
  number.`

## L157-164: `DictKey(key)`
- A dict key must be text → otherwise `dict keys are text, got a number.` (B17:35). Used by `in`,
  indexing, `get`, `has`. (Room ids are numbers, so a script stores them as `text(id)` keys; see
  router_lab\locations.txt.)

## L166-188: `GetItem(target, index)` (`x[i]`)
- L171-172: list → the item at a checked position.
- L173-174: text → the one character at that position, as text (B17:35 indexing; R17-5 "Text can be read
  by position (`s[i]`)").
- L175-184: dict → the value for that key; a missing key is an error with a hint: `the dict has no key
  "rooms"; use get(dict, key, default) or has(dict, key) when a key may be missing.` (not none; so a typo
  in a key is caught instead of silently giving none).
- L185-186: anything else → `can't take an item out of a number; only lists, dicts and text have items.`

## L190-205: `SetItem(target, index, value)` (`x[i] = v`)
- L194-196: list: replace the item at a checked position (can't grow the list; use `append`).
- L197-199: dict: set the key (adds it if new).
- L200-201: text → `text can't be changed one character at a time; make new text with +, replace or
  join.` (R17-5: "but not changed").
- L202-203: anything else → `can't set an item of a number; only lists and dicts can be changed that
  way.`
- Tests: `err_set_item_text`, `err_set_item_number`, `err_dict_missing_key`, `err_dict_index_key`,
  `err_in_right_side`, `err_in_text_left`.

## L207-229: `Position(index, count, what, unit)`
- Comment L207: a checked 0-based position, **no negative positions** (R17-5). So `x[-1]` is an error,
  not "the last item" (R17 missing-list: "last item").
- L210-213: must be a number; L214-218: must be whole (`a list position must be a whole number, got
  1.5.`); L219-222: `position -1 is before the start of the list; the first position is 0.`; L223-227:
  `position 3 is past the end of the list (it has 3 items).` — singular "item"/"character" when the count
  is 1 (L226). Tests: `indexing`, `err_index_past_end`, `err_index_negative`, `err_index_fraction`,
  `err_index_not_number`, `err_index_text_past_end`, `err_index_number`, `err_set_index_past_end`,
  `err_remove_at_range`.

## L231-245: size-cap checks
- `the text got too long (over 1,000,000 characters).` / `the list got too long (over 1,000,000 items).`
  Called before any join, append, replace, fill etc. makes something bigger.
