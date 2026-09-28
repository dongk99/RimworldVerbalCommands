# Parser.cs, line by line

File: `src\RouterScript\Parser.cs` (753 lines). Source tags: see `..\README.md`.

**What this file is:** step 2 of 3 of the check. It turns the lexer's CodeLines into statements
(Ast.cs). Comment L6-9: blocks come from indentation (a line ending in `:` owns the following lines
indented deeper, and every line of one block has the same indentation); a line with a problem is
reported and dropped, and parsing carries on (it even reads the block under a broken header), so one
check reports every problem. Why: B17:32-33 (indentation blocks), B17:81-83 (report every problem), D6.

## L1-4: usings (`System` for `Exception`), namespace.

## L10-36: fields
- L12 `MaxBlockDepth = 50`: blocks inside blocks, at most 50 deep (L148-155). L13 `MaxExpressionDepth =
  60`: brackets/operators inside each other on one line, at most 60 (L358-365). Why both: the parser
  is recursive (it calls itself for each block and each bracket), and a very deep file could otherwise
  overflow the C# stack and crash the game (B17:90, D7). The numbers are the agent's (R17-14 lists them).
  Tests: `err_nesting_blocks`, `err_nesting_line`.
- L15-17: all CodeLines, the shared problem list, and `index` (the next CodeLine to read).
- L19-23: the line being parsed: its tokens, the position in them, its line number, and the current
  expression depth.
- L25-30 `LineProblem`: a private exception used *only inside the parser* to abandon one bad line
  (thrown by the expression code, caught at L114-131). It never leaves this class.
- L32-36: private constructor.

## L38-44: `Parse(lines, problems)`
- Parses everything as one block at indentation 0, depth 0, `topLevel = true`, and returns the
  top-level statements.

## L46-167: `ParseBlock(indent, into, depth, topLevel)`: one block
- L48 `lastHadBlock`: whether the previous line owned a block (changes which indentation message is
  given, L87-94).
- L49 `lastIf`: the `if` statement an `elif`/`else` on the next line would join.
- L50-56: stops at the first line indented *less* than this block (the block is over).
- L57-80 **a line the lexer already reported (`broken`)**:
  - Comment L59-61: it may have been a header (e.g. `if x:` with a bad character), so the lines under it
    are read as its block (their own problems are still reported), and an `elif`/`else` after it is
    accepted without a second report.
  - L62: move past it. L63-76: if the next line is indented deeper, parse those lines as a throw-away
    block (or skip them if already too deep).
  - L77: `lastIf = new IfStmt()` — a dummy `if`, so an `elif`/`else` right after doesn't get reported
    as "must come right after an if".
  - Why the whole thing: report each real mistake once (D6).
- L81-102 **a line indented more than the block**:
  - L83-86: the very first line of the file → `the first line of code is indented; top-level lines
    start at the left edge.` (test `err_first_line_indented`).
  - L87-90: after a line that owned a block → `this line's indentation doesn't line up with any block
    above it.`
  - L91-94: otherwise → `this line is indented more than the line above it, but the line above doesn't
    end in ':'.`
  - L95-101: one report for the stray line and everything indented under it (comment L95).
  - Test: `err_indentation`. Why these three wordings: plain words that say what to fix (B17:95, D5).
- L104-108: take the line; prepare to parse it.
- L109-113: `BeginLine` then `ParseLine` (L190).
- L114-131 **the line has a problem**:
  - L116: report it with the line number. L117-118: no statement.
  - L119-121: if the broken line was a header (ends in `:` or starts with `if/elif/else/for/while/
    function`), still read its block (comment L119-120), into a throw-away list.
  - L122-130: a broken `if`/`elif`/`else` still counts as one, so the `elif`/`else` lines after it
    aren't reported too (comment L122-123).
- L133-136: a real statement is added to the block (`elif`/`else` aren't statements: they already
  joined `lastIf`, L210-245).
- L137-140: after anything but `elif`/`else`, `lastIf` becomes this statement if it is an `if`
  (otherwise null, so an `else` two lines later is refused).
