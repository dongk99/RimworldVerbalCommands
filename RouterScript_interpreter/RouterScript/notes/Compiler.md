# Compiler.cs, line by line

File: `src\RouterScript\Compiler.cs` (639 lines). Source tags: see `..\README.md`.

**What this file is:** step 3 of 3 of the check, and the translation into instructions. Comment L61-63:
"the check and the compiler in one walk. It reports every call to an unknown function, every wrong
number of values, names that are never given a value, and misplaced break / continue / return /
function, and turns the statements into instructions for the Runner." Why: B17:81-83 ("Before running,
the interpreter checks the whole file: syntax, and every call names a built-in, a host function or a
script function with the right argument count. Every problem found is reported"). Turning statements
into a flat list of instructions is what lets the Runner run the script without using the C# stack for
script calls (Runner.cs:12-14), so deep recursion can't crash the game (R17-14, D7).

## L1-3: usings, namespace.

## L5-29: `Op`: the instruction set (22 kinds)
Each instruction works on a small stack of values belonging to the running function.
- L7 `Const`: push a fixed value.
- L8 `NewList`: pop `a` items, push a new list of them. L9 `NewDict`: pop `a` key/value pairs, push a
  new dict.
- L10 `Load`: push local slot `a` if it has a value, else global slot `b`; neither → "used before it was
  given a value" (Runner.cs:178-195).
- L11 `StoreLocal`: pop into local slot `a`. L12 `StoreGlobal`: pop into global slot `b`.
- L13 `GetIndex`: pop index and target, push `target[index]`. L14 `SetIndex`: pop value, index, target;
  `target[index] = value`.
