# E. Existing RimWorld mods: colonist groups, group hotkeys, weapon-based grouping

Question: do existing mods let the player (a) assign colonists to named/numbered groups, (b) draft or select a group with a hotkey, (c) build groups by the weapon / weapon type the pawn holds? Target: RimWorld 1.6.

Method: every GitHub-hosted mod was cloned with `git clone --depth 1` into `sources\<RepoName>` under this project and the About.xml + C# source were read directly. Steam Workshop pages were fetched via the WebFetch tool; that tool returns a processed rendering of the page, not the raw HTML, so Workshop-derived statements below are marked "Workshop description (fetch rendering)" and are descriptions, not code. All paths below are relative to `C:\Users\[user]\.claude\projects\RimWorld-LLM-Integration\sources\`.

Discovery searches (WebSearch, this session): "UnlimitedHugs RimworldDefensivePositions github"; "RimWorld Colony Groups mod github Taranchuk"; "RimWorld Better Pawn Control mod github source"; "RimWorld mod control groups OR squads draft colonists hotkey"; "RimWorld mod group colonists by weapon draft melee ranged squad hotkey 1.6"; "github Taranchuk TacticalGroups Colony Groups RimWorld source"; "RimWorld Squad Behaviours mod github source 3523697049"; "Squad Behaviours RimWorld Gr_im github"; "RimWorld SquadBehaviour OR Squad Behaviours mod source code github LifeIsGame". No mod literally named "Squads" or "Control Groups" for RimWorld surfaced in any of these; the closest hits were "Colony Groups Hotkeys" and "Squad Behaviours" (both covered below).

---

## 1. Defensive Positions — UnlimitedHugs

