# Runner.cs, line by line

File: `src\RouterScript\Runner.cs` (534 lines). Source tags: see `..\README.md`.

**What this file is:** runs a checked script. Comment L10: one Runner per `RunAsync` call, so runs never
share variables. Comment L12-14: the script's own calls don't use the C# stack — every function call is
a `Frame` in a list, and one loop steps through instructions — so deep recursion can't overflow the
game's stack (the depth limit stops it first), and waiting on a host function is a single `await` in that
loop. Why: B17:90 ("a broken router must never hang or crash the game"), B17:84-86 (await host functions
without blocking), R17-14, D7.

## L1-8: usings, namespace
- `System.Diagnostics` (Stopwatch for the time limit), `System.Globalization` (the "1,000,000" in
  messages), `System.Threading(.Tasks)`.

## L15-57: fields
- L17-18 `CheckEvery = 256`: the clock and the host's cancel token are looked at every 256 steps, not
  every step (comment L17). Why: `—` (the agent's choice; no reason recorded).
- L20-27 `Frame`: one running function: its code, `pc` (the next instruction), its local slots, its value
  stack, and its running `for` loops.
- L29-33 `LoopState`: a running `for` loop: `items` is **a copy taken when the loop starts** (comment
  L31), and `next` is the next position. Why a copy: R17-4 ("`for` goes through a copy taken when the
  loop starts, so appending inside the loop can't make it endless").
- L35-44 `Stop`: comment L35: a script error with its line; only ever caught inside this class (L103),
  where it becomes a failed result.
- L46-57: the script, its compiled program, the options (limits), the host's cancel token, the frame
  list, the global slots, the step counter, the call depth, the line being run (for error messages),
  the stopwatch, and two token sources (one for the time limit, one linking it with the host's token).

## L59-65: constructor.

## L67-117: `RunAsync(entryFunction, args)`
- L69: starts the stopwatch.
- L70: a token source that cancels itself when the time limit passes (or never, when there is no limit).
- L71: `runSource` = cancelled when *either* the host cancels or the time runs out. This is the token
  host functions receive (L382).
- L74-79: copies the entry arguments (C# null → none).
- L80-92: checks the entry function **before anything runs** (R17-1: "The argument count is checked
  before anything runs"): missing → `there is no function named 'route' to run.` (with no line, L85;
  test `err_entry_missing`); wrong count → `'route' needs 1 value, got 0.` at the function's line (L88-91;
  test `err_entry_args`).
- L94: fresh global slots (all empty).
- L95: **runs the top-level lines first, every run**; they give the globals their values (R17-1,
  Script.cs:17-19). Consequence: a table built at the top of `router.txt` is rebuilt on every order.
- L96-101: then the entry function, if any; its return value is the result.
- L103-106: a script error → a failed result with `router.txt line N: message`.
- L107-111: any other exception is a bug in the interpreter itself → `the script stopped because of a
  problem inside the interpreter.` at the current line, never the exception text (code comment L109;
  B17:99, D5).
- L112-116: disposes the token sources.
- Why no exception ever escapes: B17:92-93 ("Hitting any of these is a normal script error, not an
  exception thrown to the host"), B17:101-102.

## L119-124: `Fail(line, message)`
- A failed result with one error, prefixed `router.txt line N: ` (Script.cs:87-90).

## L126-337: `Execute(code, args)`: the instruction loop
- Comment L126: runs code until it returns; nested script calls are frames on the same list.
- L129: how many frames existed before; when the frame list shrinks back to that, this call is done.
- L130: pushes the first frame.
- L133-146 **every step**:
  - L135-137: the top frame, its next instruction, and that instruction's line becomes `currentLine`.
  - L138-142: count one step; over `maxSteps` → the step-limit error (L494-497).
  - L143-146: every 256 steps, check the clock and the host token (L456-466).
- L148-330: one case per instruction kind (Compiler.cs:5-29):
  - L151-153 `Const`: push the value.
  - L154-160 `NewList`: take the last `a` values off the stack into a new list (no extra copy,
    `WrapList`).
  - L161-177 `NewDict`: pairs off the stack; a key that isn't text → `dict keys must be text, got a
    number.` (L168-171; B17:35 "Keys are strings"; test `err_dict_literal_key`). Keys set in order.
  - L178-195 `Load`: the local slot if it has a value, else the global slot, else `'rooms' was used
    before it was given a value.` (L191; B17:97's example message; test `err_used_before`). This is the
    run-time check for a name that *is* assigned somewhere but not yet at this point.
  - L196-201 `StoreLocal` / `StoreGlobal`.
  - L202-208 `GetIndex` → `Operations.GetItem`. L209-216 `SetIndex` → `Operations.SetItem`.
  - L217-223 `Binary` → `Operations.Binary(op, left, right, this)` (the runner is passed so big joins
    can be charged extra steps).
  - L224-233 `Negate`: only numbers → otherwise `'-' needs a number, got text.` (test
    `err_negate_text`).
  - L234-239 `Not`, `ToBool`: truthiness (Value.cs:245-266) as true/false.
  - L240-248 `Jump`, `JumpIfFalse`.
  - L249-251 `Pop`.
  - L252-254 `CallBuiltin`: pops the values and calls the built-in (Builtins.cs) directly; a C# null
    result becomes none.
  - L255-261 `CallHost`: pops the values and **awaits** `CallHost` (L376). This is the only `await` in
    the loop: the one place the script can pause without holding the thread (B17:84-86).
  - L262-273 `CallScript`: pops the values; one more level than `maxCallDepth` → `functions called each
    other too deeply (more than 200 levels); check 'forever', which may keep calling itself.` (L265-270;
    test `err_depth`, `err_depth_custom`); otherwise pushes a new frame (no C# recursion).
  - L274-288 `Return`: pops the result, removes the frame, lowers the depth (the top level doesn't count
    as a level, L278-281); if this was the frame `Execute` started with, return the value (L282-285);
    otherwise hand the value to the caller's stack (L286).
  - L289-312 `ForBegin`: a list → copy of its items (L293-296); a dict → copy of its keys as text, in
    order (L297-304); anything else → `'for' needs a list or a dict to go through, got text.` (L305-308;
    test `err_for_not_list`).
    L309: copying costs extra steps (1 per 100 items, L446-454). L310: the loop is pushed on the frame.
  - L313-326 `ForNext`: next item onto the stack, or jump out when done.
  - L327-329 `ForEnd`: drop the loop.
- L333-336: any `ScriptError` thrown by an operation, built-in or host check becomes a `Stop` with the
  current line. This is where every run-time message gets its line number.

## L339-353: `PushFrame(code, args)`
- New frame; local slots sized to the function's locals (at least the argument count, L343); the
  arguments go into the first slots (they are the parameters, Compiler.cs:171-179). Depth +1 except for
  the top level (L348-351).

## L355-372: stack helpers
- `Pop`: the top value. `PopArgs(count)`: the last `count` values, in call order (first argument first).

## L374-428: `CallHost(ins, args)`: calling a host (mod) function
- L380-387: calls the handler with the run token. If it throws *while being called* (a plain
  `Register` handler runs right here, Script.cs:170), → `HostFailure` (L430).
- L389-404 **the answer isn't ready yet**:
  - L391-394: waits for whichever comes first: the host's task, or the run being cancelled / out of
    time (a `Task.Delay` on a linked token, L393).
  - L395: cancels that wait-delay either way (so it doesn't linger).
  - L396-402: stopped or out of time first → `the script was stopped before it finished while waiting
    for 'test_hang'.` or `... ran too long (over 0.3 seconds) while waiting for 'test_hang'.` The host's
    task is abandoned; comment L398-399: nobody waits for it any more, and its failure (if any) is read
    so it isn't left unobserved (an unobserved failed Task can be reported later by .NET as an unhandled
    error). Why: a host function that never answers must not hang the router (B17:90-93; R17-14: "a host
    call that never answers is abandoned when the time runs out or the token is cancelled"). Tests:
    `err_cancel_waiting`, `err_time_host_waiting` (both use `test_hang`, which ignores cancellation).
- L406-408: comment: host time counts — a slow host function that did finish can still use up the time
  limit (B17:91-92 "host call time counts"; test `err_time_host_blocking`).
- L410-413: a handler that returned no task (C# null) → none.
- L414-418: the task failed → `HostFailure` with its inner exception.
- L419-426: the task was cancelled: because the run was stopped → the stopped/too-long message; by the
  host on its own → `'test_cancelled' did not finish.` (test `err_host_cancelled`).
- L427: the answer (C# null → none).

## L430-442: `HostFailure(ins, e)`
- L432-436: a `ScriptError` with a message → that message, as is: the host's plain words reach the
  player (B17:100).
- L437-440: an `OperationCanceledException` because the run was stopped → the stopped/too-long message.
- L441: **anything else → `'name' failed.`** and nothing of the exception. Why: B17:99 ("No exception
  text, no stack traces, no C# type names"), D5. Test: `err_host_crash` (its exception text
  "System.InvalidOperationException: internal detail at Foo.Bar()" must not appear).

## L444-525: limits and their messages
- L446-454 `Charge(items)`: comment L446: built-ins and operators that copy a lot of items pay for it,
  one step per 100 items. Why: without it, one `for` over a million-item list, or joining huge text,
  would cost only a few steps and slip past the step limit (R17-14: "Copying large text or lists costs
  an extra step per 100 items").
- L456-466 `CheckClock()`: the host cancelled → stopped; the time limit passed → too long.
- L468-486 `StoppedOrTooLong(line, waiting)`: the host cancelled → `the script was stopped before it
  finished` + (while waiting for 'x') or, when in a loop, `...; it was in the loop that starts here.`
  pointing at the loop's header line (comment L477: a stable line rather than wherever in the loop the
  stop landed; test `err_cancel_loop`). Otherwise it was the time limit → `TooLong`.
- L488-492 `TooLong`: `the script ran too long (over 0.3 seconds)` + waiting text + loop hint (test
  `err_time`).
- L494-497 `StepLimit`: `the script ran too long (over 1,000,000 steps)` + loop hint. The full message
  with the hint is B17:98's example: `router.txt line 9: the script ran too long (over 1,000,000 steps);
  check the loop that starts here.` Tests: `err_steps`, `err_steps_caller_loop`, `err_steps_no_loop`.
- L499-509 `WithLoopHint`: comment L499-500: points at the innermost running loop (in this function or
  any caller), "since that is almost always what ran away"; with no loop, the current line and a
  full stop.
- L511-525 `RunningLoopLine()`: walks the frames from the innermost out; for each, the `loopLine` of the
  instruction it is on (Compiler.cs:41, 633); the first non-zero one wins. That is how a limit hit
  inside a function called from a loop points at the caller's loop (test `err_steps_caller_loop`).
- L527-531 `FormatSeconds`: `0.3 seconds`, `1 second` (rounded to milliseconds; singular for exactly 1).
