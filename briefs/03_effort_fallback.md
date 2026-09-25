# Brief 03 — API mode: tolerate models that reject `output_config.effort`

Project root: `C:\Users\[user]\.claude\projects\RimWorld-LLM-Integration`
Scope: API mode only (`AnthropicClient.cs`, its callers in `OrderController.cs`, one Languages string, handoff doc). Do NOT touch `HeadlessClient.cs`, `Executor.cs`, `ToolDefinitions.cs`, `Snapshot.cs`, `Dialog_VerbalCommand.cs`.
Read first: `src\VerbalCommands\AnthropicClient.cs`, `src\VerbalCommands\OrderController.cs`, `src\VerbalCommands\VerbalCommandsMod.cs`, `mod\Languages\English\Keyed\VerbalCommands.xml`, `For_Claude_Debugging_Handoff_VerbalCommands.md`.

## Verified facts (fetched 2026-09-02 from official docs; quote these, invent nothing)

From https://platform.claude.com/docs/en/build-with-claude/effort :
- "Supported models: `claude-fable-5-1`, `claude-mythos-5-1`, `claude-fable-5`, `claude-mythos-5`, `claude-mythos-preview`, `claude-opus-5`, `claude-opus-4-8`, `claude-opus-4-7`, `claude-opus-4-6`, `claude-opus-4-5-20251101`, `claude-sonnet-5`, `claude-sonnet-4-6`"
- "Setting `effort` to `"high"` produces exactly the same behavior as omitting the `effort` parameter entirely."
- "Don't pass `adaptive` as an `effort` value: `adaptive` is a thinking mode, not an effort level."
- Values: `low`, `medium`, `high`, `xhigh`, `max`.

From `sources\anthropic_docs\models_overview.txt:65` (model comparison table, columns Fable 5.1 / Opus 5 / Sonnet 5 / Haiku 4.5): "Default effort high high high Not supported" — i.e. `claude-haiku-4-5-20251001` does not support effort.

From https://platform.claude.com/docs/en/api/errors :
- "400 - `invalid_request_error`: There was an issue with the format or content of your request."
- Error shape: "The API always returns errors as JSON, with a top-level `error` object that always includes a `type` and `message` value. The response also includes a `request_id` field":
  ```json
  {"type":"error","error":{"type":"invalid_request_error","message":"..."},"request_id":"req_..."}
  ```
- The exact `message` text returned when a non-supporting model receives top-level `output_config.effort` is NOT documented anywhere I read. Only the per-message (beta) variant is documented: "output_config.effort requires a model that supports per-turn effort; this model does not". Therefore detection MUST be heuristic and commented as such (see below).

## Changes

### 1. `AnthropicClient.cs`
a. Add `public sealed class AnthropicApiException : Exception` with public readonly fields `int statusCode; string errorType; string errorMessage; string requestId; string rawBody;`. In `SendAsync`, on non-2xx: try `JObject.Parse(body)`, read `error.type`, `error.message`, `request_id`; if parse fails, `errorType = null`, `errorMessage = body`. Exception `Message` = `"HTTP " + statusCode + " " + (errorType ?? "") + ": " + errorMessage`. Replace the current `throw new HttpRequestException(...)`.
b. Add to `LlmResponse`: `public bool effortDropped; public string effortDropReason;`.
c. Effort gating in `BuildBody`: emit `output_config.effort` ONLY when `ShouldSendEffort(model, effort)` is true, where:
   - effort trimmed is non-empty, AND
   - effort is not `"high"` (OrdinalIgnoreCase) — cite the docs line above in a comment, AND
   - `model` is not in a `private static readonly HashSet<string> modelsRejectingEffort` guarded by a `lock` (it is read on the main thread in `BuildBody` and written on background threads in the fallback).
   Otherwise emit no `output_config` at all.
d. Add `public static string DescribeEffort(VerbalCommandsSettings s)` for the log line: returns e.g. `"low"`, `"high (not sent: API default)"`, `"(blank: not sent)"`, `"low (not sent: model rejected it earlier this session)"`.
e. Add `public static async Task<LlmResponse> SendWithEffortFallbackAsync(JObject requestBody, string model, string apiKey, int timeoutSeconds, CancellationToken ct)`:
   - `try { return await SendAsync(...) }`
   - `catch (AnthropicApiException ex) when (IsEffortRejection(ex, requestBody))`: add `model` to `modelsRejectingEffort`; clone the body (`(JObject)requestBody.DeepClone()`), `Remove("output_config")`, `await SendAsync(clone, ...)`, set `effortDropped = true`, `effortDropReason = ex.errorMessage`, return.
   - `IsEffortRejection`: `ex.statusCode == 400 && ex.errorType == "invalid_request_error" && requestBody["output_config"] != null && ex.errorMessage != null && (ex.errorMessage.IndexOf("effort", OrdinalIgnoreCase) >= 0 || ex.errorMessage.IndexOf("output_config", OrdinalIgnoreCase) >= 0)`. Comment: "The exact message for top-level effort on an unsupported model is undocumented (checked platform.claude.com/docs/en/api/errors and /build-with-claude/effort, 2026-09-02); this substring test is the best available signal. Only one retry, only when we actually sent output_config."
   - Any other exception propagates unchanged.

### 2. `OrderController.cs`
- Both API-mode call sites (`Submit` and `SendExplainRequest`) call `SendWithEffortFallbackAsync(request, settings.model, apiKey, timeoutSeconds, token)` instead of `SendAsync`.
- `Submit` log line: replace `", effort " + settings.effort` with `", effort " + AnthropicClient.DescribeEffort(settings)` in API mode only (headless keeps `settings.effort` verbatim).
- In `OnResponse` and `OnExplainResponse`, if `r.effortDropped`: `AppendLog("effort: model rejected output_config.effort (" + r.effortDropReason + "); request resent without it. Leave effort blank or 'high' for this model to skip the retry.")`.
- Do not change headless code paths.

### 3. `mod\Languages\English\Keyed\VerbalCommands.xml`
Change `VerbalCommands_Settings_Effort` to: `Effort (low/medium/high/xhigh/max; blank or high = not sent, API default; models without effort support fall back automatically)`.

### 4. `For_Claude_Debugging_Handoff_VerbalCommands.md`
- In the Anthropic API facts section add a bullet block "Effort support" with the quotes above (supported model list, high == omitted, Haiku 4.5 not supported per models_overview.txt:65, error envelope shape, exact rejection message undocumented) and a one-paragraph description of the fallback: gating in `BuildBody`, one retry without `output_config` in `SendWithEffortFallbackAsync`, per-session `modelsRejectingEffort` memo, log line text.
- Update the settings sentence (line ~35) to say effort blank/high is not sent.
- Do NOT rewrite other sections.

### 5. Build
Run `powershell -ExecutionPolicy Bypass -File build.ps1` from the project root. It must end with both DLLs present and the robocopy mirror to `E:\STEAM\steamapps\common\RimWorld\Mods\VerbalCommands`. If the build fails, fix the compile error in the files you own and rebuild; do not touch other files. Paste the tail of the build output in your report.

## Rules
- C# style: match existing files (tabs, braces on own lines, no `var`, no C# 8+ features beyond what compiles today, `Verse.Log` fully qualified inside `OrderController` because its `Log` field shadows it).
- Quote nothing you did not read. No new settings fields. No Harmony. No changes to request body other than described.
- Finish with: list of files changed with line counts, the build tail, and any doubt you have.