- L142-165 **the line's block**:
  - L143-146: the line ends in `:` and the next line is deeper → parse that as its block (L158), with
    the next line's indentation as the block's indentation.
  - L148-155: already 50 deep → `blocks are nested too deeply here (more than 50 levels).` and skip the
    block.
  - L161-164: no deeper line under a good header → `the line ending in ':' needs an indented block
    under it.` (Not reported under a line that already failed, L161.)

## L169-178: header helpers
- L169-172 `IsHeaderKeyword`: `if elif else for while function`.
- L174-178 `EndsInColon`: the last token before End is `:`.

## L180-186: `BeginLine(code)`
- Points the token reader at this line and resets the expression depth.

## L188-346: `ParseLine`: one line into one statement
- Comment L188-189: returns the statement (null for `elif`/`else`, which join `lastIf`) and, for a line
  ending in `:`, the list its block goes into.
- L194-195: statements that start with a keyword:
- L199-209 `if cond:` → a new `IfStmt` with its first condition and block. B17:39.
- L210-228 `elif cond:`: must follow an `if` block (L215-218: `'elif' must come right after an 'if'
  block.`) and not come after its `else` (L219-222: `'elif' can't come after 'else'.`); adds a condition
  and block to `lastIf`. Test: `err_else_elif`.
- L229-245 `else:`: must follow an `if`/`elif` (L233-236); only one per `if` (L237-240: `this 'if' already
  has an 'else'.`).
- L246-261 `for name in items:`: L251: the loop variable must be a name (hint: `like: for room in
  rooms:`); L252-255: `expected 'in' after 'for x', but found ...`. B17:40.
- L262-271 `while cond:`. B17:40.
- L272-280 `break` / `continue`: nothing may follow them on the line. Whether they are inside a loop is
  checked by the compiler (Compiler.cs:355-362), which knows the loops.
- L281-292 `return [value]`: the value is optional (bare `return` gives none, B17:42). Whether it is
  inside a function is checked by the compiler (Compiler.cs:379-383).
- L293-318 `function name(a, b):`:
  - L298 records whether it is at the top level (functions only at the top level, B17:42; enforced in
    Compiler.cs:399-404).
  - L299: the name (hint `like: function route(order):`); L300: `(`; L301-313: parameter names separated
    by commas (hint `like: function route(order, vocab):`); L314: `)`; L315: `:` at the end.
  - Parameter names repeated are caught by the compiler (Compiler.cs:173-177).
- L322-325: a keyword followed by `=` (e.g. `if = 3`) → `'if' is a word of the language and can't be
  used as a name.`
- L326: otherwise the line is an expression...
- L327-340 ...followed by `=` → an assignment. L330-333: only a name or an item (`x[i]`, `d["key"]`) can
  be assigned: `only a name, or an item like x[i] or d["key"], can be given a value with '='.` (so
  `len(x) = 3` is refused). B17:38.
- L341-345: otherwise an expression statement (usually a call, B17:44).
- No `+=` exists: `+` then `=` can't form a statement (R17 missing-list: "`+=`").

## L348-485: expressions, lowest priority first
- Comment L348: `or`, `and`, `not`, comparisons, `+ -`, `* / %`, `-x`. This is the usual precedence
  order (so `a + b * c` is `a + (b * c)` and `not a == b` is `not (a == b)`). B17:46-49 lists the
  operators; the order is the agent's (the common one; `—`).
- L350-356 `ParseExpr`: one level deeper (`Enter`), parse an `or` expression, one level back.
- L358-365 `Enter`: more than 60 levels on one line → `this line nests too deeply (more than 60 levels
  of brackets or operators).`
- L367-376 `ParseOr`: `a or b or c`, left to right.
- L378-387 `ParseAnd`: `a and b`, left to right. Short-circuiting is done by the compiler
  (Compiler.cs:511-536); B17:47.
