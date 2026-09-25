# For Claude: Debugging Handoff — "Verbal Commands" RimWorld mod

Written 2026-09-02 by the Claude session that researched and built v1. Read this before re-researching anything.

## 1. Where everything is

| What | Path |
|---|---|
| **Project directory (canonical)** | `C:\Users\[user]\.claude\projects\RimWorld-LLM-Integration` |
| Shipping mod folder (source of truth for what ships) | `<project>\mod\` |
| Deployed copy the game loads | `E:\STEAM\steamapps\common\RimWorld\Mods\VerbalCommands` (mirrored from `mod\` by `build.ps1` with robocopy /MIR — anything placed only in the deployed folder is deleted on next build) |
| C# source | `<project>\src\VerbalCommands\*.cs` (10 files, ~1620 lines) + `VerbalCommands.csproj` + `nuget.config` |
| Build + deploy script | `<project>\build.ps1` (Windows PowerShell 5.1; run it, it builds Release, verifies the two DLLs, mirrors `mod\` to the Mods folder, exits 0) |
| Design plan (approved by user) | `<project>\PLAN.md` |
| Coding briefs given to the Sonnet coding agents | `<project>\briefs\01_scaffold.md`, `02_csharp.md` |
| Research report (API layers) | `<project>\RimWorld_API_Layers_for_LLM_Scheduling.md` |
| Verbatim-quote research notes | `<project>\notes\A_*.md` (scheduling/sleep), `B_*.md` (areas/rooms/beds/mod entry points), `C_*.md` (existing LLM + scheduling mods), `D_*.md` (wiki pages) |
| Decompiled RimWorld C# (Chillu1/RimWorldDecompiled, build **1.6.9438**, shallow clone) | `<project>\sources\RimWorldDecompiled\{Verse,RimWorld}\*.cs` |
| Other cloned repos | `<project>\sources\{RimTalk, Rimworld_AI_Framework, RimDialogueServer, SmarterScheduling, PawnRules}` |
| RimWorld wiki pages as text (fetched via MediaWiki API) | `<project>\sources\wiki_text\*.md` |
| Official Anthropic docs as text | `<project>\sources\anthropic_docs\*.txt` (messages_create, define_tools, handle_tool_calls, strict_tool_use, structured_outputs, models_overview, versioning, authentication2 = API overview) |
| Installed game (XML defs read from here) | `E:\STEAM\steamapps\common\RimWorld` — version **1.6.4871 rev590**, Core + Royalty + Ideology + Biotech. Game DLLs in `RimWorldWin64_Data\Managed`. |
| Steam Harmony (not used by this mod, present if ever needed) | `E:\STEAM\steamapps\workshop\content\294100\2009463077\Current\Assemblies\0Harmony.dll` |

## 2. What the mod does (v1)

Player presses **Return** on the map → a dialog opens → player types an order in plain language → mod snapshots live colony state to JSON → one HTTPS request to the Anthropic Messages API with three strict tools → model returns `tool_use` blocks → mod resolves them against **live** game state on the main thread → (confirm mode) shows the planned writes → applies them through the game's own public API. One-shot; no continuous enforcement.

Tools ("skills"):
- `set_schedule` — 24-slot timetable per targeted pawn → `Pawn_TimetableTracker.SetAssignment` (same call the Schedule tab makes).
- `create_allowed_area` — new `Area_Allowed` from room roles (Kitchen, RecRoom, …) plus optionally each pawn's own bedroom, then `Pawn_PlayerSettings.AreaRestrictionInPawnCurrentMap = area`. If needed areas exceed free slots (cap 10) → whole call refused, nothing created.
- `set_work_priorities` — `Pawn_WorkSettings.SetPriority`; incapable pawns skipped and reported as notes; if manual priorities are off only 0/3 accepted.
Targets: `all` | `no_rest_need` (pawns whose Rest need is disabled: Neversleep gene, Circadian half-cycler implant, etc.) | explicit `ids` (ThingIDs from the snapshot).

Settings (Options > Mod settings > Verbal Commands): API key (plaintext in the ModSettings XML, same as RimTalk), model (default `claude-sonnet-5`), effort (default `high`; in API mode, blank or `high` is not sent to the API at all — see "Effort support" below), max tokens, timeout, confirm-before-apply (default ON; user wants it OFF after testing), explain-faults-with-LLM (default ON; sends the fault back as `tool_result is_error:true` for a one-sentence explanation).

## 3. Architecture (file → responsibility)

| File | Role | Key engine hooks |
|---|---|---|
| `VerbalCommandsMod.cs` | `Mod` + `ModSettings`, settings UI | `Mod(ModContentPack)`, `GetSettings<T>`, `DoSettingsWindowContents`, `Scribe_Values.Look` |
| `VerbalCommandsDefs.cs` | cached `KeyBindingDef` lookup | `DefDatabase<KeyBindingDef>.GetNamed("VerbalCommands_Open")` |
| `MainThread.cs` | `ConcurrentQueue<Action>` Post/Drain | — |
| `GameComponent_VerbalCommands.cs` | key detection + queue drain | `GameComponentOnGUI` (key), `GameComponentUpdate` (drain; runs every frame even when paused, `Verse/Game.cs:678`) |
| `Snapshot.cs` | live state → JSON + `pawnsById` | `map.mapPawns.FreeColonists`, `pawn.needs.rest == null`, `pawn.ownership.Bedroom`, `map.areaManager.AllAreas`, `map.regionGrid.AllRooms`, `Room.Role` |
| `ToolDefinitions.cs` | tool JSON schemas (enums from live DefDatabase) + system prompt | — |
| `AnthropicClient.cs` | HttpClient POST, request builders, response parse | .NET only, never touches game state |
| `Executor.cs` | `Resolve(toolUse, snapshot) → Plan | Fault`, `Apply(plan)` | the four write APIs above |
| `OrderController.cs` | state machine Idle→Sending→AwaitingConfirm→Applying→Done/Faulted, log lines | `Task.Run` + `MainThread.Post` |
| `Dialog_VerbalCommand.cs` | the window | `Window`, `Widgets.TextArea/ButtonText/BeginScrollView` |

No Harmony. No reflection. No `LongEventHandler` (its `ExecuteWhenFinished` list is unlocked and may run synchronously in the caller — `Verse/LongEventHandler.cs:298-305`).

## 4. Facts verified from primary sources (do not re-derive)

Engine (decompiled 1.6.9438; path:line under `sources\RimWorldDecompiled`):
- `Pawn_TimetableTracker`: `public List<TimeAssignmentDef> times` (24), `SetAssignment(int hour, TimeAssignmentDef)` = bare list write, no validation/event (`RimWorld/Pawn_TimetableTracker.cs:56-59`). UI calls the same (`PawnColumnWorker_Timetable.cs:96`).
- Joy weighting: `ThinkNode_Priority_GetJoy.cs:26-45` — `Joy` slot → priority 7 while joy < 0.95; `Anything` → 6 only when joy < 0.35.
- Rest need removal: `Pawn_NeedsTracker.ShouldHaveNeed` (`:198-236`, `:360-363`) checks hediffSet/genes/traits/ideo `DisablesNeed`; `pawn.needs.rest` is **null** for non-sleepers (`:19`).
- Areas: `AreaManager.MaxAllowedAreas = 10` (`Verse/AreaManager.cs:13`; wiki says 8 — code wins), `TryMakeNewAllowed(out Area_Allowed)` (`:147-158`), `Area_Allowed.SetLabel` (`:81-84`), `area[IntVec3] = bool` → `Set` → `MarkDirty` (drawer, pathfinder, region notify; `Verse/Area.cs:60-70`, `:130-135`). Vanilla paint tool does exactly `SelectedArea[c] = true` (`Designator_AreaAllowedExpand.cs:28`).
- **1.6 change:** area restriction is per map; the property is `Pawn_PlayerSettings.AreaRestrictionInPawnCurrentMap` (`:85-111`). `AreaRestriction` no longer exists (SmarterScheduling's 1.4 code uses it and will not compile).
- Rooms: `map.regionGrid.AllRooms` (`Verse/RegionGrid.cs:28`), `Room.Role` lazy (`Room.cs:859-879`), `Room.Cells` (`:189`), `Room.ID` (`:11`), `ProperRoom` (`:536`). `RoomRoleDefOf` has **no Kitchen/RecRoom/DiningRoom** → `DefDatabase<RoomRoleDef>.GetNamed`.
- Beds: `Pawn_Ownership.OwnedBed` private setter; `Bedroom => OwnedBed.GetRoom()` (`RimWorld/Pawn_Ownership.cs:12-67`).
- Mod entry points: `Verse/Mod.cs:13-49`, `Verse/ModSettings.cs:7-13`, `GameComponent` instantiated via `Activator.CreateInstance(type, game)` (`Verse/Game.cs:475-481`) → needs `(Game game)` ctor. `GameComponentOnGUI` from `Verse/UIRoot.cs:66`.
- Key binding: `KeyBindingDef.KeyDownEvent` (`Verse/KeyBindingDef.cs:43-66`); vanilla `Accept` is also Return (`Data/Core/Defs/Misc/KeyBindings/KeyBindings.xml:57-61`) → the mod refuses to open while a non-MainTab window with `closeOnAccept` is on the stack.
- Assemblies load in file order (`Verse/ModAssemblyHandler.cs:31`) → Newtonsoft renamed `000_Newtonsoft.Json.dll` (RimAI Framework does the same).
- Work: `SetPriority` logs error + returns for disabled work types (`RimWorld/Pawn_WorkSettings.cs`), `Find.PlaySettings.useWorkPriorities` (`RimWorld/PlaySettings.cs:48`).

Installed XML (1.6.4871):
- TimeAssignmentDefs: Anything, Work (`allowRest=false, allowJoy=false`), Joy (label "recreation"), Sleep (`Data/Core/Defs/Misc/TimeAssignmentDefs/TimeAssignments.xml`); Meditate (Royalty).
- RoomRoleDefs incl. `Kitchen`, `RecRoom`, `Bedroom` (`Data/Core/Defs/Rooms/RoomRoles.xml`).
- No-sleep sources all use `<disablesNeeds><li>Rest</li>`: gene `Neversleep` (`Data/Biotech/Defs/GeneDefs/GeneDefs_Spectrum.xml:921-929`), hediff `CircadianHalfCycler` (`Data/Royalty/Defs/HediffDefs/Hediffs_BodyParts_Bionic_Empire.xml:1270-1290`). No vanilla trait disables Rest.
- 20 Core WorkTypeDefs: Firefighter Patient Doctor PatientBedRest BasicWorker Warden Handling Cooking Hunting Construction Growing Mining PlantCutting Smithing Tailoring Art Crafting Hauling Cleaning Research.

Anthropic API (`sources\anthropic_docs`):
- `POST https://api.anthropic.com/v1/messages`; headers `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`.
- Body used: `model`, `max_tokens`, `system`, `messages`, `tools[{name,description,input_schema,strict:true}]`, `tool_choice {type:auto|none}`, `output_config {effort}`. **Never** `temperature`/`top_p`/`top_k` (rejected by current models).
- **Fable 5.1 / Mythos 5.1 return 400 for `tool_choice` any/tool** → mod uses `auto` (works on all models).
- Strict schemas: `additionalProperties:false`, everything in `required`; **`minimum`/`maximum`/`minLength`/`maxLength` are unsupported constraints** (structured_outputs.txt:282) — removed from the schemas; executor enforces 24 slots and 0..4 instead. Enum casing not guaranteed → executor resolves case-insensitively.
- `tool_result` blocks must be first in the user content array; assistant `content[]` echoed unmodified.
- Model IDs/pricing: `claude-sonnet-5` ($2/$10 per MTok), `claude-haiku-4-5-20251001`, `claude-opus-5`, `claude-fable-5-1` (models_overview.txt).

