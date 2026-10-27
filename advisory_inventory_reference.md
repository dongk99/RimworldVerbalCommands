# Tips, reminders and build hints

## Categories

| | Category | Function | file:line |
|---|---|---|---|
| A | Know-how tips (`agentTips`) | `TipInjector.ForResult` | `AgentInbox.cs:847` |
| B | Base and building reminders | `AgentChunks.ReminderLine`, `HeaterLine`, `AgentBenchScan.StonecutterLines` | `AgentReminderScan.cs:476`, `:482`, `:487` |
| | | work-spot penalty and light loop, `AgentRoomTempScan.Lines`, `StoveLine`, `BlueprintLine`, `ForbiddenLines` | `AgentReminderScan.cs:518-566`, `:572`, `:573`, `:584`, `:600` |
| | | `AgentRoomScan.Text` (12-hour) | `AgentReminderScan.cs:156-164` |
| | | door lines (under `pathfindCost`) | `AgentReminderScan.cs:165-169` |
| C | Food and farming reminders | `AgentGrowScan.Lines`, `BulkMealLine`, `AgentDeteriorationScan.Lines`, `AgentRotScan.Lines` | `AgentReminderScan.cs:125`, `:578`, `:595`, `:597` |
| D | Pawn and work reminders | `WeaponLines`, `AgentBenchScan.WorkLines`, `AgentWorkChanceScan.Lines`, `CarryMedicineLine`, `DraftLines`, `HypothermiaLine` | `AgentReminderScan.cs:488`, `:583`, `:589`, `:590`, `:599`, `:604` |
| E | Resource reminders | `AgentResourceScan.Lines`, `AgentMicro.LeftoverLines` | `AgentReminderScan.cs:481`, `:490` |
| F | Urgent reminders | `BreakTick`/`BreakLine`, `BleedTick`/`BleedLine`, `MerchantEntered`/`MerchantLine` | `AgentReminderScan.cs:376-427`, `:285-341`, `:351-374`; delivery `:200-230` |
| G | Build checks (note + confirm) | `AgentWindCheck` (`Note`, `NoteRoof`, `GeyserNote`), `AgentLightCheck` (`Note`, `NoteRoof`, `PictureNote`), `AgentWorkspotCheck.Note`, `AgentDoorCheck` (`Note`, `NoteShell`, `NoteBlockedDoors`), `AgentCoolerCheck.Note`, `AgentVentCheck.Note` | callers `AgentBuild.cs:137-142`, `:195-196`, `:338-343`; `AgentBuildShapes.cs:180-185`, `:1082-1085`; `BuildTools.cs:482-487`; `AgentAreas.cs:251-252` |
| H | Build advice notes | see "Build advice notes" | |

## Settings

`VerbalCommandsSettings` in `VerbalCommandsMod.cs` (fields `:18-65`)

| Field | Field / Scribe key / checkbox | Checked at | Gates |
|---|---|---|---|
| `agentTips` (default true) | `:56` / `"agentTips"` `:100` / `:439`, key `VerbalCommands_Settings_AgentTips` | `AgentInbox.cs:847` | `TipInjector.ForResult` |
| `pathfindCost` (default true) | `:65` / `"pathfindCost"` `:103` / `:440`, key `VerbalCommands_Settings_PathfindCost` | `AgentDoorPathScan.cs:95` | door-walk recording, daily door reminders |
| `agentInbox` | `:52` / `:99` / `:438` | | whole inbox/outbox |
| `confirmBeforeApply` | `:18`, checkbox `:431` | | overridden by `plan.askConfirm` |
| `fallbackOnCannot`, `recordHumanPlay` | `:59`, `:62` | | |

- Labels: `Languages\English\Keyed\VerbalCommands.xml:38-39`.
- `MerchantArrivalPatch.Apply()`: `VerbalCommandsMod.cs:190`.

## Channels

