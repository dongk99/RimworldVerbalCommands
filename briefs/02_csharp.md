# Brief 02 — C# source for the VerbalCommands mod (RimWorld 1.6, net472)

Project root: `C:\Users\[user]\.claude\projects\RimWorld-LLM-Integration`
Read `PLAN.md` fully first. Then read `notes\A_scheduling_and_sleep_detection.md`, `notes\B_areas_rooms_beds_mod_entrypoints.md`, and `sources\anthropic_docs\messages_create.txt`, `handle_tool_calls.txt`, `strict_tool_use.txt`.
Decompiled game source: `sources\RimWorldDecompiled\Verse\*.cs` and `RimWorld\*.cs`. **Before using any engine member not listed below, Grep it in that tree and match the exact signature.** Never invent members.
Write all files into `src\VerbalCommands\`. Namespace `VerbalCommands`. No Harmony. Newtonsoft.Json is available (`using Newtonsoft.Json.Linq;`). Do not write the csproj (brief 01 owns it); if it exists you may `dotnet build` at the end and fix compile errors.

## Engine facts you may rely on (verified, path:line in `sources\RimWorldDecompiled`)
- `Mod(ModContentPack)`, `GetSettings<T>()`, `override void DoSettingsWindowContents(Rect)`, `override string SettingsCategory()`, `override void WriteSettings()` — `Verse/Mod.cs:13-49`. `ModSettings.ExposeData()` — `Verse/ModSettings.cs:7`. `Scribe_Values.Look<T>(ref T value, string label, T defaultValue = default, bool forceSave = false)` — `Verse/Scribe_Values.cs:7`.
- `GameComponent` virtuals: `GameComponentUpdate()`, `GameComponentTick()`, `GameComponentOnGUI()`, `ExposeData()`, `FinalizeInit()` — `Verse/GameComponent.cs:7-23`. The game instantiates every non-abstract subclass with `Activator.CreateInstance(type, game)` — `Verse/Game.cs:475-481`, so the class needs a `public GameComponent_VerbalCommands(Game game)` constructor. `GameComponentUpdate` is called every frame from `Game.UpdatePlay` regardless of pause (`Verse/Game.cs:678`); `GameComponentOnGUI` from `Verse/UIRoot.cs:66` while `Current.Game != null`.
- `KeyBindingDef.KeyDownEvent` (bool property, only true during a KeyDown GUI event) — `Verse/KeyBindingDef.cs:43-66`. Resolve the def with `DefDatabase<KeyBindingDef>.GetNamed("VerbalCommands_Open")`, cached lazily.
- `Current.ProgramState == ProgramState.Playing` — `Verse/Current.cs:67`.
- `Window`: `abstract void DoWindowContents(Rect inRect)` (`:133`), `virtual Vector2 InitialSize` (`:102`), fields `doCloseX`, `closeOnAccept`, `closeOnCancel`, `absorbInputAroundWindow`, `draggable`, `preventCameraMotion` (`Verse/Window.cs:16-42`), `virtual void PostClose()` (`:179`). `Find.WindowStack.Add(Window)` (`Verse/WindowStack.cs:358`), `IsOpen<T>()` (`:295`), `Windows` (`IList<Window>`, `:41`). `MainTabWindow : Window` (`RimWorld/MainTabWindow.cs:7`).
- Widgets: `Widgets.TextArea(Rect, string, bool readOnly = false)` (`Verse/Widgets.cs:1783`), `Widgets.TextField(Rect, string)` (`:1764`), `Widgets.ButtonText(Rect, string, bool drawBackground = true, bool doMouseoverSound = true, bool active = true, TextAnchor? overrideTextAnchor = null)` (`:1434`), `Widgets.Label(Rect, string)` (`:900`), `Widgets.CheckboxLabeled(Rect, string, ref bool, ...)` (`:1215`), `Widgets.TextFieldNumeric<T>(Rect, ref T, ref string buffer, float min, float max)` (`:1862`). `Listing_Standard`: `Label(string, ...)` (`:100`), `CheckboxLabeled(string, ref bool, string tooltip = null, ...)` (`:215`), `ButtonText(string, ...)` (`:248`), `TextEntry(string, int lineCount = 1)` (`:326`), `TextEntryLabeled(string label, string text, int lineCount = 1)` (`:334`); Grep `Listing_Standard.cs`/`Listing.cs` for `Begin(`/`End(`/`Gap(` before use. `Text.Font` / `GameFont` (`Verse/Text.cs:55`). `Messages.Message(string, MessageTypeDef, bool historical = true)` (`Verse/Messages.cs:47`). `Log.Message/Log.Error/Log.Warning(string)`.
- Maps and pawns: `Find.CurrentMap` (`Verse/Find.cs:114`), `map.mapPawns.FreeColonists` → `List<Pawn>` (`Verse/MapPawns.cs:144`), `pawn.ThingID` (`Verse/Thing.cs:392`), `pawn.LabelShort` (`Verse/Pawn.cs:956`), `pawn.needs.rest` is `Need_Rest`, null when the Rest need is disabled (`RimWorld/Pawn_NeedsTracker.cs:19`, `:198-236`), `pawn.ownership.Bedroom` → `Room` or null (`RimWorld/Pawn_Ownership.cs:58-67`), `pawn.timetable.times` → `List<TimeAssignmentDef>` of 24 (`RimWorld/Pawn_TimetableTracker.cs:10`), `SetAssignment(int hour, TimeAssignmentDef)` (`:56-59`), `GetAssignment(int)` (`:51`).
- Work: `pawn.workSettings.GetPriority(WorkTypeDef)`, `SetPriority(WorkTypeDef, int)` (0..4; logs an error and returns if the type is disabled — so check first), `pawn.WorkTypeIsDisabled(WorkTypeDef)` (`Verse/Pawn.cs:4476`), `Find.PlaySettings.useWorkPriorities` (`RimWorld/PlaySettings.cs:48`). Grep `RimWorld/Pawn_WorkSettings.cs` for the exact `GetPriority`/`SetPriority`/`EverWork`/`Initialized` members before use.
- Areas: `map.areaManager.AllAreas` (`Verse/AreaManager.cs:15`), `AreaManager.MaxAllowedAreas = 10` (`:13`), `CanMakeNewAllowed()`, `TryMakeNewAllowed(out Area_Allowed area)` (`:147-158`), `Area_Allowed.SetLabel(string)` (`RimWorld/Area_Allowed.cs:81-84`), `area.Label`, `area[IntVec3] = bool` (`Verse/Area.cs:60-70`), `area.TrueCount` (`:28`), `area.Delete()` (`:137`). `pawn.playerSettings.AreaRestrictionInPawnCurrentMap { get; set; }` (`RimWorld/Pawn_PlayerSettings.cs:85-111`). There is no `AreaRestriction` property in 1.6.
- Rooms: `map.regionGrid.AllRooms` (`IReadOnlyList<Room>`, `Verse/RegionGrid.cs:28`), `room.ID` (`Verse/Room.cs:11`), `room.ProperRoom` (`:536`), `room.Role` (`RoomRoleDef`, `:509`), `room.Cells` (`IEnumerable<IntVec3>`, `:189`), `room.Owners` (`IEnumerable<Pawn>`, `:406`). Resolve roles by `DefDatabase<RoomRoleDef>.GetNamed(name, false)`; `RoomRoleDefOf` has no Kitchen/RecRoom.
- Defs: `DefDatabase<TimeAssignmentDef>.AllDefs`, `DefDatabase<RoomRoleDef>.AllDefs`, `DefDatabase<WorkTypeDef>.AllDefs`, `.defName`, `.label`. `TimeAssignmentDefOf.Anything/Work/Joy/Sleep/Meditate` (`Meditate` requires Royalty: `ModsConfig.RoyaltyActive`).
- Time: `GenLocalDate.HourOfDay(Map)`.

## Anthropic Messages API facts (verified in `sources\anthropic_docs`)
- `POST https://api.anthropic.com/v1/messages`. Headers: `x-api-key: <key>`, `anthropic-version: 2023-06-01`, `content-type: application/json` (all required).
- Body: `model` (string), `max_tokens` (int), `system` (string), `messages` (array of `{role, content}`; content is a string or an array of blocks `{type:"text", text}` / `{type:"tool_use", id, name, input}` / `{type:"tool_result", tool_use_id, content, is_error}`), `tools` (array of `{name, description, input_schema, strict:true}`), `tool_choice` (`{type:"auto"}` or `{type:"none"}`), `output_config: {effort: "<low|medium|high|xhigh|max>"}`. **Never send** `temperature`, `top_p`, `top_k`, `thinking`.
- Response: `content[]` of blocks; text blocks `{type:"text", text}`; tool calls `{type:"tool_use", id, name, input}`; `stop_reason` ∈ end_turn | tool_use | max_tokens | refusal | …; on `refusal` read `stop_details.explanation` (may be null). Errors: non-2xx with a JSON body; surface status code and body text verbatim.
- `tool_result` blocks must be the first items of the user message content array; the assistant turn that contained the `tool_use` must be echoed back as `{role:"assistant", content:<the original content array>}`.
- Strict tools: `strict:true`, `additionalProperties:false` on every object, list every property in `required`. Enum casing is not guaranteed → compare enums case-insensitively when resolving.

## Files and their contracts

### `VerbalCommandsMod.cs`
```csharp
public class VerbalCommandsSettings : ModSettings {
  public string apiKey = ""; public string model = "claude-sonnet-5"; public string effort = "high";
  public int maxTokens = 2048; public int timeoutSeconds = 60; public bool confirmBeforeApply = true;
  public bool explainErrorsWithLlm = true; public string systemPromptExtra = "";
  public override void ExposeData() { /* Scribe_Values.Look for each, with the defaults above */ }
}
public class VerbalCommandsMod : Mod {
  public static VerbalCommandsSettings Settings;
  public VerbalCommandsMod(ModContentPack content) : base(content) { Settings = GetSettings<VerbalCommandsSettings>(); }
  public override string SettingsCategory() => "Verbal Commands";
  public override void DoSettingsWindowContents(Rect inRect) { /* Listing_Standard; api key via TextEntryLabeled; model/effort text; ints via TextFieldNumeric with string buffers; checkboxes; extra prompt TextEntry(…, 4) */ }
}
```
Translation keys from brief 01 may be used with `"Key".Translate()`; if a key is missing the raw key shows, which is acceptable.

### `VerbalCommandsDefs.cs`
Static class with a lazily cached `KeyBindingDef OpenKey => DefDatabase<KeyBindingDef>.GetNamed("VerbalCommands_Open")`.

### `MainThread.cs`
```csharp
public static class MainThread {
  static readonly ConcurrentQueue<Action> queue;
  public static void Post(Action a);          // from any thread
  public static void Drain();                 // main thread only; runs everything queued, each in try/catch, Log.Error on exception
}
```

### `GameComponent_VerbalCommands.cs`
`public GameComponent_VerbalCommands(Game game)`. `GameComponentUpdate()` → `MainThread.Drain()`. `GameComponentOnGUI()`: if `Current.ProgramState != ProgramState.Playing` return; if `VerbalCommandsDefs.OpenKey.KeyDownEvent`: if `Find.WindowStack.IsOpen<Dialog_VerbalCommand>()` return; if any window in `Find.WindowStack.Windows` is not a `MainTabWindow` and has `closeOnAccept == true`, return (vanilla Return closes that dialog; do not also open ours); else `Find.WindowStack.Add(new Dialog_VerbalCommand())` and `Event.current.Use()`.

### `Snapshot.cs`
```csharp
public sealed class Snapshot {
  public Map map; public JObject json;                 // json is what goes to the model
  public Dictionary<string, Pawn> pawnsById;           // ThingID -> Pawn (live objects, main thread only)
  public List<string> timeAssignmentNames, roomRoleNames, workTypeNames;  // valid enum values
  public static Snapshot Capture(Map map);             // main thread
}
```
JSON shape:
```json
{ "hour": 13, "use_work_priorities": true, "area_slots_remaining": 7,
  "time_assignments": ["Anything","Work","Joy","Sleep","Meditate"],
  "room_roles": ["Bedroom","Kitchen","RecRoom",...],
  "work_types": ["Firefighter",...],
  "colonists": [ { "id":"Human123", "name":"Kim", "needs_rest":false, "bedroom_room_id": 42,
                   "timetable": ["Sleep",...24], "work": {"Cooking":3,...}, "current_area": "Home Life" } ],
  "areas": [ {"label":"Area 1", "cells": 320} ],
  "rooms": [ {"id":42, "role":"Bedroom", "cells": 20, "owner_ids":["Human123"]} ] }
```
`area_slots_remaining = AreaManager.MaxAllowedAreas − count of Area_Allowed in AllAreas`. `rooms` only where `ProperRoom`. `work` omits disabled work types. `current_area` = `AreaRestrictionInPawnCurrentMap?.Label`.

### `ToolDefinitions.cs`
Builds the `tools` JArray from a Snapshot (enums come from the snapshot lists so they are always current) and the fixed system prompt string:
- `set_schedule`: `{targets, slots (array, minItems 24, maxItems 24, items enum time_assignments), note (string)}`; all required.
- `create_allowed_area`: `{name (string), room_roles (array of enum room_roles), include_own_bedroom (bool), targets}`; all required.
- `set_work_priorities`: `{targets, priorities (array of {work_type enum work_types, priority integer 0..4})}`; all required.
- `targets`: `{mode enum ["all","no_rest_need","ids"], ids array of string}`; both required (ids empty unless mode="ids").
Descriptions must be 3–5 sentences each (docs: "Provide extremely detailed descriptions"). Include in each description what the executor will refuse (area cap, unknown ids, manual-priorities-off).
System prompt (constant + `Settings.systemPromptExtra`): role, use only ids/defNames from the snapshot, hours 0–23 in-game, `Joy` = recreation, `needs_rest:false` pawns never sleep, expand "every N hours" into 24 slots yourself, if ambiguous or unknown pawn reply in text and call no tool, keep text to one or two sentences.

### `AnthropicClient.cs`
```csharp
public sealed class LlmResponse { public string rawJson; public JArray content; public string stopReason; public string refusalExplanation; public List<string> texts; public List<JObject> toolUses; }
public static class AnthropicClient {
  // Runs on a background thread. Never touches game state. Throws on HTTP error with "HTTP <code>: <body>".
  public static Task<LlmResponse> SendAsync(JObject requestBody, string apiKey, int timeoutSeconds, CancellationToken ct);
  public static JObject BuildInitialRequest(VerbalCommandsSettings s, string systemPrompt, JArray tools, string userText, JObject snapshotJson);
  public static JObject BuildErrorExplainRequest(VerbalCommandsSettings s, string systemPrompt, JArray tools, string userText, JObject snapshotJson, JArray assistantContent, string toolUseId, string errorText);  // tool_choice none, tool_result is_error:true FIRST in content, followed by a text block asking for a one-sentence explanation
}
```
Use a single static `HttpClient`; set `ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12` once. Serialize with `JsonConvert.SerializeObject`. Snapshot goes into the user message as a second text block after the order text.

### `Executor.cs`
```csharp
public sealed class Write { public string description; public Action apply; }           // description is what the preview shows
public sealed class Plan { public string toolName; public List<Write> writes; public List<string> notes; }   // notes = "skipped X: incapable of Cooking" etc.
public sealed class Fault : Exception { public Fault(string msg) : base(msg) {} }
public static class Executor {
  public static Plan Resolve(JObject toolUse, Snapshot snap);   // main thread; throws Fault; validates against LIVE state
  public static void Apply(Plan plan);                          // main thread; runs each write.apply
}
```
Rules per tool (from PLAN.md 4.7 and the settled item 1.2):
- Targets: `all` → `map.mapPawns.FreeColonists` now; `no_rest_need` → those with `needs.rest == null`; `ids` → each id must resolve via `snap.pawnsById` **and** still satisfy `pawn.Spawned && !pawn.Dead && pawn.Map == snap.map`, else Fault naming the id. Empty target set → Fault.
- `set_schedule`: exactly 24 slot names, each resolved case-insensitively to a `TimeAssignmentDef` present in `DefDatabase`; `Meditate` without Royalty → Fault. One Write per pawn: "Kim: schedule → J J A A … (24 letters)"; apply loops `SetAssignment`.
- `create_allowed_area`: resolve role names (case-insensitive) to `RoomRoleDef`s; collect rooms `ProperRoom && Role == role`; if a requested role matched no room → Fault listing it. Needed area count = 1 if `!include_own_bedroom` else targets.Count. If needed > slots remaining (`MaxAllowedAreas − Area_Allowed count`) → Fault "needs N areas, M slots free; nothing created". Writes: one per area "create area 'Home Life (Kim)' with 3 rooms (Kitchen 24 cells, RecRoom 30, Bedroom 12) and restrict Kim to it". Apply: `TryMakeNewAllowed` (if it returns false → throw Fault and stop), `SetLabel`, `area[c] = true` for every cell, then set `AreaRestrictionInPawnCurrentMap`. If `include_own_bedroom` and a pawn has no bedroom → note "Kim has no assigned bed; bedroom skipped", not a Fault.
- `set_work_priorities`: if `!Find.PlaySettings.useWorkPriorities` and any priority ∉ {0,3} → Fault "manual priorities are off in the Work tab". Per pawn per work type: if `WorkTypeIsDisabled` → add note "Kim skipped: incapable of Cooking" (no Write); else Write "Kim: Cooking → 1".

### `OrderController.cs`
Owns one order's lifecycle for the dialog:
```csharp
public enum OrderState { Idle, Sending, AwaitingConfirm, Applying, Done, Faulted }
public sealed class OrderController {
  public OrderState State; public List<string> Log;                 // log lines shown in the dialog
  public List<Plan> Plans; public List<string> ModelTexts;
  public void Submit(string orderText);                              // main thread: capture Snapshot, log "snapshot: N colonists, M rooms, K areas", build request, Task.Run(SendAsync), continuation posts to MainThread
  void OnResponse(LlmResponse r);                                    // main thread: log stop_reason, texts; for each tool_use → Executor.Resolve inside try; Fault → log + optional explain call; if confirm mode → AwaitingConfirm else ApplyAll()
  public void ApplyAll(); public void CancelPending();
}
```
Every transition appends a timestamped line (in-game hour is fine) to `Log`, e.g. `[13h] request sent (model claude-sonnet-5, effort high)`, `[13h] response: tool_use set_schedule`, `[13h] plan: 2 writes, 1 note`, `[13h] applied 2 writes`, `[13h] FAULT: needs 6 areas, 4 slots free; nothing created`. Exceptions from `SendAsync` are logged verbatim (`ex.Message`, plus inner exception message). Never touch game objects off the main thread; the Task continuation must only call `MainThread.Post`.

### `Dialog_VerbalCommand.cs`
`Window` subclass. `InitialSize` 700×560. `doCloseX = true; closeOnAccept = false; closeOnCancel = true; absorbInputAroundWindow = true; draggable = true; preventCameraMotion = false;`. Layout: title; order `TextArea` (3 lines); row of buttons: Send (enabled in Idle/Done/Faulted and when the box is not empty), Apply and Cancel (enabled only in AwaitingConfirm), Close; below: preview list (each `Plan`'s writes and notes) when AwaitingConfirm; bottom: read-only `TextArea` with the log joined by newlines, using a `Widgets.BeginScrollView`/`EndScrollView` pair if you verify their signatures in `Widgets.cs`. If `Settings.apiKey` is empty, Send logs the NoApiKey line instead of sending.

## Quality bar
- Every engine call must match a signature you found in the decompiled source. When unsure, Grep first.
- No reflection, no Harmony, no `LongEventHandler`.
- Catch exceptions at the boundaries (GUI callbacks, drained actions, HTTP) and log them; never let one propagate into the game loop.
- Finish by listing every file created (path, line count) and every engine member you used that is NOT in the list above, with the path:line where you verified it.
