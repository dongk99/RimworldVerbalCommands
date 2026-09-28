# Program.cs, line by line

File: `src\RouterScript.Cli\Program.cs` (492 lines). Source tags: see `..\..\RouterScript\README.md`.

**What this file is:** the offline command-line runner. It is not part of the mod and never ships: it
exists so scripts and the router lab can be run and tested outside RimWorld (B17:15-19). Why offline:
router work is done offline in `router_lab\` and the game is never launched for it (handoff standing
rules; the user does not plan to deploy for router testing, old handoff §Standing rules). Use the
`bin\Release\net472\RouterScript.Cli.exe` copy (the `obj` copy can't find RouterScript.dll).

## L1-9: usings, namespace `VerbalCommands.RouterScript.Cli`.

## L11-31: the header comment (usage)
- `run <script> [input file] [options]` and `test <folder>` (B17:16-19).
- Options (L16-26), also readable from `# cli: ...` lines at the top of a test script: `--entry`,
  `--arg` (repeatable), `--steps`, `--depth`, `--time`, `--cancel-after`, and (Brief 18) `--map <file>`
  (load a lab map and add its read functions, LabMap.cs) and `--script <file>` (test mode only: run
  another script, e.g. `router_lab\locations.txt`, instead of the test file itself).
- L27: in test mode, `--map` / `--script` paths are relative to the test folder.
- L29-31: host functions: `print(value)` and `read_lines()` (the input file's lines, or stdin; in test
  mode `<name>.input`). Test mode adds `test_*` functions that exercise the host side (answers that
  come later, failures, hangs, argument ranges). B17:16-19.

## L34-42: `RunSettings`
- The entry function, its argument values, the limits, when to cancel, the map path, the script path.

## L44-58: `Main`
- L46: console output in UTF-8 without a byte-order mark (so printed sentences with any characters come
  out right).
- L47-54: `run` or `test`.
- L55-57: anything else prints the usage and exits with 2. (The usage line doesn't list `--map` /
  `--script`; `—`.)

## L62-140: `Run(argv)`
- L64-77: the script path; the first non-option word after it is the input file; the rest are options.
- L78-84: reads the options; a bad one → its problem, exit 2.
- L86-95: reads the script (UTF-8); can't → `cannot read the script file ...`, exit 2.
- L97-106: reads the input file's lines if one was given.
- L108-113: `print(value)`: writes `text(value)` as one line.
- L114-121: `read_lines()`: the input file's lines, or everything typed on stdin (read once).
- L122-131: with `--map`, loads the map (a bad map → its problem, exit 2) and registers `rooms`,
  `things_in`, `doors_of` (LabMap.cs).
- L133-139: runs; prints the output to stdout if it worked, the error lines to stderr if not; exit 0 or
  1.

## L142-170: `RunScript(fileName, source, host, settings, output)`
- Comment L142: output gets `returned: ...` (for an entry function) or the error lines.
- L145-150: `Script.Load`; problems → they are the output.
- L151: the chosen limits.
- L152-157: a cancel token; with `--cancel-after`, it cancels itself after that time (used to test
  "stopped" messages).
- L158: runs and waits (`GetAwaiter().GetResult()`: fine in a console program, which has no UI thread
  to block).
- L159-167: errors, or `returned: <value>` when an entry function ran.

## L172-231: `ReadOptions(args, settings)`
- Each option needs a value (L177-180). `--steps`, `--depth`, `--time`, `--cancel-after` need numbers
  (read with the invariant culture). `--arg` values are always text (L189-191). Unknown option → `unknown
  option ...`.

## L233-241: `ReadLines(text)`
- Splits on newlines (Windows line ends normalised); drops one empty last line (the file's final
  newline).

## L245-285: `Test(folder)`
- L247-251: the folder must exist.
- L252-253: every `*.txt` in it, in a fixed (ordinal) order.
- L256-281: for each, the matching `.expected` must exist (else FAIL); runs it (`RunTest`); compares
  output and expected line by line, ignoring empty lines at the end; prints `PASS name` or `FAIL name`
  plus a diff.
- L282-284: `N passed, M failed, K tests`; exit 0 only when nothing failed.
- Why tests compare printed output: B17:18-19 ("compares its printed output with the matching
  `*.expected`"). B17:20: tests cover every feature and every error message.

## L287-348: `RunTest(file)`
- L293-304: `# cli:` lines anywhere in the test set its options (split like a command line, L415-448);
  a bad one → `bad # cli: line: ...` as the output.
- L306-320: with `--script`, the named script (relative to the test folder) is run instead, and its
  file name is used in messages.
- L322-323: `<name>.input` next to the test feeds `read_lines()`.
- L325-331: `print` in test mode collects output; text containing newlines becomes several lines (comment
  L328), as on the console.
- L332: `read_lines()`.
- L333: the `test_*` functions.
- L334-344: `--map` (relative to the test folder); a bad map → its problem is the output (tests
  `err_map_file`, `map_bad_letter.map`).
- L346-347: runs; returns the output lines.

## L350-412: `AddTestFunctions(host)`: test-only host functions
Comment L350: they exist only in test mode, to test the host side of the language (B17:77-93).
- L353-358 `test_later(v)`: gives `v` back after a real 10 ms wait (the script must await it).
- L359-363 `test_wait(ms)`: waits `ms` milliseconds (cancellable).
- L364-369 `test_block(ms)`: comment L364: busy on the calling thread — a slow host function that
  answers "immediately" (tests that host time counts, `err_time_host_blocking`).
- L370-373 `test_fail(msg)`: throws `ScriptError(msg)` at once → the script shows `msg` (tests the
  plain-message path, `err_host_fail`).
- L374-378 `test_fail_later(msg)`: the same after a wait (`err_host_fail_later`).
- L379-383 `test_crash()`: comment L379: "A host bug: its exception text must never reach the player."
  Throws an exception whose text looks like a C# crash; the test checks only `'test_crash' failed.`
  appears (`err_host_crash`; B17:99).
- L384-385 `test_hang()`: comment: never answers and ignores cancellation (tests that the script still
  stops, `err_cancel_waiting`, `err_time_host_waiting`).
- L386-392 `test_cancelled()`: comment: a Task the host cancelled by itself → `'test_cancelled' did not
  finish.` (`err_host_cancelled`).
- L393-395 `test_range` (1 to 3 values) / `test_optional` (1 or 2): comment: say how many values they
  got (tests value-count ranges and their messages, `err_calls`).
- L396-397 `test_convert(v)`: comment: Value → plain C# data → Value (round trip of `ToObject` /
  `Value.From`).
- L398-409 `test_from_csharp()`: comment: C# strings, numbers (int, float), lists, dictionaries, bool and
  null → Value (B17:88 "easy conversion").
- L410-411 `test_to_strings(list)`: comment: Value → C# strings, "the list helper the mod will use"
  (`Value.ToStringList`).
- These are used by `host_functions.txt` and the `err_*` host tests.

## L414-448: `SplitCommandLine(line)`
- Comment L414: splits `--arg "two words" --entry route` into `["--arg", "two words", "--entry",
  "route"]`: spaces separate, double quotes group (and are removed).

## L450-489: small helpers
- L450-456 `TrimTrailingEmpty`: drops empty lines at the end.
- L458-472 `Same`: two line lists equal.
- L474-489 `PrintDiff`: for each differing line, `line N:` with `expected:` and `actual:` (or
  `(nothing)`).