| Channel | Path |
|---|---|
| `tips` | `AgentInbox.cs:847-849` → `o["tips"]` `:902` |
| `reminders` | `AgentInbox.cs:856` `AgentReminderScan.TakeFor`, `:859` `AgentMicro.TakeMessages`, `:861` `AgentRoofOnly.TakeMessages`, `:863` `ResearchBenchRule.TakeMessages`, `:865` `BatteryOutdoorRule.TakeMessages` → `o["reminders"]` `:903` |
| `notes` | `plan.notes.Add` (`Executor.cs:23`) → `OrderController.cs:678` `LastPlanNotes` (field `:52`, cleared `:261`, `:1280`; `:705-708`; `:730`) → `o["notes"]` `AgentInbox.cs:887` (`planNotes` `:819`, `plan_lines` `:886`) |
| confirm | `plan.askConfirm` / `confirmBy` (`Executor.cs:24-31`) → `OrderController.cs:716-726`; `HarnessLog.Add` `:720` |
| `risky` | `AgentInbox.cs:820`, `:888`; set at `OrderController.cs:698-704` |
| hourly check | `AgentHourlyCheck.Tick` `AgentHourlyCheck.cs:60-84` (slot `TicksGame/2500`; bills.md `:74`; `HourlyLines` `:75`) → `Open` `:86-102`, vote `:105-135` → `StateField` `:158-171` → `AgentInbox.cs:953`. `BatchText` `:138`, `PauseLine` `:144`, `RefusalText` `:152`; empty scan `:78` |
| `events` | `AgentEvents.Add` `AgentEvents.cs:101` (last 500) → `AgentInbox.cs:951` (last 20, `RecentEvents` `:961-983`) |
| outbox dedupe | `WithoutRepeats` `AgentInbox.cs:900-901`; `WriteOutbox` `:754`; `WriteStateIfChanged` `:916`, `:955` |
| tick entry | `AgentEvents.Tick` `AgentEvents.cs:171` (every 60 ticks) → `RunCheck("workspots", AgentReminderScan.Tick)` `:195` → `AgentReminderScan.Tick` `:135-170` |
| reminder log | `AgentReminderLog.cs:21-48` → `logs\reminders_<time>.md` |

## Reminder scheduler (`AgentReminderScan.cs`)

- `Tick` `:135-170`: `BreakTick`, `BleedTick`, `GrowTick`, `AgentHourlyCheck.Tick` (`:137-140`)
- 6-hour slot `TicksGame/15000` (`:141-150`); `pending = Scan()` `:153`
- 12-hour: `roomPending = AgentRoomScan.Text()` (`:156-164`)
- daily: `doorPending = AgentDoorPathScan.DailyLines()` (`:165-169`)
- 3-hour: `GrowSlotTicks` `:102` (`TicksGame/7500`), `GrowTick` `:107-132`
- `OrchestratorForms` `:58-63`; delivery gate `:179-191`; cleared `:232-237`
- `MaxLines = 20` `:55`; `BlueprintKindsNamed = 5` `:1079`
- `Block` `:436-450`; `TakeFor` `:173-258` (room block `:240-245`; titles `:251-252`)
- `breakSeen` `:272`, `bleedSeen` `:282`, `merchantSeen` `:348`

## Tips (`TipInjector.cs`)

