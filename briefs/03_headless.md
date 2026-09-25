# Brief 03 — headless mode (`claude -p`) as an alternative to the Anthropic API

Project root: `C:\Users\[user]\.claude\projects\RimWorld-LLM-Integration`
Read `PLAN.md` and `For_Claude_Debugging_Handoff_VerbalCommands.md` first.

## Goal

Add a mod-settings checkbox. **Checked** = the mod shells out to the locally installed Claude Code CLI
(`claude -p`), which uses the user's existing subscription login and needs no API key. **Unchecked** =
the existing direct Anthropic Messages API path, unchanged.

The existing API path must keep working byte-for-byte. This is additive.

## Verified environment facts (do not re-derive, do not doubt)

- `where.exe claude` on this machine returns exactly `C:\Users\[user]\.local\bin\claude.exe`.
  It is a **native .exe**, not a `.cmd`/`.bat` shim. So `Process.Start` with
  `UseShellExecute = false` works directly; **never** route through `cmd.exe`.
- `claude --version` → `2.1.258 (Claude Code)`. Every flag below is present at this version.

## Verified CLI flags (quoted from https://code.claude.com/docs/en/cli-reference and /docs/en/headless)

- `--print, -p` — "Print response without interactive mode".
- `--output-format` — "Specify output format for print mode (options: `text`, `json`, `stream-json`)".
  With `json`, "the text result in the `result` field".
- `--json-schema` — "Get validated JSON output matching a JSON Schema after the agent completes its
  workflow (print mode only)... Claude Code exits with an error on an invalid schema and accepts the
  `format` keyword as an annotation without client-side validation". The docs state: "The response
  includes metadata about the request (session ID, usage, etc.) with the structured output in the
  `structured_output` field."
- `--model` — model alias (`sonnet`, `opus`, `haiku`, `fable`) or a model's full name.
- `--effort` — "Options: `low`, `medium`, `high`, `xhigh`, `max`, or `ultracode`."
- `--system-prompt-file` — "Load system prompt from a file, replacing the default prompt".
- `--permission-mode` — accepts `dontAsk`. Under `dontAsk` "Claude Code denies anything not in your
  `permissions.allow` rules or the read-only command set". Use it so a permission prompt can never
  hang the process: the docs list "waiting for an answer to a permission prompt" as a real state a
  `-p` run can sit in.
- stdin: "Non-interactive mode reads stdin, so you can pipe data in", documented example
  `cat build-error.txt | claude -p 'concisely explain the root cause of this build error'`.
  "Piped stdin is capped at 10MB."
- Exit codes: "exits with code 0 on success and a non-zero code when the run fails". "When a failure
  happens inside the run, such as missing authentication, Claude Code prints the failure as the
  result on stdout."

**Do NOT use `--bare`.** The docs are explicit: "In bare mode, Claude Code never reads OAuth
credentials or the system keychain" and "bare mode doesn't use your subscription login". Bare mode
would require `ANTHROPIC_API_KEY`, which defeats the entire point of this feature.

## Design (decided — implement this, do not redesign)

### The seam

`HeadlessClient` must return the **same `LlmResponse` object** the API path returns
(`AnthropicClient.cs:13-21`), with `toolUses` populated as synthetic `tool_use` blocks. Then
`OrderController.OnResponse` and `Executor.Resolve` need no changes to their logic at all.

Synthesise each entry as:
```json
{ "type": "tool_use", "id": "headless_0", "name": "<tool name>", "input": { ... } }
```
`Executor.Resolve` reads `name` and `input`; `OrderController` reads `id` for the explain path.

### The JSON schema passed to `--json-schema`

Do **not** use `oneOf`/`anyOf`/polymorphism. Build a flat object with one array per tool, so every
branch has a fully-specified schema:

```json
{
  "type": "object",
  "properties": {
    "message": { "type": "string", "description": "..." },
    "set_schedule":        { "type": "array", "items": <that tool's input_schema> },
    "create_allowed_area": { "type": "array", "items": <that tool's input_schema> },
    "set_work_priorities": { "type": "array", "items": <that tool's input_schema> }
  },
  "required": ["message", "set_schedule", "create_allowed_area", "set_work_priorities"],
  "additionalProperties": false
}
```

Build it by **reusing the existing `input_schema` objects** from `ToolDefinitions.BuildTools(snap)` —
deep-clone them, never mutate the originals. An empty array means "no calls of this kind". Flatten in
declaration order into `LlmResponse.toolUses`. `message` → `LlmResponse.texts`.

Ensure no description string in the schema contains a backslash.

### Process invocation