- Repo: https://github.com/UnlimitedHugs/RimworldDefensivePositions (clone at `RimworldDefensivePositions\`, HEAD e264a7215be40830e3db65e3264319648ec4f553, 2025-07-27)
- Workshop ID 761219125 (`RimworldDefensivePositions\Mods\DefensivePositions\About\PublishedFileId.txt`; Workshop page fetched, see below)
- About.xml: `RimworldDefensivePositions\Mods\DefensivePositions\About\About.xml:3-15` — name "Defensive Positions", author "UnlimitedHugs", supportedVersions 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, **1.6**; packageId UnlimitedHugs.DefensivePositions; depends on UnlimitedHugs.HugsLib (:46-47). A `v1.6\Assemblies\DefensivePositions.dll` is shipped (`RimworldDefensivePositions\Mods\DefensivePositions\v1.6\Assemblies\`).
- No README in the repo (only `license.txt`).

### (a) Numbered groups — YES (numbered 1-9, not named)
- `Source\PawnSquad.cs:9-18` — class `PawnSquad : IExposable` with `int squadId` and `List<Thing> members`. Members can be pawns or buildings (:17 comment; eligibility at :48-50 requires player faction).
- `Source\PawnSquadHandler.cs:13-14` — `SquadHotkeyNameBase = "DPSquad"`, `NumSquadHotkeys = 9`.
- Assignment: `Source\PawnSquadHandler.cs:54-70` — when Control is held (`HugsLibUtility.ControlIsHeld`, :55) and a squad key is pressed, the current selection (`Find.Selector.SelectedObjects`, :102-108, or selected caravans on the world map, :90-100) is written into that squad via `ReassignSquadMembers` (:131-139); empty selection clears the squad (:69, :141-145).
- Persistence: `Source\WorldData.cs:24-28, 57` — `List<PawnSquad> pawnSquads` saved in a `WorldComponent`.
- Groups are numbered only; there is no name field on `PawnSquad` (`Source\PawnSquad.cs:9-59`).

### (b) Hotkey select / draft — SELECT yes; DRAFT-the-squad not directly (draft is per selected pawn via a separate key)
- Key defs: `Mods\DefensivePositions\Defs\KeyBindingDefs\KeyBindings.xml:34-78` — `DPSquad1`..`DPSquad9`, defaults Keypad1..Keypad9; also `DPSelectAllColonists` (KeypadPeriod, :15-19), `DPSendAllColonists` (Keypad0, :21-25), `DPUndraftAll` (KeypadDivide, :27-31), `DefensivePositionGizmo` (T, :9-13).
- Key polling: `Source\PawnSquadHandler.cs:27-52` — `OnGUI` on `EventType.KeyDown`, matches `KeyPrefs.KeyPrefsData.keyPrefs[key].keyBindingA/B`; called from `Source\DefensivePositionsManager.cs:113-117` (`ModBase.OnGUI`).
- Selecting a squad: `Source\PawnSquadHandler.cs:71-77` → `PawnSquadSelector.TryActivateSquad` (`Source\PawnSquadSelector.cs:36-63`) → `TrySelectInterestPointSquadMembers` (:206-224) which calls `Find.Selector.ClearSelection()` (:215, unless Shift held :207) and `Find.Selector.Select(thing)` (:220). Repeated presses cycle the camera through member clusters/caravans (:11-13 comment, :45-51, `CameraJumper.TryJump`).
- Drafting: the squad hotkeys **do not draft**. Drafting happens through the "defensive position" job: `Source\PawnSavedPositionHandler.cs:170-174` `DraftToPosition` makes job `DPDraftToPosition` and `Owner.jobs.TryTakeOrderedJob(job, JobTag.DraftedOrder)`; the job driver sets the engine member directly: `Source\JobDriver_DraftToPosition.cs:27` `pawn.drafter.Drafted = true;` then queues `JobDefOf.Goto` (:35-36) or `JobDefOf.ManTurret` (:30-31). The `DefensivePositionGizmo` hotkey (T) triggers this for selected pawns (`Source\PawnSavedPositionHandler.cs:48, 59` hotKey on the gizmo; `:93-96, 148-167`); `DPSendAllColonists` does it for every colonist on the visible map (`Source\MiscHotkeyHandler.cs:38-55`). So the practical flow "press Keypad1 (select squad 1) then T (draft-to-position)" exists, but there is no single-key "draft squad N".
- Undraft: `Source\MiscHotkeyHandler.cs:57-71` — `pawn.drafter.Drafted = false;` (:61) for all colonists on all maps.
- Gizmo injection: `Source\DraftController_GetGizmos_Patch.cs:11-31` — Harmony postfix on `Pawn_DraftController.GetGizmos`, inserted after the vanilla draft toggle.

### (c) Weapon-based grouping — NO
- Squad membership is only ever the current selection (`Source\PawnSquadHandler.cs:59-64, 102-108`). `grep -rniE 'IsRangedWeapon|IsMeleeWeapon|equipment\.Primary' RimworldDefensivePositions\Source` returned nothing.

### Workshop description (fetch rendering) — https://steamcommunity.com/sharedfiles/filedetails/?id=761219125
Fetch returned: title "Defensive Positions", author shown as "Symbolic", Updated Jul 27, 2025, version tags 1.0-1.6, description including "keys to quickly create and select groups of colonists for easier control in battle", HugsLib required. Description only; the code above is authoritative.

---

## 2. [LTO] Colony Groups — BICKLEY / Taranchuk (source repo mirror TroyAlias/tacticalgroups)

- Repo: https://github.com/TroyAlias/tacticalgroups (clone at `tacticalgroups\`, HEAD fd36834f8b7509725649f3cc6df7faa6888f7981, 2025-07-16). Repo title on GitHub (from search result) "Colony Groups - Bickley and Taranchuk". Whether this is the authors' canonical repo or a third-party mirror: **unverified** (the Workshop page fetch returned no GitHub link).
- Workshop ID 2345493945 (`tacticalgroups\About\PublishedFileId.txt` exists; Workshop page fetched, see below)
- About.xml: `tacticalgroups\About\About.xml:3-12` — name "[LTO] Colony Groups", author "DerekBickley", supportedVersions 1.2, 1.3, 1.4, 1.5, **1.6**; packageId DerekBickley.LTOColonyGroupsFinal; depends on brrainz.harmony (:17). Per-version folders `1.2`..`1.6` each with Source/Assemblies (`tacticalgroups\1.6\Source\TacticalGroups\`). No README in the repo.
- All code citations below are from the `1.6` folder.

### (a) Named groups — YES (auto-numbered default name, renamable)
- Creation: `1.6\Source\TacticalGroups\ColonistBar\ColonistBar.cs:273-286` `HandleGroupingClicks` — on left-click of the create-group rect, takes `Find.Selector.SelectedPawns` filtered to player faction (:277) and calls `TacticUtils.TacticalGroups.AddGroup(selectedPawns)` (:281). `1.6\Source\TacticalGroups\TacticalGroups.cs:52-56` `AddGroup` inserts `new PawnGroup(pawns)` into `pawnGroups` (a `WorldComponent`, :17).
- Default name: `1.6\Source\TacticalGroups\ColonistGroup\PawnGroup.cs:43-51` — `curGroupName = defaultGroupName + " " + groupID`, `groupID` from `CreateGroupID()` (:74-80, count-based).
- Rename: `1.6\Source\TacticalGroups\ColonistGroup\ColonistGroup.cs:51-56` `SetName(string)`; dialog `1.6\Source\TacticalGroups\Menus\Dialog_RenameColonistGroup.cs:30-34`. Name persisted at `ColonistGroup.cs:1267` (`Scribe_Values.Look(ref groupName, "groupName")`).
- Add/remove pawns to an existing group: `1.6\Source\TacticalGroups\Menus\MainFloatMenu.cs:215-229` (add selected), `:190-207` (disband selected).

### (b) Hotkey select / draft — NO hotkeys; mouse only (select on double-click, draft via "Rally" button)
- Only one KeyBindingDef in the mod: `1.6\Defs\KeybindingDefs\MainButton.xml:11-17` `TG_SlaveMenu` (LeftControl + S), handled at `1.6\Source\TacticalGroups\TacticalGroups.cs:28-41` — opens the slave menu. No group-select/draft keybinding exists; `grep -rnE 'KeyCode\.|Input\.GetKey|KeyBindingDefOf|JustPressed'` over `1.6\Source` (excluding dialogs/color picker) returned nothing else.
- Select group by mouse: `1.6\Source\TacticalGroups\ColonistGroup\ColonistGroup.cs:294-304` — double-click on the group banner → `Find.Selector.ClearSelection()` then `Find.Selector.Select(pawn)` for each member. Helper `1.6\Source\TacticalGroups\Utils\TacticUtils.cs:209-216` `SelectAll(this ColonistGroup)`.
- Draft group by mouse: `1.6\Source\TacticalGroups\Menus\MainFloatMenu.cs:28-50` "Rally" button — selects each active pawn and sets `pawn.drafter.Drafted = true;` (:42) when `CanBeDrafted()`. Extension methods `TacticUtils.cs:217-226` `Draft` (`pawn.drafter.Drafted = true;` :223) and `:233-242` `Undraft` (`pawn.drafter.Drafted = false;` :239); `CanBeDrafted` at `:228-231`.

### (c) Weapon-based grouping — PARTIAL: weapon-type *selection filter inside an existing group*, not group construction
- `1.6\Source\TacticalGroups\Menus\OrderMenu.cs:305` — `var shooters = this.colonistGroup.ActivePawns.Where(x => x.equipment?.Primary?.def.IsRangedWeapon ?? false);` and `:352` `var melees = ... IsMeleeWeapon ...`. Clicking the shooter icon (:312-324) or melee icon (:361-373) does `Find.Selector.ClearSelection()` + `Find.Selector.Select(...)` for just those pawns.
- No code path constructs a `PawnGroup` from a weapon predicate; the only `PawnGroup` construction sites are `TacticalGroups.cs:54` (from `AddGroup`) and the callers `ColonistBar.cs:281` (from current selection). A weapon-based group can therefore only be produced manually in two steps (click shooters/melee filter → selection → click create-group).
- Other weapon references are unrelated to grouping: `TacticUtils.cs:350-372` (auto-equip weapon preference), `ColonistGroup.cs:914` / `PawnGroup.cs:186` (Combat Extended ammo check for icon overlay), `Enums.cs:53-57` `WeaponShowMode` (icon display).

### Workshop description (fetch rendering) — https://steamcommunity.com/sharedfiles/filedetails/?id=2345493945
Fetch returned: title "[LTO] Colony Groups", authors "BICKLEY, pointfeev, Black_moons, Taranchuk", Updated July 18, 2025, version tags 1.2-1.6, description including "simply select some pawns, click the create group button" and "Show Pawn Weapons" display toggle. The fetch also returned the line "This item was removed from the community for violating Steam Community & Content Guidelines and is only visible to the creator." — reported as returned; its current accuracy is **unverified** (the same fetch also returned subscriber counts). Description only; code above is authoritative.

---

## 3. Colony Groups Hotkeys — Bodil Stokke (add-on for [LTO] Colony Groups)

- Repo: https://github.com/bodil/ColonyGroupsHotkeys (clone at `ColonyGroupsHotkeys\`, HEAD d30a37c73170141cc34e2200feec86ba0926a2bc, 2022-10-24)
- Workshop ID 2397993374 (`ColonyGroupsHotkeys\Mod\About\PublishedFileId.txt`; page fetched, see below)
- About.xml: `ColonyGroupsHotkeys\Mod\About\About.xml:2-9` — name "Colony Groups Hotkeys", author "Bodil Stokke", packageId bodilpwnz.ColonyGroupsHotkeys, supportedVersions **1.2, 1.3, 1.4 only — no 1.5, no 1.6**; depends on brrainz.harmony (:14) and DerekBickley.LTOColonyGroupsFinal (:20, :26). Shipped assemblies only for 1.2/1.3/1.4 (`ColonyGroupsHotkeys\Mod\1.{2,3,4}\Assemblies\`).
- README: `ColonyGroupsHotkeys\README.md:3-4` — "adds keyboard shortcuts to the [LTO] Colony Groups mod". MPL-2.0 (:10).

### (a) Groups — delegates to Colony Groups; adds hotkey *creation/overwrite* of numbered pawn groups
- `Source\Utils.cs:59-79` `CreateGroup(int index)` — takes `Find.Selector.SelectedPawns`, calls `TacticUtils.TacticalGroups.AddGroup(selected)` (:76). `Source\Extensions.cs:149-161` `SetGroupToCurrentSelection` — replaces an existing group's `pawns` with the selection. Both fire on the "set" modifier + group key (`Source\ColonyGroupsHotkeys.cs:103-106`).
- Index → group mapping: `Source\Utils.cs:31-45` `GetActivePawnGroupByIndex` (reverse order of `TacticUtils.GetAllPawnGroupFor(colony)`).

### (b) Hotkey select / draft / undraft — YES (this mod is exactly that), but only for game versions 1.2-1.4
- Key defs: `Mod\Common\Defs\KeyBindingDefs\KeyBindings.xml` — `SelectCurrentColony` (:4-8), `DraftCurrentColony` (:9-13), `UndraftCurrentColony` (:14-18), `BattleStationsCurrentColony` (:19-23), `BattleStationsAction` (:24-28), `SelectColony1..12` (:30-89), `SelectGroup1..12` (:91-150). No default key codes in the XML (all unbound by default).
- Dispatch: `Source\ColonyGroupsHotkeys.cs:28-129` `OnGUI` (hooked via Harmony postfix on `UIRoot.UIRootOnGUI`, `Source\Patches.cs:22-32`). Group key + modifier selects the action: draft modifier → `Extensions.DraftGroup` (:107-109), undraft → `UndraftGroup` (:111-113), battle stations → `ToBattleStations` (:115-117), else `SelectGroup` (:119-122). Modifiers are configurable and default to `Disabled` (`Source\Settings.cs:9, 27-31`).
- Draft implementation: `Source\Extensions.cs:102-117` `DraftGroup` → `group.SelectGroup()` then `group.Draft()` — i.e. Colony Groups' `TacticUtils.Draft`, which sets `pawn.drafter.Drafted = true` (`tacticalgroups\1.6\Source\TacticalGroups\Utils\TacticUtils.cs:223`). Undraft `:119-132` → `group.Undraft()` (`TacticUtils.cs:239` `pawn.drafter.Drafted = false`).
- Battle stations: `Source\BattleStationsJob.cs:32-60` `JobDriver_ToBattleStations` sets `pawn.drafter.Drafted = true;` (:46) then `JobDefOf.Goto` with `LocomotionUrgency.Sprint` via `TryTakeOrderedJob(job, JobTag.DraftedOrder)` (:47-50); position comes from Colony Groups' formation data (`Source\Extensions.cs:37-51`).
- Select: `Source\Extensions.cs:69-100` `SelectGroup` → `Utils.SelectOrJumpToGroup` (`Source\Utils.cs:83-101`) → `group.SelectAll()` (Colony Groups `TacticUtils.cs:209-216`); repeated presses cycle the camera through members (:85-94).

### (c) Weapon-based grouping — NO
- `grep -rniE 'IsRangedWeapon|IsMeleeWeapon|equipment\.Primary' ColonyGroupsHotkeys\Source` returned nothing.

### Workshop description (fetch rendering) — https://steamcommunity.com/sharedfiles/filedetails/?id=2397993374
Fetch returned: Updated October 23, 2022, version tags 1.2, 1.3, 1.4, notice "This item is incompatible with RimWorld", source link https://github.com/bodil/ColonyGroupsHotkeys, and an author comment dated July 22, 2025: "this isn't getting updated by me, I stopped using Colony Groups a long time ago" recommending "Defensive Positions for the grouping hotkeys nowadays." Description/comment only.

---

## 4. Better Pawn Control — VouLT

- Repo: https://github.com/voult2/BetterPawnControl (clone at `BetterPawnControl\`, HEAD 7cfc247ca1981f3037a6f5693deec061ee5e4564, 2025-09-20)
- Workshop ID 1541460369 (`BetterPawnControl\README.md:3`)
- About.xml: `BetterPawnControl\About\About.xml:3-12` — name "Better Pawn Control", author "VouLT", supportedVersions 1.2, 1.3, 1.4, 1.5, **1.6**; packageId VouLT.BetterPawnControl; depends on brrainz.harmony (:38).
- README: `BetterPawnControl\README.md:5-9` — "Bulk assignment of colonists and animals to outfits, areas, drugs, food, work in one single action"; "'Emergency' button to toggle the configured policies at once in one click or keyboard shorcut."

### (a) Groups — NO (policies, not pawn groups)
- The unit is a `Policy` (`Source\Base\Policy.cs:5-8`: `int id`, `string label`) that maps every colonist to an outfit/area/drug/food/work/etc. setting; it is a colony-wide preset, not a subset of pawns. There is no structure holding a list of member pawns as a group.

### (b) Hotkey select / draft — NO
- Only keybinding: `v1.6\Defs\KeyBindingDefs\KeyBindings.xml:8-12` `BetterPawnControlEmergency` (default key `5`). Handler `Source\Patches\UIRoot_OnGUI_onKeyPress.cs:10-18` → `PlaySettings_DoPlaySettingsGlobalControls.EmergencyToogleButton()` (`Source\Patches\PlaySettings_DoPlaySettingsGlobalControls.cs:37-83`), which swaps active policies (`AlertManager.LoadState`) and optionally interrupts jobs (`Source\Managers\AlertManager.cs:47-63`). It reads `pawn.Drafted` (:53, :58) but never sets it; `grep -rnE 'drafter|Drafted|Selector\.Select'` over `Source\` shows no draft assignment and no selection code.

### (c) Weapon-based grouping — NO
- "Weapons" in BPC is a policy that stores a per-pawn *loadout id* from the separate mod "Weapons Tab Reborn" via reflection: `Source\Helpers\Widget_WeaponsTabReborn.cs:28-49`; link record `Source\Base\WeaponsLink.cs:8-9` (`Pawn colonist; int loadoutId`); manager `Source\Managers\WeaponsManager.cs:59-91, 109-136`. It does not read the pawn's held weapon; grep for `IsRangedWeapon|IsMeleeWeapon|equipment.Primary` in `BetterPawnControl\Source` returned nothing.

---

## 5. Squad Behaviours — Gr_im (Workshop only; source NOT found)

- Workshop ID 3523697049 — https://steamcommunity.com/sharedfiles/filedetails/?id=3523697049 (fetched; fetch rendering)
- Workshop description (fetch rendering): author "Gr_im", Created Jul 12, 2025, Updated Jul 18, 2025, tags 1.5, **1.6**. Description states the mod lets players "group pawns into squads for tactical combat and coordination", with formations, an order system, a duty system, and usage "Select a pawn, open bio tab, click the leader toggle button to enable the squad panel where groups can be created, managed, merged, and ordered."
- No GitHub/source link was returned by the page fetch, and three WebSearch queries found no repository. **Code is unverified.** From the description alone: (a) squads exist (description); (b) no hotkey is mentioned in the fetched description — unverified; (c) no weapon-based grouping is mentioned — unverified. Nothing about how draft is performed can be stated.

---

## Summary

| Mod | 1.6 in About.xml | (a) groups | (b) hotkey select | (b) hotkey draft | (c) by weapon |
|---|---|---|---|---|---|
| Defensive Positions | yes | yes, numbered 1-9 (`PawnSquad.squadId`) | yes (Keypad1-9 → `Find.Selector.Select`) | no single key; select squad then T = draft-to-position job (`pawn.drafter.Drafted = true` in `JobDriver_DraftToPosition.cs:27`); KeypadDivide undrafts all | no |
| [LTO] Colony Groups | yes | yes, named + auto-numbered | no hotkey (double-click banner) | no hotkey ("Rally" button sets `pawn.drafter.Drafted = true`, `MainFloatMenu.cs:42`) | selection filter only (`OrderMenu.cs:305, 352`), not group construction |
| Colony Groups Hotkeys | **no (1.2-1.4)** | via Colony Groups; hotkey set/create numbered group | yes (SelectGroup1-12, unbound by default) | yes (modifier + group key → `TacticUtils.Draft`) | no |
| Better Pawn Control | yes | no (policies) | no | no | no |
| Squad Behaviours | Workshop tag only | description says yes | unverified | unverified | unverified |

- (a)+(b) on 1.6 with verified code: **Defensive Positions** is the only one with hotkey group selection on 1.6; drafting a hotkey-selected group needs the second key (T / defensive position) or vanilla R. **Colony Groups** has richer named groups and one-click draft on 1.6 but no hotkeys. **Colony Groups Hotkeys** delivers the full hotkey select+draft flow but supports only 1.2-1.4 and its author states it is unmaintained.
- (c) weapon-based grouping: **no mod examined builds groups from held weapon/weapon type.** The closest is Colony Groups' ranged/melee selection filter inside an already-built group (`tacticalgroups\1.6\Source\TacticalGroups\Menus\OrderMenu.cs:305-324, 352-373`).
- Draft mechanism in all verified code: direct assignment to `Pawn.drafter.Drafted` (`Pawn_DraftController.Drafted`), sometimes followed by `pawn.jobs.TryTakeOrderedJob(JobDefOf.Goto, JobTag.DraftedOrder)`.

Unverified / open:
- Squad Behaviours source and behaviour beyond its Workshop description.
- Whether TroyAlias/tacticalgroups is the authors' canonical Colony Groups repo or a mirror, and the meaning of the "removed from the community" line the Workshop fetch returned.
- Workshop page content was obtained via WebFetch's processed rendering, not raw HTML.
- No mod named "Squads" or "Control Groups" was found for RimWorld; existence not proven either way.