- Tip files: `mod\Tips\summary\*.md` (from `agent_player\knowhow\summary\`)
- `Load` `:618`, `Parse` `:647`, `Array.Sort` `:628`
- `MaxPerResult = 2` `:71`; `between` default 50000 context tokens `:79` (per tip file: `phrasetip` 5000, `idletip` 0)
- `Due` `:238-262`: a tip waits `between` context tokens after it was last shown; `Forget` `:229`: reset on compaction or new session; `Render` `:264-273`, `Counts` `:601`, `State` `:276-306`

| What | Function | file:line |
|---|---|---|
| Matched tips | `ForResult` | `:100-166` (`:141-144`, `:149-156`) |
| "I need tips on" line (`phrasetip.md`) | `ForResult` | `:141` |
| Blueprints short of material | `BlueprintsShort` | `:310-409` |
| Sick animal, no animal bed | `AnimalSickNoBed` | `:413-462` |
| Hunting, no corpse stockpile | `HuntNoCorpseStockpile` | `:466-486` |
| Prisoner, 0 food | `PrisonerNoFood` | `:494-513` |
| Human body, 0 food | `HumanBodyNoFood` | `:520-541` |
| Pawn bleeding out | `PawnBleedingOut` | `:548-568` |
| Colonists idle | `ColonistsIdle` | `:572-584` |
| "i need tips on X." | `Query` / `Read` | `:170-211`; `FormQueries.cs:67-68` |
| "what does BREAK do." / "list breaks." | `MentalBreakTips.QueryBreak` / `QueryList` | `MentalBreakTips.cs:40-67`, `:70-89`; `FormQueries.cs:69-73` |
| Vocabulary line `tips` | `VocabularyText` | `VocabularyText.cs:86-87` |

## Reminders

### 6-hour (`Scan()` `AgentReminderScan.cs:469-500`)

| What | Function | file:line (call) |
|---|---|---|
| Stone chunks indoors | `AgentChunks.ReminderLine` | `AgentChunks.cs:109-117`, `:29-34` (`:476`) |
| Steel/component/plasteel source | `AgentResourceScan.Line` / `Lines` | `AgentResourceScan.cs:274`, `:420-424`, `:75`, `:428-433` (`:481`) |
| Heater | `HeaterLine` | `:874-907`, `AnyTreeInView` `:863` (`:482`) |
| Stonecutter | `AgentBenchScan.StonecutterLine` / `StonecutterLines` | `AgentBenchScan.cs:229`, `:274-275`, `:114` (`:487`) |
| Unarmed better fighter | `WeaponLines` | `:975-1004` (`:488`) |
| Mining leftovers | `AgentMicro.LeftoverLines` | `AgentMicro.cs:272-291`, `:121-124` (`:490`) |
| `[TIP]` drafting line | `Scan` | `:497-498` |

### Hourly (`HourlyLines()` `AgentReminderScan.cs:505-611`)

| What | Function | file:line (call) |
|---|---|---|
| (start) | `HarnessLog.BeginHourly` | (`:507`) |
| Work spot penalty | `AgentWorkspotCheck.Penalties` | `:552-560`, cap `:545` |
| Interaction spot light | `LightLine` / `LightNeeded` | `:1156-1175`, `:1154` (`:524`, `:533`, `:565`) |
| Room temperature | `AgentRoomTempScan.Lines` / `Advice` | `AgentRoomTempScan.cs:62`, `:102-103`, `:43-56` (`:572`) |
| Vent between rooms | `AgentRoomTempScan.Vent` | `:115`, `:172-173` |
| Stove | `StoveLine` | `:832-860` (`:573`) |
| Bulk meal bill | `BulkMealLine` | `:916-964` (`:578`) |
| Too few benches | `AgentBenchScan.WorkLine` / `WorkLines` | `AgentBenchScan.cs:125`, `:198-199`, `:99` (`:583`) |
| Blueprints waiting | `BlueprintLine` | `:1081-1112` (`:584`) |
| Botched builds | `AgentWorkChanceScan.FailureLine` | `AgentWorkChanceScan.cs:92`, `:139-145` (`:589`); `MarkScanned` `:609` |
| Fail chance, better pawn | `AgentWorkChanceScan.CheckLine` | `:174`, `:187-201`, `:46`, `:55` |
| Doctor without medicine | `CarryMedicineLine` | `:1013-1070` (`:590`) |
| `[ALERT]` deterioration | `AgentDeteriorationScan.Lines` | `AgentDeteriorationScan.cs:35`, `:96-99` (`:595`) |
| Rot | `AgentRotScan.IndoorLine` / `OutdoorLine` | `AgentRotScan.cs:36-45`, `:137`, `:146` (`:597`); `HaulPlan` `:156` |
| Drafted pawns | `DraftLines` | `:621-661` (`:599`) |
| Forbidden buildings/items | `ForbiddenLines` | `:668-743`, cap `:695` (`:600`) |
| Hypothermia | `HypothermiaLine` | `:785-820` (`:604`) |

### Other cadences

| What | Function | file:line |
|---|---|---|
| 3-hour grow zones | `AgentGrowScan.BedLine` / `Lines` / `Empty` / `Stalled` / `TemperatureText` | `AgentGrowScan.cs:93`, `:135-154`, `:88`, `:42`, `:159-193`, `:197-223`, `:229-230` (`AgentReminderScan.cs:125`); `MaxGroups` 8 |
| 12-hour rooms and floors | `AgentRoomScan.Text` / `MapLines` / `NoFoodSupply` | `AgentRoomScan.cs:126-147`, `:149-197`, `:200-207`, `:144-145`, `:192-195` |
| Daily doors | `AgentDoorPathScan.MoveLine` / `CheckMoved` / `Track` / `DailyLines` | `AgentDoorPathScan.cs:431`, `:523-525`, `:530`, `:545-547`, `:107-110`, `:249`, `:93-96`; `CooldownTicks` `:67`, `:68`, `SlowerShare` `:63` |
| Mental break | `BreakLine` / `BreakTick` | `AgentReminderScan.cs:376-427` |
| Stranger bleeding out | `BleedLine` / `BleedTick` / `BleedingStranger` | `AgentReminderScan.cs:285-341` |
| Merchant | `MerchantLine` / `MerchantEntered`; `MerchantArrivalPatch.Postfix` | `AgentReminderScan.cs:351-374`; `MerchantArrivalPatch.cs:39-59`, `:53` |

## Order follow-ups (`reminders`)

| What | Function | file:line |
|---|---|---|
| Mining/hauling messages | `AgentMicro.TakeMessages` (`VeinLine`, `MoreQuestion`, `MineDone`, `HaulDone`, `AskMore`, `Finish`) | `AgentMicro.cs:258-268`, `:106-109`, `:101-104`, `:111-114`, `:116-119`, `:1108-1118`, `:1384-1394`; `veinTold` `:1092` |
| Roof-only | `AgentRoofOnly.TakeMessages` | `AgentInbox.cs:861` |
| Research bench rule | `ResearchBenchRule.TakeMessages` | `AgentInbox.cs:863` |
| Outdoor battery rule | `BatteryOutdoorRule.TakeMessages` | `AgentInbox.cs:865` |

## Build checks (`notes` + confirm)

| What | Function | file:line | confirmBy |
|---|---|---|---|
| WIND | `AgentWindCheck.Note` | `AgentWindCheck.cs:120`, `:170-172`, `:217-220`, `:225` | "Wind check" |
| WIND roof | `AgentWindCheck.NoteRoof` | `:237`, `:266-268`, `:272` | |
| GEYSER | `AgentWindCheck.GeyserNote` | `:289`, `:312-315`, `:177` | |
| LIGHT | `AgentLightCheck.Note` | `AgentLightCheck.cs:138`, `:211-304`, `:310` | "Sun lamp check" |
| LIGHT roof | `AgentLightCheck.NoteRoof` | `:351`, `:385-387`, `:388` | |
| PICTURE | `AgentLightCheck.PictureNote` | `:315-347` | |
| WORKSPOT | `AgentWorkspotCheck.Note` / `Found` / `Penalties` | `AgentWorkspotCheck.cs:91-122`, `:51-56`, `:124`, `:154`, `:159`, `:172-208` | "Work spot check" |
| DOOR / DOOR BLOCKED | `AgentDoorCheck.Note` / `NoteBlockedDoors` | `AgentDoorCheck.cs:207-209`, `:255-258` | "Door check", "Door block check" |
| Cooler | `AgentCoolerCheck.Note` | `AgentCoolerCheck.cs:56-62` | "Cooler check" |
| Vent instead | `AgentVentCheck.Note` | `AgentVentCheck.cs:45`, `:88`, `:28-29` | |
| Move chunks | `AgentChunks` | `AgentChunks.cs:146` | |
| Hostiles nearby | `AgentMicro.HostileNote` | `AgentMicro.cs:89`, `:466-467` | |

## Build advice notes (`notes`)

| What | file:line |
|---|---|
| Room shell roof rules (`AddRoofNotes`, `AddAutoRoofRules`) | `AgentBuildShapes.cs:1241-1295`, `:1272` |
| Room shell door/shift/edge | `AgentBuildShapes.cs:913-1014` |
| Roof area | `AgentAreas.cs:240`, `:244` |
| Allowed area | `AgentAreas.cs:267`, `:328` |
| Crop notes (`AddCropNotes`) | `AgentZones.cs:901-936`, `:146`, `:377`, `:420` |
| Room layouts | `AgentRoomLayouts.cs:140-155`, `:237-345`, `:681`, `:715` |
| Roof-only | `AgentRoofOnly.cs:47`, `:52`, `:146`, `:150` |
| Prison cell / beds | `FormControls.cs:552-638` |
| Unripe harvest (`UnripeNote`, `UnripeListed`) | `AgentDesignations.cs:1506`, `:1521-1544` |
| Slaughter/hunt/tame/deconstruct warnings | `AgentDesignations.cs:1256-1422`, `:1467-1474`, `:1482-1491` |
| Skill block, pawn left out | `AgentMicro.cs:414`, `:438`; `SkillBlock.cs:44` |
| Steam geyser chosen | `AgentBuild.cs:193` |
| Choice gives something up | `AgentWindows.cs:440` |

## Other plan notes and lines

- Materials, auto-stuff, skipped, left-out:
  - `AgentBuild.cs`: [`:620`, `:673`, `:815-855`, `:1058-1067`, `:1237`]
  - `Placement.cs`: [`:460-485`]
  - `AgentBuildShapes.cs`: [`:170`, `:173`, `:283`, `:959`, `:1725-1740`]
  - `BuildTools.cs`: [`:393`, `:436`, `:453`, `:480`, `:593`, `:670`, `:1020`, `:1023`, `:1153`, `:1228`, `:1232`]
  - `Executor.cs`: [`:377`, `:451`, `:600-605`, `:895-901`, `:953-970`, `:1001-1029`]
  - `FormPlanner.cs`: [`:564`, `:586`, `:653`, `:680`, `:840`, `:844`, `:933`, `:1024`]
  - `FormBills.cs`: [`:240`, `:246`, `:310`, `:386`, `:605`, `:891`]
  - `FormGroups.cs`: [`:73`, `:124`, `:177`, `:184`, `:205`, `:291`, `:319`, `:361`]
  - `FormWave1.cs`: [`:291-296`, `:386`, `:397`, `:421-431`, `:565`, `:687`, `:853`]
  - `FormWave1Care.cs`: [`:221`, `:260-279`, `:367-395`, `:582-597`]
  - `FormControlGroups.cs`: [`:195`]
  - `FormStorage.cs`: [`:509`, `:698`, `:729`]
  - `AgentInteract.cs`: [`:245`, `:491`]
  - `AgentTime.cs`: [`:574`, `:579`]
  - `AgentPawnActions.cs`: [`:387`, `:395`]
  - `AgentPawnActionsGear.cs`: [`:379-396`]
  - `AgentPawnActionsJobs.cs`: [`:214`, `:433`]
  - `AgentPawnActionsWork.cs`: [`:147`, `:511`, `:516`]
  - `AgentZones.cs`: [`:337`]
- RISKY lines:
  - `AgentAreas.cs`: [`:401`]
  - `AgentZones.cs`: [`:527`, `:532`, `:594`]
  - `AgentPawnActions.cs`: [`:605`]
  - `AgentPawnActionsGear.cs`: [`:573`]
  - `AgentPawnActionsJobs.cs`: [`:385`, `:480`]
  - `AgentDesignations.cs`: [`:1491`]
  - `AgentWindows.cs`: [`:458`]
  - `FormWave1.cs`: [`:850`, `:969`]
  - `FormWave1Care.cs`: [`:223`, `:612`]
- Event lines:
  - `AgentEvents.cs`: [`:282`, `:286`, `CheckLetters` `:258`, `PausesByDef` `:292`, `:456`, `:462`, `:466`, `:471`, `:487`, `:544`, `:636`, `CheckIdle` `:596`, `IdleReportAgainTicks` `:564`, `:703-712`, `CheckBatteries` `:640`]
  - `AgentFollow.cs`: [`:436`]
  - `AgentTime.cs`: [`:413`, `:425`]
- Inbox rejections:
  - `AgentInbox.cs`: [`:340`, `:350`, `:373`, `:417-432`, `:477-495`, `:522`, `:532`]
- Logs only:
  - `AgentReminderLog.cs`: [`:21-48`, `:72-74`]
  - `HarnessLog.cs`: [`Note` `:212`, `Add` `:239`]
  - `HumanPlayLog.cs`
  - `AgentContext.cs`