```
<claude.exe> -p "<fixed constant instruction>"
             --output-format json
             --json-schema <schema JSON>
             --model <settings.model>
             --effort <settings.effort>
             --system-prompt-file <temp file>
             --permission-mode dontAsk
```

- The `-p` argument is a **fixed literal constant** containing no user data, e.g.
  `"The colony snapshot and the player's order follow on stdin. Respond with the required JSON."`
- The player's order text **and** the snapshot JSON go in via **stdin**, not as arguments. This
  removes all argument-escaping risk from the two user-controlled variable-length strings.
- The system prompt (`ToolDefinitions.BuildSystemPrompt(settings)`) is written to a temp file under
  `Path.GetTempPath()` and passed with `--system-prompt-file`. Delete the temp file in a `finally`.
  Write it UTF-8 **without** a BOM.
- The schema is the one remaining large argument. Implement correct Windows argument quoting (wrap in
  `"`, escape embedded `"` as `\"`, double any backslashes that precede a quote). Do not hand-roll
  something looser.
- `ProcessStartInfo`: `UseShellExecute = false`, `CreateNoWindow = true`, redirect stdin/stdout/stderr,
  `StandardOutputEncoding`/`StandardErrorEncoding` = UTF-8. Set `WorkingDirectory` to
  `Path.GetTempPath()` so no project `.claude/` or `.mcp.json` from some unrelated folder is picked up.
- Read stdout and stderr on **separate threads or async** before waiting for exit, or the process will
  deadlock when a pipe buffer fills. This is the single most common bug in this kind of code.
- Timeout: honour `settings.timeoutSeconds`. On timeout, **kill the process tree** and throw
  `TimeoutException`, so a hung CLI can never hold the game.
- Everything runs on a background thread via `Task.Run` exactly as the API path does, and results come
  back through `MainThread.Post`. Never touch a RimWorld object off the main thread.

### Executable resolution

New setting `claudeExePath` (string, default `""`).
1. If set and the file exists, use it.
2. Otherwise run `where.exe claude`, take the first line that ends in `.exe`.
3. Otherwise try `C:\Users\[user]\.local\bin\claude.exe`.
4. If none resolve, fault with a clear message naming the setting.

Cache the resolved path for the session. RimWorld launched from Steam may not inherit the user's full
PATH, which is exactly why step 1 and step 3 exist.

### Parsing the response

`--output-format json` returns an envelope. Read `structured_output` for the payload. If it is absent,
fall back to extracting the outermost JSON object from `result`. If `is_error` is true, or the exit
code is non-zero, throw with the `result` text included — per the docs, an in-run failure such as
missing authentication is reported as the result on stdout, so that text is the useful diagnostic.

### The explain path

`OrderController.SendExplainRequest` builds an API-shaped message array that has no headless analogue.
Add `HeadlessClient.ExplainAsync(...)`: a second `claude -p` invocation, **no** `--json-schema`,
`--output-format json`, prompt asking for a one-sentence plain-language explanation of the fault, with
the fault text and the original order on stdin. Return its `result` string. Route to it from
`SendExplainRequest` when headless is on.

### Settings and UI

Add to `VerbalCommandsSettings`: `public bool useHeadless = false;` and
`public string claudeExePath = "";`. Both in `ExposeData` with `Scribe_Values.Look` and those defaults.

In the settings window: a checkbox, and the path field shown only when the checkbox is on. New keyed
strings in `mod\Languages\English\Keyed\VerbalCommands.xml`:
- `VerbalCommands_Settings_Headless` = "Use Claude Code CLI instead of an API key (no key needed; uses your Claude Code login)"
- `VerbalCommands_Settings_ClaudePath` = "Path to claude.exe (blank = auto-detect)"

`OrderController.Submit` currently hard-fails on an empty `apiKey` (`OrderController.cs:45-49`). That
check must apply **only** when headless is off. Its log line should say which backend is in use.

## Rules

- Touch only: `VerbalCommandsMod.cs`, `OrderController.cs`, the Languages XML, and a new
  `HeadlessClient.cs`. Do not modify `Executor.cs`, `Snapshot.cs`, or `ToolDefinitions.cs` beyond
  making a schema-reuse helper if one is genuinely needed, and say so if you do.
- Do not change any existing default value, and do not "fix" anything you were not asked to fix. If
  you spot a bug, report it in your summary; do not silently repair it.
- Match the surrounding code style exactly: tabs, explicit `Verse.Log` (the field `Log` on
  `OrderController` shadows it), no `var` where the existing files spell out the type, C# 7.3-safe.
- Build with `dotnet build src\VerbalCommands\VerbalCommands.csproj -c Release` and fix every error and
  warning you introduce. Then run `build.ps1` to deploy.
- Finish by listing every file changed with line counts, and state the build result verbatim.