**Effort support** (fetched 2026-09-02 from platform.claude.com/docs/en/build-with-claude/effort and /api/errors):
- Supported models: "`claude-fable-5-1`, `claude-mythos-5-1`, `claude-fable-5`, `claude-mythos-5`, `claude-mythos-preview`, `claude-opus-5`, `claude-opus-4-8`, `claude-opus-4-7`, `claude-opus-4-6`, `claude-opus-4-5-20251101`, `claude-sonnet-5`, `claude-sonnet-4-6`". Values: `low`, `medium`, `high`, `xhigh`, `max`. `adaptive` is a thinking mode, not an effort value — never pass it as `effort`.
- "Setting `effort` to `"high"` produces exactly the same behavior as omitting the `effort` parameter entirely" — so the client never sends `output_config` for a blank or `high` value.
- `claude-haiku-4-5-20251001` does not support effort at all (`sources\anthropic_docs\models_overview.txt:65`, comparison table: "Default effort high high high Not supported" for Fable 5.1 / Opus 5 / Sonnet 5 / Haiku 4.5).
- Error envelope (`/api/errors`): "The API always returns errors as JSON, with a top-level `error` object that always includes a `type` and `message` value. The response also includes a `request_id` field": `{"type":"error","error":{"type":"invalid_request_error","message":"..."},"request_id":"req_..."}`.
- The exact `message` text for a top-level `output_config.effort` rejection on an unsupported model is undocumented; only the per-message (beta) variant is documented ("output_config.effort requires a model that supports per-turn effort; this model does not").

