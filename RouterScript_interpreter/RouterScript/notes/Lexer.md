# Lexer.cs, line by line

File: `src\RouterScript\Lexer.cs` (463 lines). Read `..\README.md` first for the source tags
(`B17:n`, `B18:n`, `R17-n`, `R18`, `code`, `D1`..., `—`).

**What this file is:** step 1 of 3 of checking a script (Lexer → Parser → Compiler, called from
`Script.Load`, Script.cs:56-58). It cuts the file into lines, measures each line's indentation, and
cuts each line into tokens (words, numbers, text, symbols). A bad line is reported and skipped, and
reading carries on, so one check reports every problem (B17:81-83, code L50-51, D6).

## L1-5: usings and namespace
- L1-3: `System.Collections.Generic` (List, HashSet, KeyValuePair), `System.Globalization`
  (culture-free number parsing, L324), `System.Text` (StringBuilder for text tokens, L332).
- L5: namespace `VerbalCommands.RouterScript`, fixed by B17:14.

## L7-15: `TokenKind`
- L9 `Name`: a word that isn't a keyword (variable or function name).
- L10 `Keyword`: one of the 16 words in L56-60.
- L11 `Number`, L12 `Text` (a `"..."` string), L13 `Symbol` (operator or bracket).
- L14 `End`: every token list ends with one (L416-419), so the parser can always look at "the next
  token" without running off the list. Why: `—` (parser mechanics).

## L17-38: `Token`
- L19 `kind`; L20 `text`: the word/symbol as written, or the *content* of a text token (escapes already
  resolved, L344-369); L21 `number`: the value of a Number token.
- L24-37 `Describe()`: how a token is named inside an error message. L28-29 End → "the end of the
  line"; L30-31 Text → `the text "..."`; L32-33 Number → "the number 2" (formatted by
  `Value.FormatNumber`, so no "2.0"); L34-35 anything else → the word in quotes, e.g. `'='`.
  Why: errors are plain words, no token-type names (B17:95-99, D5). Used by Parser.cs:254,690,704,749.

## L40-48: `CodeLine`
- Code comment L40-41: one lexed line; blank and comment-only lines never become one.
- L44 `line`: 1-based file line (for "router.txt line N:").
- L45 `indent`: number of leading spaces (blocks come from indentation, B17:32-33).
- L46 `tokens`: ends in an End token.
- L47 `broken`: the lexer already reported this line. It is still kept (with its indent) so the parser
  can still see the blocks around it, and lines under a broken `if ...:` aren't reported as "badly
  indented" as well (code comment L47; Parser.cs:57-80). Why: one check reports every real problem, and
  nothing twice (B17:81-83, D6).

## L50-63: `Lexer` class header, keyword and symbol tables
- L50-51 comment: Brief 17. Works line by line: a bad line is reported and skipped, and the next lines
  are still read. Why: B17:81-83 ("every problem found is reported, not just the first").
- L52-53 comment: Brief 18 addition. An open `[`, `{` or `(` continues onto the next lines, as one
  CodeLine numbered by its first line; indentation inside is ignored. Why: B18:9-11 (parse_results.txt
  could not write NUMBER_WORDS as one dict over several lines), R18 item 1.
- L56-60 `Keywords`: `if elif else for in while break continue function return and or not true false
  none`. These can't be used as names (Parser.cs:322-325, 698-701; Script.cs:207-210). The set is exactly
  the words B17:39-51 uses. English words instead of symbols (`and` not `&&`, `not` not `!`, `none` not
  `null`) because the language is meant to read like plain English (B17:7-8, D2).
- L62 `TwoCharSymbols`: `== != <= >=`, checked before single characters (L387-397) so `<=` isn't read as
  `<` then `=`.
- L63 `OneCharSymbols`: `= < > + - * / % ( ) [ ] { } , :`. Nothing else is a symbol: no `.` (no
  attribute access, B17:50 "No methods: everything is a function call"), no `!` (L404-407), no `&`, `|`,
  `'`. Why: B17:46-50, D2.

## L65-135: `Read(source, problems)`: the whole file into CodeLines
- L67: the result list.
- L68-71: drops a UTF-8 byte-order mark (the invisible character `U+FEFF` that Windows editors such as
  Notepad put at the start of a file). Without this, line 1 would start with a character "not part of
  the language" (L408). Why: B17:28 (UTF-8 files); `—` otherwise.
- L72: normalises Windows (`\r\n`) and old Mac (`\r`) line ends to `\n`, then splits into lines. Why:
  `—` (so line numbers are right whatever editor saved the file).