- L389-403 `ParseNot`: `not x` (can repeat: `not not x`), each counting one level.
- L405-420 `ParseComparison`: at most **one** comparison per step: `a < b < c` is refused with `compare
  two values at a time; join comparisons with 'and', like: a < b and b < c.` (L415-418). Why: `—` (the
  agent's choice; no reason recorded in the code or its report).
- L422-438 `ComparisonAhead`: `== != < > <= >=`, `in`, and `not in` (two tokens: `not` followed by
  `in`). B17:47-48.
- L440-447 `SkipComparison`: moves past the operator (two tokens for `not in`).
- L449-458 `ParseAdd`: `+`/`-`, left to right.
- L460-469 `ParseMul`: `*`/`/`/`%`, left to right.
- L471-485 `ParseUnary`: `-x` (can repeat). This is also how negative numbers are written: `-3` is minus
  applied to 3 (the lexer has no negative numbers).

## L487-509: `ParsePostfix`
- L489: a basic value, then any number of `[index]` after it (L492-502): `rooms[0]["name"]`.
- L503-506: `(` after something that isn't a plain name (e.g. `x[0](...)` or `(f)(...)`) → `only a
  function name can be called with '(...)', like: len(rooms).` Why: B17:50 ("No methods: everything is
  a function call"), so there are no function values to call.

## L511-632: `ParseAtom`: one basic value
- L516-520: a number → a literal. L521-525: text → a literal.
- L526-532: `true`, `false`, `none` → literals; any other keyword here → `expected a value but found
  'if'.`
- L533-562 a name:
  - L536-557: followed by `(` → a call: arguments separated by commas (L542-554), then `)` (L555: message
    `expected ')' to close the call to 'len', ...`). No comma is allowed after the last argument (only
    lists and dicts allow that, L584-588, L612-615).
  - L558-561: otherwise a variable name.
- L563-628 a symbol:
  - L564-570: `( expr )`: brackets for grouping.
  - L571-596: `[a, b]` list. L584-588 (Brief 18): a comma right before `]` is allowed, so a list written
    over several lines can end every line with a comma (code comment L584; B18:9-11; R18 item 1).
  - L597-622: `{k: v, ...}` dict: `:` between key and value (L607); a trailing comma allowed (L612-615,
    Brief 18). Keys can be any expression here; the runner checks they are text (Runner.cs:168-171).
  - L624-627: `=` where a value should be → `'=' gives a name a value; to compare two values use '=='.`
    (the classic `if a = b:` mistake).
  - L628: any other symbol → `expected a value but found ')'.` etc.
- L629-630: the End token → `a value is missing at the end of the line.` (e.g. `x = 1 +`).

## L634-650: node makers
- `MakeLiteral`, `MakeBinary`: build nodes stamped with the current line (Ast.cs `Node.line`).

## L652-683: token helpers
- L654-657 `Peek`: the current token. L659-663 `PeekAt(n)`: n tokens ahead, or End past the end.
- L665-673 `Next`: take the current token; never moves past End (so the reader can't run off the
  list).
- L675-683 `IsSymbol`, `IsKeyword`.

## L685-750: expectation helpers (the error wording)
- L685-693 `Expect(symbol, why)`: `expected ')' to close the '(', but found the end of the line.` Every
  "expected X" message says *why* X was expected (B17:95, D5).
- L695-708 `ExpectName(hint)`: a keyword → `'x' is a word of the language and can't be used as a
  name.`; anything else → `expected a name but found ...; <hint>`.
- L710-722 `ExpectEnd`: the line must be over. A `:` at the end of a line that isn't a header → `only
  lines starting with if, elif, else, for, while or function end in ':'.` (L717-720). Otherwise
  `Unexpected`.
- L724-741 `ExpectColonEnd`: a header line must end in `:` and nothing may follow it: `nothing can
  follow the ':' on the same line; put the block on the next lines, indented.` (L734; so `if x: y = 1`
  on one line is refused — the block must be on the next lines); a missing colon → `this line must end
  in ':'.` (L738).
- L743-750 `Unexpected(token)`: `=` gets the `==` hint (L745-748); anything else → `the number 2 doesn't
  belong here.` / `'x' doesn't belong here.`
- Test for most of these: `err_syntax` (17 problems in one file, R17 test list).