- L15 `Binary`: pop right and left, push `left <op> right` (op name in the instruction's `name`).
- L16 `Negate` (`-x`), L17 `Not`, L18 `ToBool` (replace the top value with true/false by truthiness;
  used by `and`/`or`, so they give true/false — R17-3).
- L19 `Jump` to `a`. L20 `JumpIfFalse`: pop; jump to `a` when falsy.
- L21 `Pop`: throw away the top value (after an expression statement).
- L22 `CallBuiltin`, L23 `CallHost`, L24 `CallScript` (function number `a`), each with `b` values.
- L25 `Return`: pop the return value and leave the function.
- L26 `ForBegin`: pop a list/dict and start a loop over a **copy** of its items/keys. L27 `ForNext`: push
  the next item, or end the loop and jump to `a`. L28 `ForEnd`: drop the innermost loop.
- These 22 kinds are what "a step" counts (one step each, Runner.cs:138).

## L31-42: `Instruction`
- `op`, `a`, `b` (meaning depends on op, see above), `value` (for Const), `name` (variable, operator or
  function name — L37 comment: "for messages"), `builtin` / `host` (the function to call, looked up once
  here instead of by name at run time), `line` (for errors), `loopLine` (L41: header line of the
  innermost loop around this instruction, 0 if none). `loopLine` is what lets a "ran too long" error say
  `check the loop that starts here` and point at the loop (Runner.cs:499-525; B17:98's example message).

## L44-51: `FunctionCode`
- One function's compiled code: name (null for the top level, L46), its line, how many parameters,
  how many local slots, and its instruction list.

## L53-59: `CompiledScript`
- The top-level code, every function, a name → function-number index, and how many globals.

## L64-92: the compiler's fields
- L66-71 `LoopContext`: one per loop being compiled: its header line, where `continue` jumps to, and the
  `break` jumps still waiting for the loop's end address.
- L73-77: the problem list, the host (to look up host functions), the program being built, the
  functions by name, and the globals (name → slot).
- L79-81 `hadSyntaxProblems`: comment: when a line failed to parse, a name given its value on that line
  looks unassigned; the "never given a value" check is skipped then, so the same mistake isn't reported
  twice. R17-12 ("It is skipped when the file has syntax errors, so a broken assignment line isn't
  reported twice").
- L83-86: the function being compiled (`locals == null` means the top level), and its loops.

## L94-99: `Compile(statements, host, problems)`
- Notes whether earlier passes found problems (L97), then compiles everything.

## L101-162: `CompileAll`
- L103-134 **all functions first**. Comment L103-104: every function is known before any code is
  compiled, so functions can be called above the line that defines them.
  - L112-115: a function named like a built-in → `'len' is a built-in function; pick another name for
    this function.`
  - L116-119: named like a host function → `'print' is a function the mod provides; pick another name
    for this function.` (the check knows the host's functions because `Load` is given the host).
  - L120-123: a second function with the same name → `there is already a function named 'x' (line 5).`
  - L124-133: otherwise it gets a function number and an empty code slot.
  - Test: `err_functions`.
- L136-138 **globals**: every name given a value at the top level (by `=` or as a `for` variable, not
  inside functions) is a global, each with a slot (comment L136).
- L140-146: the top-level code is compiled like a function with no locals; it ends by returning none
  (L145-146).
- L148-160: then each function's body. L155-159: a refused function (duplicate/reserved name) is still
  compiled into a throw-away slot (comment L157) so the problems inside it are reported too (D6).

## L164-191: `CompileFunction(f, code)`
- L166-168: saves the current function context (functions are compiled one after another, but a
  misplaced nested function is compiled from inside another, L403).
- L170-179: the parameters become the first local slots, in order; a repeated parameter → `the function
  'f' takes 'a' twice.`
- L181: **every name given a value anywhere in the function body becomes a local** (`CollectAssigned`).
  This is why "functions can't assign globals": inside a function, `x = ...` always makes/sets a local
  `x` (B17:52-53: "Assigning inside a function makes a local variable"; R17-2).
- L182-186: compiles the body, then an implicit `return none` at the end (so falling off the end returns
  none, B17:42), and records how many local slots it needs.
- L188-190: restores the saved context.

## L193-198: `BeginFunction`
- Sets the function being compiled, its locals (null for top level) and a fresh loop list.

## L200-244: `CollectAssigned(statements, into)`
- Comment L200: names given a value by `=` or `for` in these statements and their blocks (not in
  functions). Walks into `for`, `while`, `if`/`elif`/`else` blocks; each new name gets the next slot
  number. Only plain names (L208: `x = ...`), not items (`x[0] = ...` changes an existing list, it
  doesn't create a name).

## L246-407: statements
- L248-254 `CompileBlock`: each statement in order.
- L258-276 **assignment**: `name = value` → compile the value, then store (L264-265). `x[i] = v` →
  target, index, value, then `SetIndex` (L269-273).
- L278-284 **expression statement**: compile it and `Pop` the unused result.
- L286-310 **if/elif/else**: for each condition: the condition, `JumpIfFalse` to the next test (L293),
  the block, then (unless it is the last part) a `Jump` to the end (L295-298). The `else` block comes
  last. All end-jumps are patched to the end address (L305-308).
- L312-330 **while**: `continue` target = the condition (L317); condition; `JumpIfFalse` to exit (L320);
  body; jump back (L322); exit and all `break`s patched to after the loop (L324-328).
- L332-353 **for**: compile the items, `ForBegin` (takes the copy); `continue` target = `ForNext` (L339);
  `ForNext` pushes the next item or jumps out (L341); store it in the loop variable (L342); body; jump
  back to `ForNext` (L344); the exit and `break`s land on `ForEnd` (L346-351), which drops the loop.
- L355-374 **break / continue**: outside any loop → `'break' can only be used inside a loop.` (L358-362;
  test `err_misplaced`). Otherwise a `Jump`: `break` jumps are patched when the loop ends; `continue`
  jumps to the loop's continue target.
- L376-394 **return**: at the top level → `'return' can only be used inside a function.` (L379-383,
  B17:42). Otherwise the value (or none) and `Return`.
- L396-406 **function**: top-level functions were already handled in `CompileAll`. One inside a block →
  `functions can only be made at the top level, not inside a block.` (B17:42-43), and its body is still
  checked (comment L402).

## L409-419: `StoreName(name, line)`
- In a function → `StoreLocal` to its slot. At the top level → `StoreGlobal` to its slot. (The slot
  always exists: `CollectAssigned` ran first.)

## L421-540: expressions
- L425-430 literal → `Const`.
- L432-461 **name**:
  - L435-444: looks up both a local slot (if in a function) and a global slot.
  - L445-455: neither exists:
    - it's a function's name used without brackets → `'len' is a function; call it with its values in
      brackets, like len(...).` (L447-450);
    - otherwise, unless the file already had syntax problems (L451), → `'roms' is never given a value.`
      (L453). Why: catches typos before the script runs (R17-12: "Extra check I added: 'x' is never
      given a value catches typos"). Test: `err_never_assigned`.
  - L456-459: emits `Load` with both slots, so at run time a function reads its local if it has been
    set, else the global of the same name (R17-2: "inside a function a name is looked up locally
    first, then globally. So `x = x + 1` reads the global and creates a local").
- L463-472 **list**: each item, then `NewList` with the count.
- L474-484 **dict**: key then value for each pair, then `NewDict`.
- L486-493 **index**: target, index, `GetIndex`.
- L495-500 **call** → `CompileCall`.
- L502-508 **unary**: operand, then `Negate` or `Not`.
- L510-523 **`and`**: comment L513: short-circuit, the right side runs only when the left side is
  true. Left; `JumpIfFalse` → push `false`; else right, `ToBool`. Result is always true/false (R17-3).
- L524-536 **`or`**: comment L526: the right side runs only when the left is false. Left; if true →
  push `true`; else right, `ToBool`. B17:47 ("short-circuit").
- L537-539 other operators: left, right, `Binary` with the operator's name.

## L542-586: `CompileCall(call)`
- L544-548: the argument values first (left to right).
- L550-560: **a script function takes priority**, then (L562-571) a built-in, then (L573-582) a host
  function. (Script functions can't have a built-in's or host's name anyway, L112-119.) Each checks the
  number of values (`CheckCount`) and emits the matching call instruction.
- L584-585: none of them → `there is no function named 'ofer'.` and a placeholder `none` so compiling
  can continue (the script won't run anyway). Test: `err_calls`.

## L588-613: counts
- L588-595 `CheckCount`: a wrong number of values → `'offer' needs 1 value, got 0.` (B17:96's example).
- L597-613 `NeedsText(min, max)`: comment L597 gives every wording: "needs 1 value", "needs 2 values",
  "needs no values", "needs 1 or 2 values", "needs 1 to 3 values". Also used by the Runner for the entry
  function (Runner.cs:90).

## L615-619: `IsFunctionName(name)`
- A script function, built-in or host function (for the "call it with brackets" hint, L447).

## L621-636: emitting
- L623-626 `Here()`: the address the next instruction will get (used to patch jumps).
- L628-636 `Emit(op, line)`: adds an instruction stamped with its line and the innermost loop's header
  line (L633), and returns it so the caller can fill in `a`/`b`/`value`/`name`.
