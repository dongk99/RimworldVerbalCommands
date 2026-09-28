# Script.cs, line by line

File: `src\RouterScript\Script.cs` (248 lines). Source tags: see `..\README.md`.

**What this file is:** the public C# face of the interpreter, the only part the mod will call. B17:77-88
("Host functions (C# API)") and B17:101-102 (`RunAsync` returns a result, never throws for script
problems). Everything else in `src\RouterScript` is `internal`.

## L1-6: usings, namespace
- `System.Threading` / `System.Threading.Tasks`: `CancellationToken` and `Task` for host functions that
  answer later (B17:78-79, 84-86).

## L8-25: the header comment (usage example)
- L10-15: how a host uses it: make a `ScriptHost`, `Register` plain functions, `RegisterAsync` ones that
  answer later (the example `ask_router_model` is the Haiku call the router will make, D3/D4),
  `Script.Load("router.txt", text, host)`, check `Ok`/`errors`, then `await script.RunAsync("route", new
  Value[] { order }, token)`. `route` as the entry function's name comes from
  `briefs\router_script_draft.md:71,91` ("The mod calls route(order).") and the pseudocode's
  `function route(order_text, colony)` (`spatial_context_pseudocode.md:131`); nothing in the
  interpreter fixes the name.
- L17-20: `Load` checks the whole file first and keeps every problem (B17:81-83); `RunAsync` runs the
  top-level lines (they give the global variables their values), then the entry function (R17-1); it
  never throws for script problems (B17:101-102).
- L22-25 threads: `RunAsync` runs on the calling thread until a host function returns a Task that isn't
  finished; then it awaits without blocking and continues wherever the await resumes. A host that wants
  the whole script off its main thread calls it inside `Task.Run`. Why: B17:84-86 ("the Unity main
  thread must never wait on the script. The host decides which thread its own handlers use (later
  brief)"); R17-13.

## L26-91: `Script`
- L28 `fileName`: only used in messages ("router.txt line 3: ...").
- L30-31 `errors`: every problem the check found, already formatted with file and line. Empty = fine.
- L33 `options`: the limits (L93-103); the host may replace it before running.
- L35 `program`: the compiled code (Compiler.cs:53-59); null when the check failed.
- L37-42: private constructor; only `Load` makes scripts.
- L44-47 `Ok`: no problems.
- L49-66 `Load(fileName, source, host)`:
  - Comment L49: `host` may be null (built-ins only).
  - L52: one `ProblemList` shared by all three passes.
  - L56-58: Lexer → Parser → Compiler, in that order; each adds its problems and carries on (so all
    problems are found in one check, B17:81-83). `source ?? ""`: a null file text is treated as empty.
  - L60-64: any C# exception here would be a bug in the interpreter itself, not in the script; it is
    reported as the plain `the file could not be checked because of a problem inside the interpreter.`
    with no exception text (code comment L62). Why: B17:99 ("No exception text, no stack traces, no C#
    type names in messages"), D5.
  - L65: formats the problems (sorted by line, Lexer.cs:440-460); keeps the program only if there were
    none.
- L68-72 `HasFunction(name)`: whether the script defines a function, so a host can pick an entry point.
  `—` (convenience; not in B17).
- L74-84 `RunAsync(entryFunction, args, token)`:
  - Comment L74-75: runs the top level, then `entryFunction(args)` unless it is null or empty; the
    result's value is the entry function's return value (none when there is none).
  - L78-81: a script that failed the check doesn't run; it returns the check's errors as a failed
    result (never throws).
  - L82-83: a **new `Runner` per run** (Runner.cs:10: "runs never share variables"), with the script's
    options (or defaults if the host set them to null).
- L86-90 `Where(fileName, line)`: `router.txt line 3: `, or `router.txt: ` when the problem has no line
  (line 0). The one place the message prefix is made. Why: B17:95-98 ("always with file and line").

## L93-103: `ScriptOptions` (the limits)
- L95-96 `maxSteps = 1000000`: "Evaluated steps (roughly one per operator, value, call or jump) before
  the script is stopped." B17:91 ("Step limit (default 1,000,000 evaluated nodes)"). What a step is in
  practice: one instruction (Runner.cs:136-142) plus extra charge for big copies (Runner.cs:446-454).
- L98-99 `maxCallDepth = 200`: functions running inside each other; each level of recursion counts.
  B17:91.
- L101-102 `timeLimit = TimeSpan.Zero`: wall-clock time for the whole run, host call time included;
  Zero = no limit. B17:91-92 ("wall-clock limit (host-set; host call time counts)"). Off by default
  because the host sets it (R17-14).
- Why these limits exist at all: B17:90 "a broken router must never hang or crash the game" (D7).

## L105-132: `ScriptResult`
- L107 `ok`; L108 `value` (the entry function's return value, never C# null); L109 `errors`.
- L111-117 `Success(value)`: ok, value (null → none).
- L119-125 `Failed(errors)`.
- L127-131 `ErrorText`: all errors joined by newlines, for a host that just wants to show them.
- Why a result object instead of exceptions: B17:101-102.

## L134-142: `ScriptError`
- Comment L134-136: a host function throws this to fail with a plain message the player can read; the
  script stops with `router.txt line N: <message>`. **Any other exception from a host function is
  reported only as `'name' failed.`**, with nothing of the exception shown. Why: B17:100 ("A failing
  host function surfaces as `router.txt line N: <host's plain message>`") and B17:99 (no exception
  text), D5. The interpreter itself also uses `ScriptError` internally for every run-time script error
  (Operations.cs, Builtins.cs, Sentences.cs); the Runner turns it into a message with the line
  (Runner.cs:333-336). Tests: `err_host_fail`, `err_host_fail_later`, `err_host_crash`.

## L144-150: `HostFunction`
- Name, the allowed number of values (`minArgs`..`maxArgs`, B17:78 "a fixed argument count (or a
  range)"), and the handler. Every handler is stored in the async shape
  `Func<Value[], CancellationToken, Task<Value>>` so the runner calls all host functions the same way.

## L152-246: `ScriptHost`
- Comment L152-153: the functions the host (the mod, or the test runner) gives the script. The script
  can't reach files, network or processes except through these. Why: B17:79-80, D3 (the Arduino
  framing: a small language plus read/write functions provided by the board).
- L156: name → function, exact (case-sensitive) names.
- L158-162 `Register(name, argCount, handler)`: a function that answers immediately, fixed count.
- L164-171 `Register(name, min, max, handler)`: same with a range. L170 wraps the plain handler as
  `Task.FromResult(handler(args))`. Note: the handler runs *inside* the call, so a plain handler that
  throws throws synchronously; the runner catches that at Runner.cs:380-387.
- L173-187 `RegisterAsync`: a function that answers later. Comment L173-174: the token is cancelled
  when the run is cancelled or runs out of time; the script stops waiting at that moment either way
  (Runner.cs:389-404), even if the host ignores the token.
- L189-192 `Has`; L194-198 `Find` (internal; used by the compiler to check calls, Compiler.cs:573).
- L200-229 `Add`: comment L200: host mistakes throw because they are C# bugs, not script problems.
  Refused: an invalid name (L203-206), a keyword (L207-210), a built-in's name (L211-214), a name already
  registered (L215-218), a bad count range (L219-222). Why: so a host function can never shadow a
  built-in or a word of the language; `—` beyond that.
- L231-245 `IsValidName`: not empty, doesn't start with a digit, ASCII letters/digits/`_` only: the
  same rule the lexer uses for names (Lexer.cs:284-293), so every registered function can actually be
  called from a script.
