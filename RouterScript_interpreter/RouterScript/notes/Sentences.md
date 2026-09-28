# Sentences.cs, line by line

File: `src\RouterScript\Sentences.cs` (445 lines). Source tags: see `..\README.md`.

**What this file is:** "sentences with slots, the core of the router language" (comment L8; B17:64).
Comment L10-14: a template is text with `{SLOTS}` and `[optional parts]`, e.g.
`"storage near {BENCH}[ in {ROOM}] holds only {THINGS}."`; `fill()` puts values into the slots (a list
becomes "a, b and c"); `parse()` runs the same template backwards over a sentence and gives back the slot
texts. **"One template, two readers: the player reads the filled sentence, and the router reads the
model's sentences with it."** Why: this is the user's design (D4): the pseudocode's
`# every template fills into a full sentence a player can read as-is. # same sentences go to the model:
one text, two readers (player + model).` (`spatial_context_pseudocode.md:5-6`), and B17:9-10.

## L1-5: usings (`Regex` for `split_list`'s separator).

## L17-35: the parsed template
- L17-22 `PartKind`: a piece of a template is literal text, a slot, or an optional part.
- L24-29 `Part`: the text (or the slot's name), and for an optional part its children.
- L31-35 `Template`: two versions of each template: `forFill` exactly as written, and `forParse`
  trimmed with one trailing `.` removed (comment L34), because `parse` ignores a trailing full stop on
  the sentence (L279-292) and must ignore it on the template the same way.

## L37-45: cache and caps
- L37-38: parsed templates are cached (256, emptied when full), so a template used in a loop is only
  cut into parts once. `—` (performance; no reason recorded).
- L40-42 `MaxMatchSteps = 200000`: comment: parse gives up after this many matching steps ("templates
  with many slots next to each other can take very long on long text"). Test: `err_parse_gives_up`.
- L44-45 `MaxParts = 200`: comment: parse matches recursively, one level per part, so templates have a
  size cap (otherwise a huge template could overflow the C# stack). Test: `err_template_too_long`.
- Why caps: B17:90, D7.

## L47-71: `GetTemplate(template)`
- L49: `lock` (the cache is shared).
- L57: builds the fill version.
- L58-63: the parse version: trimmed, and one trailing `.` (and the spaces before it) removed.
- L64-68: stores it.

## L73-145: `Build(template)`: template text → parts
- L75-76: a stack of open part-lists (`open`); the bottom one is the template itself.
- L77: collects literal text until a `{`, `[` or `]`.
- L82-101 `{NAME}`: needs a closing `}` (else `the template "..." has a '{' without a matching '}'.`);
  the name must be letters, digits and `_` (else `has a bad slot {bad name}; slot names are letters,
  digits and '_'.`); becomes a Slot part.
- L102-105: a `}` with no `{` → error.
- L106-116 `[`: starts an optional part; more than 19 levels inside each other → error.
- L117-131 `]`: closes the current optional part (a `]` with no `[` → error).
- L132-133: any other character is literal text.
- L135-138: an optional part never closed → error.
- L140-143: more than 200 parts in total → error.
- Tests: `err_template_open_bracket`, `err_template_close_bracket`, `err_template_open_brace`,
  `err_template_close_brace`, `err_template_slot_name`, `err_template_nested_deep`,
  `err_template_too_long`.
- Note: a template's `{`, `}`, `[`, `]` are always special; a sentence form can't contain those
  characters as plain text. `—`.

## L147-187: helpers
- L147-158 `CountParts`: counts parts including those inside optional parts.
- L160-171 `FlushLiteral`: turns collected text into a Literal part.
- L173-187 `IsSlotName`: ASCII letters, digits, `_`; not empty.

## L189-253: `fill`
- Comment L191-192: **every slot outside `[...]` must be given (and not none). An optional part is
  written only when it has at least one slot of its own and all of its own slots are given.**
- L193-198 `Fill`: fills the parts into a StringBuilder.
- L206-208: literal text is copied as is.
- L209-219: a slot: missing or none → `'fill' needs a value for the slot {ROOMS}, but the slots don't
  have one.` (B17:67 "A missing slot is an error naming it"; tests `err_fill_missing_slot`,
  `err_fill_none_slot`). Otherwise its text; size cap.
- L220-241: an optional part: written only if it has a slot and all its slots have values (L236-239).
  An optional part with no slots of its own (e.g. `[ please]`) is never written by `fill`. R17-8 (the
  agent's choice: "A slot given `none` counts as missing, and an optional part with no slots is never
  written").
  Example: `fill("storage near {BENCH}[ in {ROOM}] holds only {THINGS}.", {"BENCH": "brewery",
  "THINGS": ["beer"]})` → "storage near brewery holds only beer." — the `[ in {ROOM}]` part drops out.
- L246-253 `SlotText`: a list slot is joined as "a, b and c" (`JoinList`); anything else as `text()`
  shows it. B17:66-67 ("A list slot is joined with `join_list`").

## L255-292: `parse`
- Comment L257-258: the slot texts (trimmed, as written in the sentence, in template order), or null
  when the sentence doesn't fit; `work` = how many matching steps it took (the Runner counts them as
  script steps, Builtins.cs:176-178).
- L261-265: prepares a matcher over the normalised sentence (L280) and the parse version of the template.
- L265: the whole template must match the **whole** sentence (the final check `end == input.Length`).
- L267-270: no match → null (the script gets none).
- L271-276: a dict of slot name → text. **Slot values are always text**; a list slot must be split by
  the script with `split_list` (B17:71). Case is kept as the sentence wrote it (only the *matching*
  ignores case).
- L279-292 `NormalizeSentence`: comment L279: surrounding whitespace, wrapping backticks and one trailing
  `.` don't count. L283-286: backticks are removed only when they wrap **both** ends (R17-9); L287-290:
  one trailing `.` and the spaces before it. Why: B17:69 ("Matching ignores case, surrounding
  whitespace, one trailing `.`, and wrapping backticks") — Haiku wrapped a line in backticks in the
  first lab run (old handoff §3: "issues: backticks (parse now strips them)").

## L294-408: `Matcher`: the backwards run
- L296-298: the sentence, the slot bindings found so far (in template order), and the step counter.
- L300-301 comment: matches `parts[i..]` at `pos`, then whatever `rest` needs after that. **Slots try the
  shortest text first; optional parts are tried with their content first, then without.**
- L304-308: every call is one step; over 200,000 → `'parse' gave up: this template and text take too
  long to match.`
- L309-312: all parts matched → does the rest also match from here?
- L316-320 literal: must match here (L377-407); then the next part.
- L321-349 **slot**:
  - L324: tries every possible end, shortest first (B17:70: "A slot matches the shortest text that lets
    the rest of the template match"). Consequence: in `put {THINGS} in storage {PLACE}` the THINGS slot
    stops at the *first* " in storage " that lets the rest match.
  - L326-330: the slot's text is trimmed; empty text is never a match (slots can't be empty, R17-9).
  - L331-340: the same slot name twice in one template: the second place must say the same thing,
    case aside (comment L333; R17-9).
  - L341-346: otherwise bind it, try the rest; if the rest fails, unbind and try a longer text.
- L350-359 **optional part**: first try with the part's content (L353), then without (L357-358),
  removing any bindings the failed attempt made. A slot inside an optional part that didn't match is
  simply absent from the dict (B17:74-75).
- L363-373 `FindBinding(name)`: whether the slot is already bound.
- L375-407 `MatchLiteral(literal, pos)`: comment L375-376: case doesn't matter; a run of spaces in the
  template matches any run of whitespace in the sentence (L383-398; so "holds  only" with two spaces
  still matches). Returns the position after the match, or -1. Letters compared with
  `ToLowerInvariant` (L399). Why ignore case: B17:69.

## L410-442: lists in sentences
- L412 `ListSeparator`: a comma (with an optional "and" after it), or the word "and" between spaces,
  case-insensitive.
- L414-427 `SplitList(s)`: comment L414: "a, b and c" / "a, b, and c" / "a and b" / "a" → `["a", "b",
  "c"]`; empty parts are dropped. B17:62. Known effect: it also splits a name that contains " and "
  ("salt and pepper" → `["salt", "pepper"]`) (R17-10). The script must not split a slot that can hold
  such a name.
- L429-442 `JoinList(items)`: comment L429: `["a","b","c"]` → "a, b and c"; `["a","b"]` → "a and b";
  `["a"]` → "a"; `[]` → "". No comma before "and" (the form `split_list` also reads). B17:63.
- Why lists are written this way: they are the list form the player reads and the model writes in the
  same sentences (D4). B17:65-67's example: `fill("{PAWNS} may only go in {ROOMS}.", {"PAWNS": "Alice",
  "ROOMS": ["kitchen", "rec room"]})` gives "Alice may only go in kitchen and rec room."
