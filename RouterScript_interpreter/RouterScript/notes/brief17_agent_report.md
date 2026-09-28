# Brief 17 agent's own report (verbatim)

Copied unedited from the agent transcript `agent-a662fdb58eaee97bc.jsonl` (session 83ddf995, 2026-09-28T02:45:17.726Z). This is what the Opus agent that built the code reported, including the choices it made where the brief was silent. These choices are the AGENT'S, not the user's.

---

Brief 17 is built: both projects compile with 0 warnings and 0 errors, all 94 script tests pass, and every answer line from the first lab run parses into a form. `src\VerbalCommands` was not built, changed or referenced. I did not run build.ps1, copy anything into Mods or launch RimWorld, and I did not touch the Config folder.

## Files
Root is `C:\Users\dongk\.claude\projects\RimWorld-LLM-Integration`.
- `src\RouterScript\` (namespace `VerbalCommands.RouterScript`, net472, no packages):
  - `RouterScript.csproj`
  - `Script.cs` (public API: `Script.Load`, `RunAsync`, `ScriptHost`, `ScriptOptions`, `ScriptResult`, `ScriptError`)
  - `Value.cs`, `Lexer.cs`, `Ast.cs`, `Parser.cs`, `Compiler.cs`, `Runner.cs`, `Operations.cs`, `Builtins.cs`, `Sentences.cs`
- `src\RouterScript.Cli\RouterScript.Cli.csproj` and `Program.cs` (`run` and `test` commands).
- `router_lab\parse_results.txt`
- `router_lab\script_tests\`: 94 `.txt`/`.expected` pairs plus `host_functions.input`.

## Build
`dotnet build -c Release` on each project separately: RouterScript 0 warnings, 0 errors; RouterScript.Cli 0 warnings, 0 errors. The output assembly is `RouterScript.dll`.

## Tests
`RouterScript.Cli.exe test router_lab\script_tests` gives **94 passed, 0 failed, 94 tests** in about 3 seconds.

The 20 feature tests cover values, arithmetic, comparisons and logic, control flow, functions, indexing, every built-in, `fill`, `parse`, comments and blocks, host functions, the entry function and staying within the limits.

The other 74 files are error tests. Every message they check:
```
'+' can't join a list and a number.
'+' can't join text and a number; use text(...) to turn the other value into text first.
'append' needs a list as its first value, got text.
'*' needs two numbers, got text and a number.
'replace' needs text as its second value, got a number.
'lower' needs text, got a number.
err_calls.txt: 'offer' needs 1 value, got 0. / there is no function named 'ofer'. / 'len' needs 1 value, got 2. / 'split' needs 2 values, got 1. / 'test_range' needs 1 to 3 values, got 0 (and got 4). / 'none_needed' needs no values, got 1. / 'two' needs 2 values, got 1. / 'test_optional' needs 1 or 2 values, got 3.
line 4: the script was stopped before it finished; it was in the loop that starts here.
line 3: the script was stopped before it finished while waiting for 'test_hang'.
'<' can only compare two numbers or two texts, got text and a number.
line 3: functions called each other too deeply (more than 200 levels); check 'forever', which may keep calling itself.   (also a limit-10 variant)
dict keys are text, got a number.  /  dict keys must be text, got a number.
the dict has no key "rooms"; use get(dict, key, default) or has(dict, key) when a key may be missing.
can't divide by zero.  /  can't divide by zero (in '%').
'else' must come right after an 'if' or 'elif' block. / 'elif' can't come after 'else'. / this 'if' already has an 'else'.
err_entry_args.txt line 4: 'route' needs 1 value, got 0.
err_entry_missing.txt: there is no function named 'route' to run.
'fill' needs a value for the slot {ROOMS}, but the slots don't have one.   (also a slot given none)
'fill' needs a dict as its second value, got a list.
the first line of code is indented; top-level lines start at the left edge.
'for' needs a list or a dict to go through, got text.
functions can only be made at the top level, not inside a block. / there is already a function named 'twice' (line 5). / 'len' is a built-in function; pick another name for this function. / 'print' is a function the mod provides; pick another name for this function. / the function 'f' takes 'a' twice.
'get' needs a dict as its first value, got a list.
'test_cancelled' did not finish.   /   'test_crash' failed.   (the host's exception text is not shown)
line 3: no map is loaded.   /   line 3: the router model did not answer.   (host plain messages, immediate and after a wait)
'in' needs a list, a dict or text on its right, got a number.  /  'in' with text on its right needs text on its left, got a number.
this line is indented more than the line above it, but the line above doesn't end in ':'. / this line's indentation doesn't line up with any block above it. / the line ending in ':' needs an indented block under it. / this line must end in ':'.
a list position must be a whole number, got 1.5. / position -1 is before the start of the list; the first position is 0. / a list position must be a number, got text. / can't take an item out of a number; only lists, dicts and text have items. / position 3 is past the end of the list (it has 3 items). / position 2 is past the end of the text (it has 2 characters).
'join_list' needs a list, got text. / 'join' needs a list as its first value, got text. / 'len' needs text, a list or a dict, got a number.
this line has a tab in it; use spaces. / this text is missing its closing '"'. / '\t' is not something text can contain; only \", \\ and \n can follow a backslash. / text goes in double quotes ("like this"), not single quotes. / the character '@' is not part of the language. / '!' is not part of the language; use 'not', or '!=' for "is not equal". / a number can't end in '.'; write it like 2 or 2.5. / '3rooms' starts with a digit; names can't start with a digit.
the list got too long (over 1,000,000 items).  /  the text got too long (over 1,000,000 characters).
err_many_kinds.txt: 5 problems of different kinds reported together, in line order.
'break' / 'continue' can only be used inside a loop.  /  'return' can only be used inside a function.
'-' needs a number, got text.
line 53: blocks are nested too deeply here (more than 50 levels).  /  this line nests too deeply (more than 60 levels of brackets or operators).
'roms' is never given a value.  /  'len' is a function; call it with its values in brackets, like len(...).
'parse' gave up: this template and text take too long to match.
"(abc" is not a valid pattern.  /  the pattern "^(a+)+$" took too long to match (over 1 second).
'replace' needs something to replace; its second value is empty text.  /  'split' needs a separator; its second value is empty text.
position 0 is past the end of the list (it has 0 items).   (remove_at, and x[0] = v)
can't set an item of a number; only lists and dicts can be changed that way.
text can't be changed one character at a time; make new text with +, replace or join.
line 3: the script ran too long (over 1,000,000 steps); check the loop that starts here.
line 8: ... (over 5,000 steps); check the loop that starts here.   (the limit was hit inside a function; the message points at the caller's loop)
line 6: the script ran too long (over 10,000 steps).   (recursion, no loop)
err_syntax.txt: 17 problems in one file: missing ')' / ']' / ':', '=' used to compare, chained comparison, a word of the language used as a name, calling something that isn't a function name, assigning to a call, a value missing at the end, the number 2 doesn't belong here, bad `for` / `function` headers, ':' on a non-header line, a block on the same line.
line 4: this line is indented with a tab; use spaces.
Template: '}' / ']' / '{' / '[' without a match, bad slot {bad name}, optional parts nested too deeply (more than 19 levels), too long (more than 200 slots, brackets and text pieces).
line 4: the script ran too long (over 0.3 seconds); check the loop that starts here.
line 3: the script ran too long (over 0.2 seconds).   (a slow host function that answers straight away)
line 4: the script ran too long (over 0.3 seconds) while waiting for 'test_hang'.
line 3: 'rooms' was used before it was given a value.
```
Every message starts with `<file> line N: `. The only exception is a missing entry function, which has no line to point at, so it reads `<file>: ...`.

## parse_results.txt on `results\2026-09-27_215618.md`
```
order 1. put alice on kitchen, rec room and alice's bedroom, and change bills on butchering table to alice only, and put human meat on storage shelves
  allowed area: PAWNS = ["Alice"], ROOMS = ["kitchen", "rec room", "Alice's bedroom"]
    reads back: Alice may only go in kitchen, rec room and Alice's bedroom.
  bills: BENCH = butcher table, PAWNS = ["Alice"]
    reads back: bills on butcher table are done only by Alice.
  ask: QUESTION = Which room's shelves?
    reads back: ASK: Which room's shelves?
order 2. Change my storage settings for shelves located close to bar inside my church
  ask: QUESTION = What should the storage near the brewery in the shrine hold only, also hold, no longer hold, or what priority should it have?
    reads back: ASK: What should the storage near the brewery in the shrine hold only, also hold, no longer hold, or what priority should it have?
order 3. Only let beer go on the storage by the bar in our shrine
  storage holds only: BENCH = brewery, ROOM = shrine, THINGS = ["beer"]
    reads back: storage near brewery in shrine holds only beer.
order 4. The shelving next to the drinks counter in the temple should only hold alcohol
  storage holds only: BENCH = brewery, ROOM = shrine, THINGS = ["alcohol"]
    reads back: storage near brewery in shrine holds only alcohol.
order 5. In the chapel, make the racks by the brewery only take beer
  ask: QUESTION = Which room is the chapel?
    reads back: ASK: Which room is the chapel?
order 6. Set what the cabinets near the brew station in the worship hall accept
  ask: QUESTION = What items should the storage near the brewery in the shrine hold?
    reads back: ASK: What items should the storage near the brewery in the shrine hold?
order 7. Fix the stash near the tap in the sanctuary so it holds drinks
  ask: QUESTION = Which bench is the tap?
    reads back: ASK: Which bench is the tap?
```
Every line parsed, including the backtick-wrapped one in order 4. "reads back" is the same template filled in again, so each line uses both `parse` and `fill`.

This run had no "does not parse" lines, so I also ran the script on a made-up scratch file. Every form parsed, and bad values were rejected as `does not parse: …` with a reason: `high-ish priority`, hour 26, priority 7, storage with no room or bench, and a line matching no form.

## Ambiguities and what I chose
1. **Running:** `RunAsync(entry, args, token)` runs the top-level lines first on every run, then the entry function. With no entry function it runs only the top level. The argument count is checked before anything runs.
2. **Variables:** inside a function a name is looked up locally first, then globally. So `x = x + 1` reads the global and creates a local. This is not the "local everywhere once assigned" rule. Functions can't assign to globals, only change global lists and dicts.
3. **and / or** give true or false, not one of the two values.
4. **Loops:** `for` goes through a copy taken when the loop starts, so appending inside the loop can't make it endless. Dict keys keep the order they were first set in.
5. **Positions:** no negative positions. Text can be read by position (`s[i]`) but not changed.
6. **Arithmetic:** `/` always gives a decimal. `%` is the C# remainder, so `-7 % 3` is `-1`.
7. **Case:** `==`, `<`, `in`, `starts_with`, `ends_with` and `contains` are case-sensitive. Only `parse` and `find_pattern` ignore case.
8. **fill:** an optional part is written only if it has at least one slot and all its slots are given. A slot given `none` counts as missing, and an optional part with no slots is never written.
9. **parse:**
   - One trailing `.` is dropped from both the template and the sentence, so `CANNOT: X.` gives `REASON = X` without the full stop.
   - Backticks are stripped only when they wrap both ends.
   - A space in the template matches any run of whitespace, and slots can't be empty.
   - A slot used twice must match (case aside).
   - The result is in template order.
10. **split_list** also accepts the comma before a final "and" ("a, b, and c"). It splits on the word "and" even inside a name ("salt and pepper").
11. **Tabs:** only reported on code lines; blank and comment lines are ignored. Tabs inside text are allowed.
12. **Extra check I added:** "'x' is never given a value" catches typos. It is skipped when the file has syntax errors, so a broken assignment line isn't reported twice.
13. **Threads:** `RunAsync` runs on the calling thread until a host Task is not yet finished, then awaits it without blocking. After that it continues wherever the await resumes. A host that wants the whole script off the main thread wraps the call in `Task.Run`.
14. **Limits:**
    - Steps: each instruction is one step (default 1,000,000). Copying large text or lists costs an extra step per 100 items.
    - Call depth: default 200.
    - Wall clock: host-set, off by default. Time spent in host functions counts, and a host call that never answers is abandoned when the time runs out or the token is cancelled.
    - Size caps: text and lists up to 1,000,000; regex 1 second; `parse` 200,000 matching steps; 60 bracket levels per line and 50 block levels; templates up to 200 parts.
    - Host functions: a host throws `ScriptError("plain words")` to show a message. Any other exception shows only "'name' failed."
    - The interpreter never uses the C# stack for script calls, so deep recursion can't crash the game.
15. **CLI tests:**
    - `# cli: --entry f --arg "..." --steps --depth --time --cancel-after` lines set the run options.
    - `<name>.input` feeds `read_lines()`.
    - The `test_*` host functions exist only in test mode.

## What I think the language is missing for the router (not added)
- Lists, dicts and calls can't span several lines, so the form table has to be built one line at a time.
- There is no raw text for regex, so every backslash in a pattern must be doubled (`"\\d+"`).
- The draft's `reply.ok`, `hits.has(...)`, `again.add_all(...)`, `vocab.rooms` all need attribute access. In this language the host must return dicts and the script uses `has(hits, "room")`, `reply["ok"]`.
- A failing host call can't be caught (no try/otherwise), so one failing call ends the whole script. The mod must fall back to its built-in router.
- Functions can't assign globals directly; state has to go through shared dicts or lists.
- Missing helpers: substring or slice, index_of, last item, sort, delete a dict key, `+=`, min/max/whole number (I used `n - n % 1`), case-insensitive equals or contains.
- In `parse` a slot can't be restricted to a number or to a vocabulary list (e.g. `{HOUR:number}`); the script has to check afterwards.
- One file only: there is no include for shared template tables.

One loose end: early on I started a shell command that hung on a `python3` probe (background task bl3c1pkwh). Because of the no-kill rule I left it running rather than stop it. It does nothing to the project.