Fallback implementation (`AnthropicClient.cs`, `OrderController.cs`, API mode only — headless is untouched): `BuildBody` gates emission of `output_config.effort` behind `ShouldSendEffort` (non-blank, not `"high"` case-insensitively, and the model hasn't already rejected it this session). `OrderController` calls `AnthropicClient.SendWithEffortFallbackAsync` instead of `SendAsync`; on an `AnthropicApiException` that is HTTP 400 `invalid_request_error` with an `output_config` present in the request and an error message containing "effort" or "output_config" (heuristic substring match, since the exact message is undocumented), it adds the model to a per-session `HashSet<string> modelsRejectingEffort` (lock-guarded, read on the main thread in `BuildBody`, written on background threads), clones the request body, removes `output_config`, and retries once. The retried response carries `effortDropped = true` and `effortDropReason` (the original error message) back to `OrderController`, which logs: "effort: model rejected output_config.effort (‹reason›); request resent without it. Leave effort blank or 'high' for this model to skip the retry." The settings-panel request-sent log line uses `AnthropicClient.DescribeEffort(settings)` in API mode (e.g. `"low"`, `"high (not sent: API default)"`, `"(blank: not sent)"`, `"low (not sent: model rejected it earlier this session)"`); headless mode still logs `settings.effort` verbatim since the CLI path is untouched.

## 5. Environment gotchas hit in this session

- `curl` to rimworldwiki.com returns a Cloudflare challenge; `WebFetch` got 403. **Use the MediaWiki API via python urllib** (`action=parse&prop=text|wikitext`) — that works. `curl` in the sandbox failed entirely (exit 43/35) for subagents; python urllib works.
- Machine's default NuGet config has only the VS offline feed (Newtonsoft 13.0.1). Project-local `src\VerbalCommands\nuget.config` adds nuget.org; do not change the global config.
- robocopy returns 1 on "files copied"; the script treats 0–7 as success and ends with `exit 0`.
- Bash heredocs with long multi-line markdown failed in this harness ("unexpected EOF"); use the Write tool for long files.
- Reading `messages_api.txt` printed private-use Unicode glyphs that crash cp1252 stdout; strip U+E000–U+F8FF or set `PYTHONIOENCODING=utf-8`.

## 6. Test status

**Updated 2026-09-02 (user report).** Tested in-game and working: mod loads, Return opens the dialog, mod settings (API key, model, effort), API-mode round trip to Anthropic, snapshot capture (35 colonists / 92 rooms / 8 areas on the user's save), the effort fallback on `claude-haiku-4-5`, and `set_work_priorities` driven by skill. The user says to assume everything that path requires (settings, API client, apply pipeline) is functioning. **NOT tested**: `set_schedule`, `create_allowed_area` (the v1 zoning idea: kitchens + rec rooms + own bedroom), the group feature (`define_group`/`clear_group`, hotkeys, consent dialogs, restore button), the confirm-before-apply flip. Headless mode has no direct evidence either way (the tested request ran in API mode). Original session-1 note follows.

Build is clean (0 warnings). The user runs the test script in `PLAN.md` section 6 and reports. Expected first-run risks, in order: (1) Return key double-fires or never fires → rebind in Options > Controls or inspect the `closeOnAccept` gate in `GameComponent_VerbalCommands.cs:44-50`; (2) HTTP 400 from a schema detail → the log panel prints the response body verbatim; (3) Mono TLS failure to api.anthropic.com → fallback plan is `UnityWebRequest` (RimTalk's path, `sources\RimTalk\Source\Client\OpenAI\OpenAIClient.cs:294-308`); (4) Newtonsoft version clash with another mod.

Where errors surface: the dialog's log panel (every step logs a line) and RimWorld's dev-mode log with prefix `[VerbalCommands]`.

## 7. Rules the user set for this project (binding for any agent continuing it)

- Do **not** use any of the user's custom skills (gated-code-workflow, research-pipeline, etc.) on this project.
- Plan first, get approval, then code. **Sonnet** subagents write code; Fable/Opus plan and verify. Verify every engine member against the decompiled source before building; never claim a test passed until the user reports it.
- Do not use the memory feature unless explicitly asked in the current turn.
- Every factual claim must be backed by a source fetched and read in full (files above); no snippets.
- Project files stay in the project dir; only `Mods\VerbalCommands` on E: is written outside it (user-approved).
- Decisions already made (do not re-ask): Anthropic API; Return key opens the box; one-shot apply; preview+confirm during testing then off; tools = schedule, area, work priorities; area-cap overflow → refuse whole op; incapable work type → apply to others and report; default `claude-sonnet-5` effort `high`; LLM error explanation on by default.

## 8. Likely next steps

1. User test pass → fix whatever surfaces → `build.ps1`.
2. Flip `confirmBeforeApply` default to `false` after tests pass (decision 3).
3. Optional: a Harmony-free "workflow" panel already exists (the log); the user mentioned adding richer in-game workflow display and coded exception handling later.
4. Optional: persist last N orders via `GameComponent.ExposeData` (not in v1 by decision).

## 9. Groups (brief 04)

Rule-based pawn groups: `define_group` / `clear_group` store a weapon/range **RULE** (`GroupRule`) in one of 9 slots, not a member list. Pressing the slot's hotkey evaluates the rule against **live** equipment and selects matches; Alt+key also drafts them. No LLM call at keypress.

New files: `src\VerbalCommands\GroupRule.cs` (rule model, `Matches`/`Summary`/`WeaponRange`), `src\VerbalCommands\GroupHotkeyLayout.cs` (consent flow + rebinding).

Engine facts used (path:line, `sources\RimWorldDecompiled`):
- `Pawn_EquipmentTracker.Primary`: first equipment with `equipmentType == EquipmentType.Primary`, null if unarmed (`Verse\Pawn_EquipmentTracker.cs:16-27`).
- `ThingDef.IsWeapon` (`Verse\ThingDef.cs:954`), `IsRangedWeapon` (`:1115-1131`), `IsMeleeWeapon` (`:1137-1146`), `ThingDef.Verbs` (`:659-668`).
- `VerbProperties.range` (`Verse\VerbProperties.cs:29`), `VerbProperties.IsMeleeAttack` (`:282`).
- `Pawn_DraftController.Drafted` setter (`RimWorld\Pawn_DraftController.cs:19-31`), `Pawn.Downed` (`Verse\Pawn.cs:231`), `Pawn.drafter` (`:128`).
- `Find.Selector` (`Verse\Find.cs:62`), `Selector.ClearSelection()`/`Select(obj, playSound, forceDesignatorDeselect)` (`RimWorld\Selector.cs:274,294`).
- `KeyBindingDef.KeyDownEvent` (`Verse\KeyBindingDef.cs:43-66`), `KeyPrefsData.keyPrefs` public dict (`Verse\KeyPrefsData.cs:9`), `KeyBindingData.keyBindingA/keyBindingB` public fields + ctor (`Verse\KeyBindingData.cs:7-16`), `KeyPrefs.Save()`/`Init()` (`Verse\KeyPrefs.cs`).
- `MainButtonDef.defaultHotKey` (`RimWorld\MainButtonDef.cs:17`), generated `KeyBindingDef` named `"MainTab_" + defName` (`Verse\KeyBindingDefGenerator.cs:29-42`); defNames Work/Schedule/Assign/Animals/Wildlife/Research/Quests/World/History = F1-F9 (`Data\Core\Defs\Misc\MainButtonDefs\MainButtons.xml`).
- `Dialog_MessageBox` ctor (`Verse\Dialog_MessageBox.cs:62`).
- `Scribe_Collections.Look<K,V>` dictionary overload with working lists (`Verse\Scribe_Collections.cs:433`) for `GameComponent_VerbalCommands.groups`; `Scribe_Collections.Look<T>(ref List<T>, ...)` (`:32`) for `GroupRule`'s string lists.
- `Messages.Message(string, MessageTypeDef, bool)` (`Verse\Messages.cs:47`); `MessageTypeDefOf.RejectInput`/`SilentInput` (`RimWorld\MessageTypeDefOf.cs`).
- `Mod.WriteSettings()` / `ModSettings.Write()` (`Verse\Mod.cs:34-39`, `Verse\ModSettings.cs:11`) — `GroupHotkeyLayout.Apply`/`RestoreVanillaTabKeys` call `VerbalCommandsMod.Settings.Write()` directly (rebinding happens outside the settings window, so nothing else would flush it).
- `MapPawns.FreeColonistsSpawned` (`Verse\MapPawns.cs:329`), used instead of `FreeColonists` per the brief's fallback note, since it exists.

**OnGUI ordering answer** (brief section 25): `UIRoot.UIRootOnGUI()` calls `GameComponentUtility.GameComponentOnGUI()` at `Verse\UIRoot.cs:66`. `UIRoot_Play.UIRootOnGUI()` calls `base.UIRootOnGUI()` **first** (`RimWorld\UIRoot_Play.cs:24`), then `mainButtonsRoot.MainButtonsOnGUI()` (`:31`), which is what reads the `MainTab_*` `KeyBindingDef.hotKey.KeyDownEvent` and fires the tab toggle. So `GameComponentOnGUI` (our group-key handler) runs **before** the tab-toggle check every frame. Unity's `Event.Use()` sets `Event.current.type` to `EventType.Used`; `KeyBindingDef.KeyDownEvent` gates on `Event.current.type == EventType.KeyDown` (`Verse\KeyBindingDef.cs:45`), so a `Use()` call in our handler **does** suppress a same-frame tab toggle for that event. This only matters for the Manual layout (F-keys are already unbound from the tabs in the FKeys layout, and NumberRow never touches F-keys at all).

Design decisions: rules stored, not member lists (re-evaluated live at keypress); all group `KeyBindingDef`s default to `KeyCode.None` in XML so nothing binds without consent (`KeyPrefsData.ErrorCheckOn` only auto-fixes a key that differs from the def's own default, brief fact 20); consent dialog runs once, on first `define_group` apply or from the settings button, never silently; NumberRow fallback covers only slots 1-6 (Alpha0 = slot 6) since the number row has one fewer free key than F1-F9.

Known doubt: `GroupHotkeyLayout.PromptIfUnset()` (from the settings-window button) does not check `Current.Game != null` before adding the `Dialog_MessageBox` — harmless (the dialog itself does nothing that touches map state), but it can technically be summoned from the main menu's mod-settings screen with no game loaded.
