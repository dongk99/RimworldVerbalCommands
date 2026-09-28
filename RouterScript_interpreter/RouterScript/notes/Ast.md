# Ast.cs, line by line

File: `src\RouterScript\Ast.cs` (123 lines). Source tags: see `..\README.md`.

**What this file is:** the shapes the parser builds from each line ("the parsed script"). The parser
(Parser.cs) fills these in; the compiler (Compiler.cs) checks them and turns them into instructions.
Comment L5-6: "Every node keeps its line for error messages" (B17:95, D5). All classes are `internal`:
the host never sees them.

## L1-3: usings, namespace.

## L8-11: `Node`
- `line`: the file line the node came from. Every error at check time or run time points at a line
  through this (Compiler `Emit`, Compiler.cs:628-636, copies it into each instruction).

## L13-63: expressions (things that give a value)
- L15-17 `Expr`: base class.
- L19-22 `LiteralExpr`: a written value. Comment L21: none, true/false, a number or text, *never* a list
  or dict (those are `ListExpr`/`DictExpr`, built fresh each time they run, so two runs of the same line
  never share one list).
- L24-27 `NameExpr`: a variable name.
- L29-32 `ListExpr`: `[a, b]`, one Expr per item.
- L34-38 `DictExpr`: `{k: v}`; `keys[i]` goes with `values[i]`. Keys are expressions (checked to be text
  when the line runs, Runner.cs:168-171).
- L40-44 `IndexExpr`: `target[index]`.
- L46-50 `CallExpr`: `name(args)`. Only a *name* can be called (B17:50: "No methods: everything is a
  function call"); the parser refuses `x[0](...)` (Parser.cs:503-506).
- L52-56 `UnaryExpr`: `-x` or `not x` (comment L54).
- L58-63 `BinaryExpr`: comment L60 lists every operator: `+ - * / % == != < > <= >= in "not in" and or`
  (B17:47-49). `not in` is one operator name with a space.

## L65-121: statements (things a line does)
- L67-69 `Stmt`: base class.
- L71-75 `AssignStmt`: `target = value`; comment L73: the target is a `NameExpr` or an `IndexExpr`
  (B17:38 `name = expression`; `x[i] = v`; `d["k"] = v`).
- L77-80 `ExprStmt`: an expression alone on its line, usually a call (B17:44).
- L82-87 `IfStmt`: `conditions[0]` is the `if`, then one per `elif` (comment L84); `blocks[i]` goes with
  `conditions[i]` (L85); `elseBlock` is null when there is no `else` (L86). One node holds the whole
  if/elif/else chain because `elif`/`else` lines join the `if` above them (Parser.cs:210-245).
- L89-94 `ForStmt`: `for variable in items:` + body.
- L96-100 `WhileStmt`: `while condition:` + body.
- L102-108 `BreakStmt`, `ContinueStmt`: no fields.
- L110-113 `ReturnStmt`: `value` is null for a bare `return` (comment L112), which returns none
  (B17:42).
- L115-121 `FunctionStmt`: name, parameter names, body, and `topLevel` (L120): whether it was written
  at the left edge. Functions are only allowed at the top level (B17:42-43); the compiler reports
  others (Compiler.cs:396-406), so the flag is recorded here by the parser (Parser.cs:298).