- L73-76: for each line, `lineNumber` is 1-based (what a person sees in an editor).
- L78-87: counts the leading spaces and tabs; notes whether a tab was among them.
- L88-92: a line that is empty after its indentation, or whose first character is `#`, is skipped
  entirely, *even if it was indented with tabs* (code comment L88). Why: R17-11 ("Tabs: only reported on
  code lines; blank and comment lines are ignored") — the agent's choice, so a stray tab in a comment
  doesn't stop the router.
- L93-98: a tab in the indentation → `this line is indented with a tab; use spaces.` The line is kept
  as `Broken` (L253-260) with its indent, then skipped. Why: B17:33 ("Spaces only. Tabs are an error that
  names the line"); the message itself is B17:96-97's example. Test: `err_tab_indent`.
- L100-107: cuts the rest of the line into tokens (`Tokenize`, L263). A problem there (bad character,
  unclosed text, ...) is reported with this line's number and the line is kept as Broken.
- L108-127 (Brief 18): if the line leaves brackets open (`OpenBrackets > 0`, L138):
  - L113: `JoinContinuation` (L164) tries to pull in the following lines until the brackets close.
  - L114-117: success → `i` jumps to the last line used, so those lines aren't read again. The joined
    CodeLine keeps the *first* line's number (B18 report: "errors give its first line number").
  - L118-126: failure, and the line visibly ends open (`[`, `{`, `(` or `,` as its last token, L198) →
    `the '[' on this line is never closed; add its ']' after the last item.` and the line is Broken.
    Why: R18 item 1 ("A line that ends in [, {, ( or , and never closes gets a new message").
    Test: `err_multiline_unclosed`.
  - Failure but the line does *not* end open (e.g. `x = len(a` with more after it on the line): the
    line stays alone and the parser reports the missing `)` itself (code comment L111-112). Why: keeps
    brief 17's one-line messages unchanged (R18: "It also keeps the old one-line error messages, so
    err_syntax is unchanged").
- L128-132: a good line becomes a CodeLine (line number, indent, tokens).
- L134: all CodeLines, in file order.

## L137-157: `OpenBrackets(tokens)`
- Counts `(` `[` `{` as +1 and `)` `]` `}` as -1 over the line's Symbol tokens (L143-146 skip anything
  else, so a bracket inside text `"["` doesn't count). Returns the balance: > 0 means left open.
  Doesn't check that the kinds match; the parser does that. Why: `—` (support for L109).

## L159-196: `JoinContinuation(lines, first, tokens)` (Brief 18)
- Comment L159-163: reads the following lines until the brackets close; their indentation doesn't
  matter; blank/comment lines are skipped; gives up (-1, tokens untouched) at a line that starts with a
  statement word, has an `=` in it, can't be read, or at the end of the file.
- L166: works on a copy (`joined`), so on failure the original tokens are untouched.
- L167: the open-bracket count so far.
- L168-179: for each following line, skip its leading spaces (L171-175); skip blank/comment lines
  (L176-179).
- L180-184: tokenises it; if it can't be read, or it looks like the start of a new statement
  (`StartsStatement`, L237) → give up. Why: "Without that stop, a missing `]` would swallow the rest of
  the file" (R18 item 1).
- L185: removes the End token of what's joined so far (only the last line keeps its End).
- L186-187: appends this line's tokens and updates the count.
- L188-193: brackets closed → copy `joined` into `tokens` and return this line's index.
- L195: end of file with brackets still open → -1.
- Note: a tab *inside* a continuation line's indentation is not skipped by L172 (it only skips spaces),
  so `Tokenize` reports it as "this line has a tab in it" and the join gives up. `—`.

## L198-203: `EndsOpen(tokens)`
- Looks at the last real token (the one before End, L200): true if it is `(`, `[`, `{` or `,`. Used by
  L118 to decide between the "never closed" message and the parser's own message. Why: R18 item 1.

## L205-225: `LastOpenBracket(tokens)`
- Walks the symbols with a small stack (L208-223): pushes openers, pops on any closer. Returns the
  innermost bracket still open (L224), or `(` if none (never expected here). Used only for the wording
  of L122-123 ("the '[' on this line...").

## L227-230: `Closer(open)`
- `[`→`]`, `{`→`}`, anything else →`)`. For the message's "add its ']'".

## L232-251: `StatementWords` and `StartsStatement(tokens)`
- L232-235: the keywords that begin a statement: `if elif else for while break continue function return`.
- L239-242: a line starting with one of them can't be the middle of a list/dict/call.
- L243-249: nor can a line containing a single `=` (an assignment). `==` is a different symbol
  (L62), so a comparison inside a continued list doesn't stop the join.
- Why: R18 item 1 (the "stop" rule).

## L253-260: `Broken(lineNumber, indent)`
- A CodeLine with `broken = true`, no tokens. See L47 for why it is kept.

## L262-421: `Tokenize(text, start, tokens)`: one line into tokens
- L262 comment: returns null when fine, else the plain problem text.
- L265-266: walks the characters from the end of the indentation.
- L269-273: spaces between tokens are skipped.
- L274-277: a tab anywhere in the code part → `this line has a tab in it; use spaces.` Why: B17:33
  (spaces only). Tabs *inside* `"..."` text are allowed (text is read by L330-379 before this check is
  reached for its characters) — R17-11.
- L278-281: `#` starts a comment to the end of the line (B17:31).
- L283: a new token.
- L284-293 **names and keywords**: starts with an ASCII letter or `_` (L284: `char.IsLetter(c) && c <
  128`); continues with ASCII letters, digits, `_` (L287). L292: a keyword if it's in `Keywords`, else a
  Name. Why ASCII only: `—` (not stated anywhere; it keeps names typeable and the same as the host-name
  check in Script.cs:231-245).
- L294-329 **numbers**:
  - L296-300: the digits.
  - L301-312: an optional `.` followed by at least one digit; `2.` alone → `a number can't end in '.';
    write it like 2 or 2.5.` (L306). Why: B17:34 ("integers and decimals"); message wording is the
    agent's.
  - L313-321: a digit run followed straight by a letter or `_` (e.g. `3rooms`) → `'3rooms' starts with a
    digit; names can't start with a digit.` Why: plain words instead of a confusing "number then name"
    error (`—`, agent's wording).
  - L322-328: stored as a Number; parsed with the invariant culture (L324) so `2.5` means 2.5 on a PC
    set to a language that writes 2,5. Infinity (a number with hundreds of digits) → `the number ... is
    too big.` There are no negative number tokens: `-3` is the `-` operator on `3` (Parser.cs:471-484).
- L330-379 **text** `"..."`:
  - L332-334: builds the content; `closed` tracks the closing quote.
  - L338-343: `"` ends the text.
  - L344-369: a backslash escape. Only `\"`, `\\` and `\n` exist (B17:34). L346-349: a backslash at the
    very end of the line stops the loop (then L373 reports the missing quote). L363-366: any other
    escape → `'\t' is not something text can contain; only \", \\ and \n can follow a backslash.`
    Consequence: regex patterns need doubled backslashes (`"\\d+"`) — listed as missing "raw text" in
    R17 missing-list.
  - L370-371: any other character is taken as is.
  - L373-376: no closing quote on the line → `this text is missing its closing '"'.` Text can't span
    lines (B17:34 defines no multi-line text).
  - L377-378: a Text token whose `text` is the content.
- L380-383: a single quote → `text goes in double quotes ("like this"), not single quotes.` Why: plain
  words for the most likely mistake (agent's wording; B17:34 allows only `"..."`).
- L384-413 **symbols**:
  - L387-397: two-character symbols first (`==` before `=`).
  - L398-401: then one-character symbols.
  - L402-409: anything else is an error. `!` gets its own hint: `'!' is not part of the language; use
    'not', or '!=' for "is not equal".` (L404-407); any other character: `the character '@' is not part
    of the language.` (L408). Why: the language uses `not` (B17:47), and a programmer coming from other
    languages will type `!` first.
  - L410-412: a Symbol token; move past it.
- L414: adds the token.
- L416-420: appends the End token and returns null (no problem).

## L424-461: `ProblemList`
- Comment L424: problems found while checking a file, each with its line (0 = no line).
- L427 `items`: (line, message) pairs, in the order found.
- L429-432 `Add`.
- L434-437 `Count`: `Script.Load` uses it to decide whether the script is OK (Script.cs:65).
- L439-460 `Format(fileName)`:
  - Comment L439: "router.txt line 3: ..." in line order; a stable sort, so problems on the same line
    keep the order they were found in.
  - L442-453: an insertion sort by line number (insertion sort is stable; `List.Sort` in .NET is not).
    Why: the lexer, parser and compiler each find problems in their own pass, so without sorting a file's
    problems would come out grouped by pass, not by line. Test: `err_many_kinds` ("5 problems of
    different kinds reported together, in line order", R17 test list).
  - L454-458: prefixes each message with `Script.Where(fileName, line)` → `router.txt line 3: ` or
    `router.txt: ` for line 0 (Script.cs:87-90). Why: "Errors: plain words, always with file and line"
    (B17:95, D5).
