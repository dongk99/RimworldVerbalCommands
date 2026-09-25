# Brief 04 — rule-based pawn groups with hotkey select/draft

Project root: `C:\Users\[user]\.claude\projects\RimWorld-LLM-Integration`. Decompiled engine: `sources\RimWorldDecompiled` (1.6). Installed game XML: `E:\STEAM\steamapps\common\RimWorld\Data`.
Read first: `PLAN.md` sections 1-2, `For_Claude_Debugging_Handoff_VerbalCommands.md`, every file in `src\VerbalCommands\`, `mod\Defs\KeyBindingDefs\VerbalCommands_KeyBindings.xml`, `mod\Languages\English\Keyed\VerbalCommands.xml`, `mod\README.md`.
Style: match existing code exactly (tabs, braces on own lines, no `var`, C# 7.3-safe, `Verse.Log` fully qualified inside `OrderController`). No Harmony. No new NuGet packages. Everything that touches game objects runs on the main thread (dialog GUI, `GameComponentOnGUI`, `Executor.Apply` via `MainThread.Drain`).

## Feature

The player types e.g. "group 3 = everyone holding a rifle with range 25 or more; call it long guns". The LLM calls `define_group`; the mod stores a RULE (not a member list) in slot 1..9. Pressing that slot's hotkey evaluates the rule against LIVE equipment, selects the matching pawns, and, with Alt held, drafts them. No LLM involvement at keypress.

## Verified engine facts (all path:line into sources\RimWorldDecompiled unless stated; quote, do not invent)

- Held weapon: `Pawn_EquipmentTracker.Primary` — first equipment with `equipmentType == EquipmentType.Primary`, null if unarmed (`Verse\Pawn_EquipmentTracker.cs:16-27`). Access via `pawn.equipment?.Primary`.
- `ThingDef.IsWeapon` (`Verse\ThingDef.cs:954`), `IsRangedWeapon` = IsWeapon && any verb with `!IsMeleeAttack` (`:1115-1131`), `IsMeleeWeapon` = IsWeapon && !IsRangedWeapon (`:1137-1146`).
- `ThingDef.Verbs` returns `verbs` or an empty list (`Verse\ThingDef.cs:659-668`). `VerbProperties.range` float, cells (`Verse\VerbProperties.cs:29`); `VerbProperties.IsMeleeAttack` (`:282`). Weapon range = `range` of the first verb with `!IsMeleeAttack`, else 0.
- Draft: `pawn.drafter.Drafted = true` (`RimWorld\Pawn_DraftController.cs:19-31`); identical to the draft gizmo / R key (`:158-164`). `pawn.drafter` may be null (`Verse\Pawn.cs:128`). `pawn.Downed` (`Verse\Pawn.cs:231`).
- Selection: `Find.Selector` (`Verse\Find.cs:62`); `Selector.ClearSelection()` (`RimWorld\Selector.cs:274`), `Select(object obj, bool playSound = true, bool forceDesignatorDeselect = true)` (`:294`). Defensive Positions does exactly this for squads (`sources\RimworldDefensivePositions\Source\PawnSquadSelector.cs:206-224`).
- Key events: `KeyBindingDef.KeyDownEvent` compares `Event.current.keyCode` with the def's bound A/B key from `KeyPrefs.KeyPrefsData.keyPrefs` (`Verse\KeyBindingDef.cs:43-66`). A def bound to `KeyCode.None` never matches. Handlers must call `Event.current.Use()` after handling (existing pattern in `GameComponent_VerbalCommands.cs`).
- Key storage: `KeyPrefsData.keyPrefs` is a public `Dictionary<KeyBindingDef, KeyBindingData>` (`Verse\KeyPrefsData.cs:9`); `KeyBindingData.keyBindingA/keyBindingB` are public `KeyCode` fields (`Verse\KeyBindingData.cs:7-9`); `KeyPrefs.Save()` writes them to the user's KeyPrefs file (`Verse\KeyPrefs.cs:62`). `KeyPrefs.Init` loads the file, `AddMissingDefaultBindings`, then `ErrorCheck` (`:32-61`). `KeyBindingDef.defaultKeyCodeA` and `GetDefaultKeyCode(slot)` give the XML default for restore.
- Conflict check: category-based (`Verse\KeyPrefsData.cs:65-69`); `MainTabs` checks against `Game` (`Data\Core\Defs\Misc\KeyBindings\KeyBindingCategories.xml:67-76`). `ErrorCheckOn` only auto-fixes when the bound key differs from the def's own default (`KeyPrefsData.cs:120-135`) — so our defs MUST default to `None` in XML; keys are assigned at runtime only after the player consents.
- Main tab hotkeys: `MainButtonDef.defaultHotKey` (`RimWorld\MainButtonDef.cs:17`) → generated `KeyBindingDef` named `"MainTab_" + defName` (`Verse\KeyBindingDefGenerator.cs:35-42`). From `Data\Core\Defs\Misc\MainButtonDefs\MainButtons.xml`: F1 Work, F2 Schedule, F3 Assign, F4 Animals, F5 Wildlife, F6 Research, F7 Quests, F8 World, F9 History (Tab = Architect, leave alone). Resolve with `DefDatabase<KeyBindingDef>.GetNamedSilentFail("MainTab_Work")` etc.
- Vanilla defaults occupying the number row: Alpha1..Alpha4 (time controls, `Data\Core\Defs\Misc\KeyBindings\KeyBindings.xml`). Alpha5..Alpha9 and Alpha0 are unbound in vanilla. Defensive Positions uses Keypad0..9 / KeypadPeriod / KeypadDivide / T (`sources\RimworldDefensivePositions\Mods\DefensivePositions\Defs\KeyBindingDefs\KeyBindings.xml`), i.e. no overlap with the number row.
- Dialogs: `Dialog_MessageBox(TaggedString text, string buttonAText, Action buttonAAction, string buttonBText, Action buttonBAction, string title, ...)` (`Verse\Dialog_MessageBox.cs:62`); show with `Find.WindowStack.Add`.
- Persistence: `GameComponent.ExposeData()` (`Verse\GameComponent.cs:19`); `Scribe_Collections.Look<K,V>(ref Dictionary<K,V>, label, LookMode keyLookMode, LookMode valueLookMode, ref List<K> keysWorkingList, ref List<V> valuesWorkingList, ...)` (`Verse\Scribe_Collections.cs:433`) — use `LookMode.Value` for int keys and `LookMode.Deep` for `IExposable` values; keep the two working lists as fields. Read the Scribe API in the decompiled source before using it; cite what you used.
- OnGUI ordering: `GameComponentUtility.GameComponentOnGUI()` is called from `Verse\UIRoot.cs:66`; main-tab shortcuts are handled in `RimWorld\MainButtonsRoot.cs:54-56`. Read both to determine which runs first and whether `Event.current.Use()` in our handler suppresses the tab toggle; write the answer in the handoff doc. Regardless, the F-key layout only exists after the tab keys were unbound, so ordering only matters for the "Manual" layout if the player binds a clashing key themselves.

## Anthropic strict-schema rules (already applied elsewhere in ToolDefinitions.cs)
`additionalProperties:false`, every property in `required`, NO `minimum/maximum/minItems/maxItems/minLength/maxLength`; put limits in `description` and enforce in the executor. `enum` values may come back in a different case — compare case-insensitively.

## Changes

### 1. `Snapshot.cs`
Per colonist add `"weapon"`: `null` when `pawn.equipment?.Primary == null`, else `{ "def": def.defName, "label": primary.LabelCap (string), "ranged": def.IsRangedWeapon, "range": <float, rule above, 1 decimal> }`. Add top-level `"weapons_held"`: sorted distinct list of defNames currently held by colonists. Add top-level `"groups"`: array of `{slot, name, rule summary string}` for currently defined groups (from the GameComponent, see 4) so the LLM knows which slots are taken. Keep all existing fields.

### 2. `ToolDefinitions.cs`
Add two strict tools (and mention them in the system prompt: what groups are, that rules are evaluated live at keypress, slots 1-9, that `allowed_weapons` must come from `weapons_held` or be a real weapon defName, and that the player presses the slot key to select and Alt+key to draft):
- `define_group`: `slot` (integer, "1 to 9; overwrites that slot"), `name` (string, "short label, 1-30 chars"), `rule` object: `weapon_class` enum ["ranged","melee","any"], `min_range` (integer, "cells; 0 = no minimum; only meaningful for ranged"), `max_range` (integer, "0 = no maximum"), `allowed_weapons` (array of string, "weapon defNames; empty = any weapon passing class/range"), `include_unarmed` (boolean); `always_include_ids` (array of string), `always_exclude_ids` (array of string). All required.
- `clear_group`: `slot` (integer 1-9).

### 3. `GroupRule.cs` (new) — `public sealed class GroupRule : IExposable` with fields `name`, `weaponClass` (string, lowercased), `minRange`, `maxRange` (float), `allowedWeapons` (List<string>), `includeUnarmed` (bool), `alwaysIncludeIds`, `alwaysExcludeIds` (List<string>, ThingIDs). `ExposeData` with `Scribe_Values`/`Scribe_Collections` (LookMode.Value). Methods:
- `bool Matches(Pawn p)`: if id in alwaysExclude → false; if id in alwaysInclude → true; primary = p.equipment?.Primary; if null → includeUnarmed; def must be IsWeapon; class check (`ranged` → IsRangedWeapon, `melee` → IsMeleeWeapon, `any` → either); range check only when def.IsRangedWeapon and (minRange > 0 → range >= minRange; maxRange > 0 → range <= maxRange); if allowedWeapons non-empty → def.defName in list (ordinal).
- `string Summary()`: one line for logs/snapshot, e.g. `ranged, range>=25, weapons [Gun_BoltActionRifle, Gun_SniperRifle], +1 forced, -1 excluded`.
- `static float WeaponRange(ThingDef def)`.

### 4. `GameComponent_VerbalCommands.cs`
- Fields: `Dictionary<int, GroupRule> groups`, working lists, `public static GameComponent_VerbalCommands Instance` (set in ctor; guard `Current.Game.GetComponent<GameComponent_VerbalCommands>()` as fallback accessor).
- `ExposeData` saves `groups` (label `"vcGroups"`).
- `public void SetGroup(int slot, GroupRule rule)`, `ClearGroup(int slot)`, `GroupRule GetGroup(int slot)`, `IEnumerable<KeyValuePair<int, GroupRule>> AllGroups`.
- `GameComponentOnGUI`: keep the existing Return handling. Then, if `Current.ProgramState == Playing`, no `Dialog_VerbalCommand` open, `!Find.WindowStack.AnySearchWidgetFocused`, and `GUIUtility.keyboardControl == 0` (no text field focused — number-row layout would otherwise type into text boxes): for slot 1..9, if `VerbalCommandsDefs.GroupKeys[slot].KeyDownEvent` → `ActivateGroup(slot, draft: Event.current.alt)`; `Event.current.Use()`.
- `ActivateGroup(int slot, bool draft)`: rule null → `Messages.Message("...slot empty...", MessageTypeDefOf.RejectInput, false)` (read `Verse\Messages.cs` for the signature and cite it); else map = `Find.CurrentMap`; members = `map.mapPawns.FreeColonistsSpawned` (verify member exists in `Verse\MapPawns.cs`, else use `FreeColonists` + `Spawned`) filtered by `rule.Matches`; `Find.Selector.ClearSelection()`; `Select(p, playSound: false)` each; if `draft`: for each with `drafter != null && !Downed && !Drafted` → `Drafted = true`; `Messages.Message("<name>: N selected[, M drafted]", MessageTypeDefOf.SilentInput or NeutralEvent, false)`.

### 5. `VerbalCommandsDefs.cs`
Add `public static readonly KeyBindingDef[] GroupKeys` (index 1..9, index 0 null) resolved from defNames `VerbalCommands_Group1`..`_Group9`.

### 6. `mod\Defs\KeyBindingDefs\VerbalCommands_KeyBindings.xml`
Add nine `KeyBindingDef`s `VerbalCommands_Group1..9`, labels "verbal commands: group N (Alt = draft)", `<category>Game</category>`, `<defaultKeyCodeA>None</defaultKeyCodeA>`. Verify that `None` parses (it is the `KeyCode` enum's zero member; check how `KeyBindingDef` declares `defaultKeyCodeA` in `Verse\KeyBindingDef.cs:9-11` and confirm `KeyCode.None` exists in `UnityEngine.KeyCode`).

### 7. `GroupHotkeyLayout.cs` (new) — static class owning the consent flow and rebinding
- Enum `GroupKeyLayout { Unset, FKeys, NumberRow, Manual }` persisted in `VerbalCommandsSettings.groupKeyLayout` (string) via `Scribe_Values`.
- `Apply(GroupKeyLayout layout)`:
  - `FKeys`: for i in 1..9: main tab def `MainTab_<name>` for the F-key list above — if its bound A or B key equals F(i), set that slot to `KeyCode.None`; set `GroupKeys[i].keyBindingA = KeyCode.F1+i-1` (use an explicit `KeyCode.F1..F9` array, not arithmetic). Then `KeyPrefs.Save()`. Log which tab keys were unbound.
  - `NumberRow`: Group1..5 ← Alpha5..Alpha9, Group6 ← Alpha0; Group7..9 stay None. Save.
  - `Manual`: nothing bound; save layout only.
- `RestoreVanillaTabKeys()`: for each `MainTab_*` def in the list, set `keyBindingA = def.defaultKeyCodeA` (and B to `defaultKeyCodeB`), set all Group keys to None, layout = Unset, `KeyPrefs.Save()`.
- `PromptIfUnset()`: if layout != Unset return. Show `Dialog_MessageBox` #1: text = "Verbal Commands can bind F1-F9 to pawn groups 1-9 (Alt+key drafts). Those keys currently toggle the Work, Schedule, Assign, Animals, Wildlife, Research, Quests, World and History tabs; the tabs stay clickable, only the shortcut is removed. This is reversible in Mod settings. Unbind them?" buttonA "Yes, use F1-F9" → Apply(FKeys); buttonB "No" → Dialog #2: "Use the number row 5, 6, 7, 8, 9, 0 for groups 1-6 instead? (Unbound in vanilla and Defensive Positions; 3 slots fewer.)" buttonA "Yes" → Apply(NumberRow); buttonB "No, I'll bind keys myself in Options > Keyboard" → Apply(Manual). Text goes in Languages XML keys.

### 8. `Executor.cs`
- `ResolveDefineGroup`: slot int 1..9 else Fault; name trimmed non-empty and at most 30 chars else Fault; weapon_class lowercased in {ranged, melee, any} else Fault; min_range/max_range >= 0 and (max == 0 || max >= min) else Fault; each allowed weapon: `DefDatabase<ThingDef>.GetNamedSilentFail`, must exist and `IsWeapon` else Fault naming it; if no colonist currently holds it → note; ids must be in `snap.pawnsById` else Fault. Plan write description: `group <slot> "<name>": <Summary()>`; apply = `GameComponent_VerbalCommands.Instance.SetGroup(slot, rule)` then `GroupHotkeyLayout.PromptIfUnset()`. Add a note listing which colonists match the rule RIGHT NOW (names), so the preview shows the effect.
- `ResolveClearGroup`: slot 1..9; Fault if slot empty; write = ClearGroup.
- Wire both into `Resolve`.

### 9. `VerbalCommandsMod.cs` settings UI
Add: label showing current layout; button "Choose group hotkeys..." → resets layout to Unset and calls `PromptIfUnset()`; button "Restore vanilla tab keys (F1-F9)" → `RestoreVanillaTabKeys()`. Persist `groupKeyLayout`.

### 10. `Dialog_VerbalCommand.cs`
No change unless something above requires it.

### 11. Languages XML, README.md (mod), handoff doc
Add all new UI strings as keys. README: new "Pawn groups" section (what a rule is, live evaluation, keys, the consent flow, restore button, Alt = draft, downed pawns are selected but not drafted). Handoff doc: new section "Groups (brief 04)" with the engine facts above (keep path:line), the OnGUI-ordering answer from the fact list, files added, and the design decisions (rules not members; None defaults; consent before rebinding; NumberRow fallback = 6 slots). Do not rewrite other sections.

### 12. Build
`powershell -ExecutionPolicy Bypass -File build.ps1` from the project root; fix compile errors in files you own; paste the tail. Then confirm the deployed `VerbalCommands.dll` contains the UTF-16 strings `define_group` and `MainTab_Work` (python: `s.encode('utf-16-le') in open(path,'rb').read()`).

## Rules
- Quote nothing you did not read; every engine member you use that is not in the fact list above must be verified in the decompiled source and cited in your report.
- Do not add settings beyond `groupKeyLayout`. Do not touch `HeadlessClient.cs` beyond what is needed for the new tools to flow through its schema builder (it clones `input_schema` per tool generically; verify it needs no change).
- Report: files changed/added with line counts, build tail, the two DLL string checks, and every doubt.
