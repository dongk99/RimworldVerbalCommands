# RouterScript: the router language interpreter

Read this before touching `src\RouterScript`, `src\RouterScript.Cli` or any router script. Written
2026-09-28 from the code as it is, the two briefs, the two building agents' own reports and the user's
own words. **No code was changed to write these notes.**

## 1. What it is, in one paragraph
A small programming language of its own (not Python), and the C# library that runs it. The mod's order
router will be a plain-text script, `router.txt`, written in this language, that the mod loads and runs
for each order; the script reads and changes the game only through functions the mod gives it ("host
functions"). Its core feature is **sentences with slots**: one template like
`put only {THINGS} in storage {PLACE}.` is used both to *write* a sentence the player reads (`fill`) and
to *read* a sentence a model wrote (`parse`). Status: built and tested offline (102 tests pass), **not
connected to the mod**, never loaded inside RimWorld, `router.txt` not written yet.

## 2. Why it exists
The short version (full user quotes, verbatim and whole, with dates, are in `notes\WHY.md`):
- **D1** The router must be a very readable, programmable file the mod runs, not logic compiled into the
  DLL.
- **D2** It is its own plain-English-looking language, not Python (the `.py` extension was dropped); the
  file is `router.txt`.
- **D3** Arduino-style: a small core language plus read/write functions the mod (the "board") provides.
- **D4** The language *is* sentences with slots: the same sentence is what the player reads, what the
  model writes, and what the router parses (the user's pseudocode: "one text, two readers").
- **D5** Every message a player can see is plain words, with file and line; no codes, no exception text.
- **D6** The whole file is checked before it runs and every problem is reported at once.
- **D7** A broken router must never hang or crash the game (step, depth, time and size limits).
- **D8** Host functions may answer later (e.g. a Haiku call); the game's main thread never waits on the
  script.
- **D9** How it is built and tested: offline in `router_lab\`; language work is Opus only; **prompt tests
  are Haiku runs only** (hand-written lines test the parser, never the prompt).
- **D10** Locations and rooms (brief 18 and handoff §3b): directions from doors, every room force-named
  from its furniture.

Where it sits in the user's Router V2 flow (`intent.md`, copy of the GitHub README): Order → **Haiku**
rewrites the player's words into sentences the interpreter accepts → **the interpreter** checks them →
a plain description (no LLM) → the player accepts or re-prompts; complex orders go to **Sonnet/Opus**,
which write sentences into the interpreter too → changes apply (revert on deny). The saving: models type
sentences; the interpreter does the game changes.

## 3. How it works (the pipeline)
```
router.txt text
  └─ Script.Load(fileName, text, host)                         Script.cs:50-66
       ├─ Lexer.Read      text → lines of tokens                Lexer.cs:65-135
       ├─ Parser.Parse    lines → statements (by indentation)   Parser.cs:38-44
       └─ Compiler.Compile  checks calls/names/placement,
                            statements → instructions           Compiler.cs:94-162
     (all three add to one ProblemList; every problem is reported, sorted by line)
  └─ script.RunAsync(entry, args, token)                        Script.cs:76-84
       └─ Runner: top-level lines, then entry(args)             Runner.cs:67-117
            one loop over instructions; function calls are frames in a list, not C# calls;
            the only await is on a host function                Runner.cs:127-337, 376-428
            limits: steps, depth, time, cancel, size caps       Runner.cs:444-525, Operations.cs:11-13
       → ScriptResult { ok, value, errors }  (never throws for script problems)
```
Values (`Value.cs`): none, true/false, number (one kind, a double), text, list, dict (text keys, insertion
order). Lists and dicts are shared, not copied.

## 4. Files and their notes
Every source file has a line-by-line note: what each line does, and why (with the source of the why).

| File | Lines | What | Note |
|---|---|---|---|
| `Script.cs` | 248 | public C# API: Load, RunAsync, ScriptHost, ScriptOptions, ScriptResult, ScriptError | `notes\Script.md` |
| `Value.cs` | 558 | the value type, C# conversion, text form, equality, ScriptDict | `notes\Value.md` |
| `Lexer.cs` | 463 | lines and tokens, tabs, multi-line brackets, ProblemList | `notes\Lexer.md` |
| `Ast.cs` | 123 | statement and expression shapes | `notes\Ast.md` |
| `Parser.cs` | 753 | blocks by indentation, statements, expressions, syntax messages | `notes\Parser.md` |
| `Compiler.cs` | 639 | the check (calls, counts, names, misplaced words) + instructions | `notes\Compiler.md` |
| `Runner.cs` | 534 | running, host calls, limits and their messages | `notes\Runner.md` |
| `Operations.cs` | 248 | operators, indexing, size caps | `notes\Operations.md` |
| `Builtins.cs` | 284 | the 22 built-in functions | `notes\Builtins.md` |
| `Sentences.cs` | 445 | templates, `fill`, `parse`, `split_list`, `join_list` | `notes\Sentences.md` |
| `RouterScript.csproj` | 13 | net472 class library, no packages; nothing here references the mod | (below) |
| `..\RouterScript.Cli\Program.cs` | 492 | offline runner: `run`, `test`, test-only host functions | `..\RouterScript.Cli\notes\Program.md` |
| `..\RouterScript.Cli\LabMap.cs` | 396 | lab-only fake colony: `rooms()`, `things_in()`, `doors_of()` | `..\RouterScript.Cli\notes\LabMap.md` |
| `..\RouterScript.Cli\RouterScript.Cli.csproj` | 17 | console app, references the library | (below) |

The two `.csproj` files: `net472` because that is the mod's framework (B17:13-15), `LangVersion latest`,
nullable off, no package dependencies (B17:13), namespaces `VerbalCommands.RouterScript(.Cli)`
(B17:14). The library's comment: "The mod references it in a later brief; nothing here references the
mod."

Also in `notes\`: `WHY.md` (decisions with the user's full words), `brief17_agent_report.md` and
`brief18_agent_report.md` (the building agents' reports, verbatim: their choices where the brief was
silent). The user's words as extracted from the session transcripts: `notes\user_words\` at the
project root.

### Source tags used in every note
| Tag | Means |
|---|---|
| `B17:n` | `briefs\17_router_interpreter.md` line n (the spec the interpreter was built to). Written by the coordinating Claude session from the user's decisions; its wording is not the user's unless `notes\WHY.md` quotes the user for it. |
| `B18:n` | `briefs\18_locations_in_language.md` line n (multi-line brackets, lab map, locations). |
| `R17-n` | the brief 17 agent's report, "Ambiguities and what I chose", item n (`notes\brief17_agent_report.md`). **The agent's choice, not the user's.** "R17 missing-list" = its "What I think the language is missing". "R17 test list" = its list of error messages tested. |
| `R18` | the brief 18 agent's report (`notes\brief18_agent_report.md`). |
| `code` | the code's own comment states the reason. |
| `D1`..`D10` | a decision in `notes\WHY.md`, with the user's words. |
| `—` | no recorded reason: the line is mechanics for the lines around it, or a choice nobody wrote a reason for. Not a guess. |

## 5. The language, as built (what a script can write)
Test files are in `router_lab\script_tests\` (each `.txt` with its `.expected` output).
- **Files:** UTF-8 `.txt`; a byte-order mark is ignored. `#` comments. Blank lines ignored.
- **Blocks:** a line ending in `:` owns the following lines indented deeper; one block = one
  indentation; **spaces only** (a tab in code is an error; in comments/blank lines/text it is allowed).
  Nothing may follow the `:` on the same line. (`comments_blocks`, `err_indentation`, `err_tab_indent`)
- **Multi-line:** an open `[`, `{` or `(` continues on the next lines; a comma after the last list/dict
  item is allowed. (`multiline_literals`, `err_multiline_unclosed`)
- **Values:** numbers (`2`, `2.5`; negative via `-`), text `"..."` with only `\"`, `\\`, `\n` escapes,
  `true`, `false`, `none`, lists `[a, b]`, dicts `{"key": v}` with **text keys only**. (`basics_values`)
- **Statements:** `name = expr`, `x[i] = v`, `d["k"] = v`; `if`/`elif`/`else`; `for x in list:` (a copy of
  the list) / `for key in dict:` (keys in first-set order); `while`; `break`; `continue`;
  `function name(a, b):` at the top level only; `return [value]`; an expression alone (usually a call).
  (`control_flow`, `functions`)
- **Operators** (low to high priority): `or`, `and`, `not`, comparisons `== != < > <= >= in not in` (one
  per expression, no chaining), `+ -`, `* / %`, `-x`. `+` joins text+text and list+list only. `/` gives a
  decimal; `%` keeps the left side's sign. `and`/`or` short-circuit and give true/false. `==` never
  converts (1 ≠ "1"). (`arithmetic`, `comparison_logic`)
- **Truthiness:** `false`, `none`, `0`, `""`, `[]`, `{}` are false.
- **Indexing:** `list[i]`, `text[i]` (read only), `dict["k"]` (missing key = error; use `get`/`has`).
  0-based; no negative positions. (`indexing`)
- **Variables:** top-level names are globals; inside a function every name assigned in it is local, and
  reading a name looks at the local first, then the global.
- **Built-ins (22):** `len text number lower upper trim replace split join starts_with ends_with contains
  append remove_at keys get has find_pattern split_list join_list fill parse` — see
  `notes\Builtins.md`. (`builtins_text`, `builtins_lists`, `find_pattern`, `fill`, `parse`)
- **Templates:** `{SLOT}` (letters, digits, `_`) and `[optional part]` (nestable). `fill` needs every
  non-optional slot; a list slot is written "a, b and c"; an optional part is written only when all its
  slots are given. `parse` ignores case, surrounding whitespace, wrapping backticks and one trailing `.`;
  slots take the shortest text that lets the rest match; results are text (split lists yourself with
  `split_list`); none when the sentence doesn't fit. See `notes\Sentences.md`.
- **Host functions:** whatever the host registers (fixed count or a range; plain or async). The CLI gives
  `print(v)`, `read_lines()`, and with `--map`: `rooms()`, `things_in(id)`, `doors_of(id)`.
- **Limits (defaults):** 1,000,000 steps (one per instruction, plus 1 per 100 items copied); call depth
  200; time limit set by the host (off by default); cancellation; text and lists up to 1,000,000; a regex
  match 1 second; `parse` 200,000 matching steps; 60 bracket/operator levels per line; 50 block levels;
  templates up to 200 parts. (`limits_within`, `err_steps*`, `err_depth*`, `err_time*`, `err_cancel_*`)
- **Errors:** always `<file> line N: <plain words>` (or `<file>: ...` when there is no line). A host
  function that throws `ScriptError("...")` shows its words; any other host failure shows only
  `'name' failed.`

## 6. What it cannot do (facts, with where)
- **No error catching** (no try/except): one failing host call or run-time error ends the whole run
  (Runner.cs:103-106). R17 missing-list.
- **No attribute access / methods:** `.` is not a symbol (Lexer.cs:63); write `reply["ok"]`, not
  `reply.ok`; only a plain name can be called (Parser.cs:503-506).
- **No typed slots** (`{HOUR:number}`): slots match any text; check afterwards (e.g. `number()`).
- **Missing helpers:** substring/slice, index_of, last item, sort, `+=`, min/max, round/whole-number
  division, dict key delete (`ScriptDict` has no delete, Value.cs:521-556), case-insensitive equals or
  contains. The full built-in list is Builtins.cs:38-180.
- **No raw regex text:** backslashes must be doubled (`"\\d+"`) (Lexer.cs:344-369). `find_pattern` gives
  the first match only (Builtins.cs:238).
- **Functions can't assign globals:** assigning inside a function makes a local (Compiler.cs:181);
  change a shared global list/dict instead.
- **One file only:** no include of shared files.
- **Surprises:** comparisons are case-sensitive except in `parse`/`find_pattern` (Value.cs:487,
  Operations.cs:111,151, Builtins.cs:122-124); `split_list` splits "salt and pepper" (Sentences.cs:412);
  top-level lines run again on every run (Runner.cs:95); `for` loops over a copy (Runner.cs:295);
  `-7 % 3` is `-1` (Operations.cs:98).
- **Not connected to the mod:** nothing in `src\VerbalCommands` references it; no real host functions
  exist; `router.txt` doesn't exist; the lab is two manual commands.

## 7. Running it
- Build (compile only; never deploy, never copy into Mods, never launch RimWorld):
  `dotnet build src\RouterScript -c Release` and `dotnet build src\RouterScript.Cli -c Release`.
- Tests: `src\RouterScript.Cli\bin\Release\net472\RouterScript.Cli.exe test router_lab\script_tests`
  (102 pass as of 2026-09-28).
- A script: `RouterScript.Cli.exe run router_lab\locations.txt --map router_lab\map.txt`, or
  `RouterScript.Cli.exe run router_lab\parse_results.txt router_lab\results\<file>.md`.

## 8. Rules for whoever works on this next
- Language/interpreter work: **Opus only** (WHY.md D9, user 2026-09-28T02:14:04Z and 04:39:22Z).
- **Only Haiku makes example-prompt outputs.** Prompt tests are Haiku runs of `router_lab\run.ps1`
  (the user runs it); lines written by Opus/Sonnet test the parser only (WHY.md D9, the user's whole
  message 2026-09-28T05:09:52Z: "test prompt is done by haiku. not opus."). `examples.txt` holds player
  speech, never router lines.
- **No new code when asked for notes/docs** (WHY.md D9, 2026-09-28T06:38:49Z).
- Before writing example orders, lab maps or tests, read `router_lab\unrealistic_scenarios.md`.
- **The project `CLAUDE.md` rules apply:** read WHY.md, this README and the interpreter first; never
  touch the rationale without the user's explicit yes; when code changes, add a `CHANGED` addendum next
  to the old rationale (don't rewrite it); make a versioned copy in `interpreter_versions\` before
  changing code or WHY.md. Line numbers in the notes are for the files as of 2026-09-28 (`v1`).
- Handoff entry point: `COMPACT_2026-09-28b_router_language.md` at the project root.
