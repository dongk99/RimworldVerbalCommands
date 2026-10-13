# REQUIRED READING for every agent playing RimWorld through the interpreter

Read this file in full before your first order, every session. It is the mod author's own play of a 3-colonist crashlanded start on a -22C
map, read day by day with the reasoning behind each move. It was read from the raw action log that the mod's
"Record human gameplay" setting writes; lines in that log starting `[Event]`, `[Reasoning]`, `[day 18~24]`
and `[Layout` were written by the human and outrank anything inferred here.

## End-of-day note (required, every game day)
At the end of each game day (hour 0 of the next day, read from `show speed.` or `inbox_state.json`,
60000 ticks = 1 day):
1. **Pause the game**: `set game speed to paused.` with `mode: raw apply`. Pause rule:
   the agent never pauses the game unless necessary, e.g. busy doing tasks like writing memos, checking
   game status, reading memos, delegating tasks to other agents. Writing this note is such a task.
2. Read the previous day's note, `day_NN-1.md` (at session start: the newest two at least, all of them if the
   colony is new to you). Then write `<skill folder>\play_log\day_NN.md` (NN = the game day just
   ended) with these sections:
   - **What I did today**: orders applied, with cells; what failed or was refused, quoted.
   - **Short-term goal** (next 1-3 days): the concrete thing and why it comes first.
   - **Long-term goal** (the colony): where this is heading (e.g. fabrication, a renewable material, a
     killbox) and why.
   - **Pawns to secure**: which colonist(s) you must keep alive, fed, warm or out of fights, and the
     reasoning (the only researcher, the only doctor, the only builder, carrying the colony's one rifle...).
   - **Reference check**: one line on what the human did on the same day in this file, and whether you are
     doing the same, different, and why.
   - **Against yesterday**: which of yesterday's goals and pawns-to-secure carry over, which you dropped,
     and why.
3. Unpause: `show windows.`, close what holds the pause, then `set game speed to normal.` / `fast.` /
   `superfast.`, `mode: raw apply`.
This daily note replaces the older "every 2 game days" handoff file; it is also what the `SessionStart`
compaction hook prints back to you.

---

# Day-by-day reading of REFERENCE_HUMAN_PLAY-Autosave-5.md

Source: VerbalCommands human-play record, colony "New Arrivals", map 250x250, -22C outdoors.
Start: 3 colonists (Zimmerman, Stumpy, Hicklin) + pet Alvin. End of record: day 54, 8 colonists, wealth 55097.
The log only contains the sessions that ended up in the Autosave-5 chain, so days 11-15, 19-23, 26-30, 34-38, 41-45, 48-53 are missing. Wealth deltas across the gaps are the only trace of those days.

Role pattern that holds for the whole record: **Stumpy = builder/hauler/miner/grower** (nearly every build/haul order), **Hicklin = researcher/miner**, **Zimmerman = doctor, cook, warden, social** (tends, cooks, calms, arrests, recruits).

---

## Day 1 - Lay the floor
- Player's very first action is a 16x9 paved-tile floor (x104-119, z122-130), then fills in the gaps hour by hour. The whole base footprint is decided on hour 2 of day 1: one rectangular slab, base will be built on top of it.
- Horseshoes pin at 109,123: recreation source placed before any wall or bed. Player knows mood matters from day 1.
- VF_RoadZone made then deleted at 1h: a Vanilla Furniture Expanded zone tool mis-click, undone immediately.
- Why paving first: -22C map, likely tundra/ice. Paved floor is cheap (stone chunks are free), gives cleanliness and beauty, and removes dirty-floor debuffs later. Also puts the stone chunks lying on the slab to use.

## Day 2 - Chunks out, power in, food scare
- Finishes the slab, hauls the 12 sandstone chunks off the slab into a new 16-cell **Stockpile zone 2** (x101-102) just west of the slab with 5 kinds allowed (chunk types only). The repeated "cancelled Haul" on cells 101-102 are chunks that already sit in that stockpile: the drag-select caught them and the player un-designates them one by one.
- **Simple research bench** at 112,129, inside the slab.
- **Wind turbine** at 104,135 north of the slab, 14 hidden conduits along z131 and a spur down x112 to the bench. Micro-orders Stumpy to haul steel and components to it: player is forcing the turbine through rather than waiting for the job system.
- 22h: **raw fungus x7 hauled urgently** from x51-61, z142-150 (a cave 50+ tiles west) and 210 fungus **unforbidden**. This is a food emergency; nothing grows outdoors at -22C, so the player grabs the only wild food on the map. Hicklin is sent personally.

## Day 3 - Heat, light, second turbine, east wing starts
- **Heater** at 104,130 (slab is being enclosed; needs warmth). Wall lamps along z130.
- Home area cut from 604 to 198 then regrown by hand to ~470: player deletes the auto-expanding home area and redraws only what should be cleaned/firefought. Stops colonists wandering off to clean snow.
- Dozens of "ordered Stumpy: building ..." lines: the player right-click-prioritises Stumpy onto every blueprint. At 16h sets **Stumpy construct 2 -> 1**, i.e. stops micromanaging and makes construction his top job.
- **Hicklin research 3 -> 2** and research target **battery**: power storage so the turbine output is not wasted at night.
- Second **wind turbine** at 104,142 (placed twice; first blueprint got cancelled or blocked). Stumpy equips a revolver: first weapon, likely because wildlife showed up.
- 1h: **steel wall x10 at x120-129, z132** east of the slab. First structural wall of the record, and it is not around the slab but an annex to the east.

## Day 4 - Enclose, partition, pet fence, first ore, first hunt
- Build-roof area and wall orders: the slab is being roofed.
- **Area 1 (280 cells) created and Alvin restricted to it**: the pet was getting in the way or at risk outside, so it gets a pen area.
- **Door at 120,127** on the east edge + **wall lamp and heater at x121**: the east annex becomes a heated room.
- **MineVein at x128-131, z129-131**: compacted steel found right next to the base. The designate/cancel ping-pong that runs through day 5 is the player following the vein as each cell is revealed, cancelling the cells that turn out to be plain rock. Steel is the bottleneck for everything being built.
- **Stockpile zone 3** (18 cells, 84 kinds) south of the slab at z118-120: a general dump for everything that is not chunks.
- 23h-1h: **walls at x108 and x107 with doors at 108,124 and 107,122**: internal partitions. The west strip x104-106 becomes a bedroom wing, the middle becomes workshop/dining.
- 2h: Zimmerman and Stumpy drafted, **attack a snowhare**, butcher spot bill "forever". Hand-hunting because meat is zero and no hunter is assigned; butcher bill set so the kill is processed automatically.

## Day 5 - Beds, hydroponics research, vein chase
- **Battery** at 110,129 and a stool at the research bench (research speed/comfort).
- Research switches to **hydroponics**: the player has concluded outdoor farming is impossible here, so food will come from indoor basins under a sun lamp.
- All day: MineVein chase moves east from x129 to x135. Each hour one or two cells designated, one or two cancelled.
- **Three steel beds** at x104, z124-128: the west wing is now officially the bedroom. Steel beds because there is no wood on the map.
- Hicklin equips a plasteel knife. Wealth +1492 (items +998): the mined steel is landing in stockpile.

## Day 6 - Rescue a stranger, redraw the annex, dig the farm room
- **Wall x9 at z131 (x121-129)** then **deconstruct the day-3 wall at z132**: the east annex is shifted one tile south. Player redesigned the room (possibly to line up with the door at 120,127 and roof limits).
- Zimmerman drafted, **tends then rescues Vicente**: a downed stranger (wanderer/refugee event). Rescue = free recruit chance.
- 168 steel unforbidden, 4 steel hauled urgently from the vein: ore being collected immediately.
- **Two ship chunks designated for deconstruct** (83,70 and 79,55): components. Research moves to **solar panel**.
- Steel table 1x2 + 4 steel stools at 115,129: a dining room, to remove the ate-without-table debuff.
- 23h-1h: **Mine 96+5+7 cells at x121-131, z111-123**: a large room is carved into the rock south-east of the base. Day 9 confirms it is the hydroponics room.

## Day 7 - Kitchen and solar
- Hicklin and Stumpy mine priority raised to 2, Hicklin research to 1: the farm room has to be dug fast while research keeps going.
- Stumpy gathers potatoes (wild or from a drop), **electric stove** at 119,129 with bill "simple meal x4 until 10", Zimmerman forced onto cooking three times: colonists were eating raw fungus/meat and getting the debuff.
- **Two solar generators** north at 106,133 and 106,137, second battery at 114,129. Power is being over-provisioned ahead of the sun lamp, which draws 2900 W.

## Power field layout (final state, from the day-54 screenshot)
The log only records the first two turbines and first two solars; the rest were built in unrecorded days. Final layout north of the base:

```
  north ↑

   [W]   [SSSS]                        [W]       W = wind turbine, vertical, 2 wide x 7 tall
   [W]   [SSSS]                        [W]       S = solar panel, 4x4
   [W]   [SSSS]                        [W]
   [W]   [SSSS]                        [W]
   [W]                                 [W]
   [W]                                 [W]
   [W]                                 [W]
   ------------------------------------------   turbine wind-path boxes run east-west over the field
   [W]   [SSSS]                        [W]
   [W]   [SSSS]                        [W]
   [W]   [SSSS]                        [W]
   [W]   [SSSS]                        [W]
   [W]   [SSSS][SSSS][SSSS]            [W]
   [W]   [SSSS][SSSS][SSSS]            [W]
   [W]   [SSSS][SSSS][SSSS]            [W]
   [W]   [SSSS][SSSS][SSSS]            [W]
  ┌────────────────────────────────────────────┐
  │ bedrooms │ research/dining │ workshop       │  base slab, conduit along its north wall (x104-117, z131)
```

- **Turbines**: 4 total, all rotated vertical (2 wide x 7 tall), two columns. Left column anchors 104,135 and 104,142 (days 2-3). Right column built in a gap. Each turbine's east-west clearance box reaches across the field toward the other column.
- **Solars**: 5 total, 4x4 each, packed between the two columns with **no spacing**. Two stacked flush against the left column (anchors 106,133 and 106,137, day 7). Three in a row along the bottom against the base's north wall (gap days).
- **Why this works**: solar panels do not block wind, so the turbine clearance zone doubles as the solar field. Nothing in the clearance is wasted ground, and the whole power plant fits in one rectangle directly north of the base on the conduit line.
- **Batteries** are not out in the field; all three are inside the slab next to the research bench (110,129; 114,129; 113,128).

## Day 8 - Power build-out, Hicklin gets hurt
- Stumpy hauls and builds battery and solar panels, third battery placed.
- Stockpile zone 2 grows 16 -> 48 cells (more chunks coming from the mine).
- 16h: **all three drafted**, Hicklin moved, then Hicklin tended by Zimmerman. Pawns wealth -185. Something attacked (manhunter animal or small raid); Hicklin took the damage.

## Day 9 - Ishta joins, farm room gets its lamp
- 22 slate chunks and 4 sandstone chunks from the dug room hauled urgently out; again the player cancels the ones already inside stockpile 2.
- 24 conduits into the new room.
- **Ishta appears** (colonists 4 by day end): equips a bolt-action rifle that was lying forbidden. Likely Vicente's recruit or a new join event; Ishta is immediately the ranged fighter.
- Research **Terrain Rehabilitation** (a mod tech), then **sun lamp at 126,116 and 5 hydroponics basins at x123**: the farm room goes live.
- **Ishta medicine Best -> Normal**: player saves the good medicine for emergencies; new colonist does not get glitterworld meds.
- 0h: **Mine 32 cells at x51-56, z113-118**: a second steel vein far west.

## Day 10 - Harvesting a raider
- Stumpy grow priority 2, sent to sow the basins.
- 11h-12h: Hicklin, Stumpy, Ishta drafted; Hicklin melee attacks **Chaffinch**, Ishta **captures Chaffinch**. A single attacker or lone raider, taken alive on purpose.
- Zimmerman equips a poor steel knife, tends Hicklin (hurt again).
- 17h-19h: Zimmerman **"Removing body part" three times on Chaffinch**, Chaffinch medicine set to Normal first so the surgeries do not fail on herbal. The prisoner is being **harvested for organs** (kidney, lung, then the fatal one). Wealth +3194 items that day is consistent with harvested organs plus steel.
- **Stockpile zone 4** (23 cells, 1 kind) at x114-117, z99-105, far south of the base: a single-item dump, most likely corpses, placed away from living space to avoid the mood hit.
- West mine: 17 cells cancelled once steel was found and hauled. 4 more hydroponics basins.

## Days 11-16 - (gap)
- Buildings wealth 7571 -> 13541 over the gap: the base roughly doubled. Colonists still 4.

## Day 17 - Mental break, Psyche joins
- MineVein cancellations at x30-37, z116-120 then Stumpy and Hicklin ordered to **dig compacted steel** there and 11 steel hauled urgently to Stockpile zone 1: another far-west vein, player is cherry-picking only the ore cells.
- Alvin's area toggled unrestricted -> Home -> Area 1 (grown to 476): pet area enlarged.
- Heater at 108,130 (bedroom wing still cold).
- 23h: **Zimmerman calming Stumpy down**: Stumpy is in a mental break. Stumpy has been the single pawn doing all construction, hauling and mining for 17 days.
- New steel bed at 104,123 and **Psyche** given medicine Normal and research/mine priority 2: fifth colonist, bed prepared the hour they arrive.

## Day 18 - Mood management
- Stumpy "spending time alone" at 6h: break still running.
- **Chocolate x4 found far south (65-68, 26-34)**, unforbidden 102 chocolate: a cargo drop pod, grabbed for recreation/food.
- Stumpy ordered onto a **steel art bench**: art for beauty/mood and wealth.
- **Schedule overhaul for everyone**: 0-6 sleep, 6-7 recreation, 7-21 work, 21-22 anything, 22-24 sleep; Psyche gets 6-8 recreation. Direct reaction to Stumpy's break: forced recreation slot every morning.

## Days 19-24 - (gap, player annotation)
- Player annotation in the log: a **15x15 room was mined** (not connected to other rooms), **soil laid inside**, a **lamp with a column** in the middle (column prevents roof collapse over a 15-wide span), and a **growing zone set to fibercorn**. None of this was captured by the recorder: growing-zone creation and plant selection are not logged, and the mine/wall/floodlight orders fell in the unrecorded stretch. Buildings wealth +2226 across the gap is the only trace.
- Player reasoning: wood from fibercorn is renewable, steel on this map is not. Wood goes to furniture and traps and becomes a steady supply. Until Deep Drilling and Ground-Penetrating Scanner are researched, steel is treated as functionally non-renewable and reserved mostly for military gear (flak jacket, bolt-action rifle, assault rifle, SMG).
- This reframes the earlier steel-chasing (days 4-5, 9-10, 17): it was never about building material long-term, it was about securing the finite stock before raids scale with wealth. It also explains the steel furniture in the first bedrooms being the stopgap, with wood planned to take over.

## Day 24 - Second room south, prison politics
- **Walls at x113, z108-113 + doors + heater at 114,113**, old wall at 119,114 swapped for a door: a new room south of the base, connected to the farm room.
- **Koork prisoner mode: convert** (Ideology). A captured raider is being converted rather than recruited.
- 21h: **Zimmerman arrests Ishta**. Colonist count drops 5 -> 4. Then 2h: **Ishta prisoner mode: convert**, Ishta's bolt-action rifle unforbidden for others. Ishta has a different ideology (likely causing mood problems, or the player wants a single-ideo colony); the player imprisons their own colonist to convert them.
- Jade end table in the bedroom at 104,129: bedroom quality upgrade.
- Stockpile 2 grows to 83 cells.

## Day 25 - Ishta breaks out
- 13h: Zimmerman and Hicklin drafted, **melee attack Ishta**, Zimmerman **captures** then **converts** Ishta: Ishta escaped the cell and was beaten back down. Melee, not guns, because they want Ishta alive.
- Player annotation: **Ishta lost an arm in this fight**. That one-armed Ishta is the reason for the day-33 and day-39 Ishta lines below.
- **Hicklin doctor 0 -> 1 and self-tend on**: a second doctor so Zimmerman is not the single point of failure, and so Hicklin can patch himself after fights.
- Ishta medicine downgraded to herbal: no good medicine spent on the prisoner.
- Rice being cut (the basins are producing rice), horseshoes pin moved to 100,115.
- **Three steel shelves placed over Stockpile zone 1 cells** (x113-119, z122-126): converting the floor stockpile to shelves, 3x density.

## Days 26-31 - (gap)

## Day 31 - Prisoners on rations
- New **butcher spot at 116,109** in the south room with a forever bill: butchering moves out of the living area.
- **Food policy Meaty and Koork: Lavish -> Simple**: prisoners were eating fine meals; now get simple. Colonists 5 again (Ishta converted and released, or Koork recruited).

## Day 32 - Healroot, another capture, new room NE
- Stumpy ordered to **sow healroot** nine times: medicine production, the player keeps re-ordering because Stumpy keeps getting pulled off.
- **Bakya** captured, tended, set to convert and simple food: another raider/downed visitor taken as prisoner.
- **Mine 90 cells at x141-146, z136-150**: a new large room north-east.
- Panthera fur hauled: a panther was killed (likely the day-8 type threat).
- 20h-21h: four colonists drafted and moved, undrafted an hour later: a threat that resolved without a fight (or a quick one).
- Research **smithing**.

## Day 33 - Ishta is back, but taken off cooking
- **Ishta drafted/undrafted** at 6h: Ishta is a colonist again (conversion worked), and per the player's annotation this draft/undraft is a **force-cancel of Ishta's cooking job**. Ishta had been assigned cooking after release; with one arm and a go-juice dependency deficiency, manipulation was around 10%, so meals were taking far too long. From here Zimmerman is the only cook, which is why every later cooking line names Zimmerman and why day 47 shows Zimmerman cooking ten hours straight.
- Note: the Work-tab change that removed Ishta from cooking is not in the log (no "set work priorities" line for Ishta); only the job cancel is visible.
- Stockpile zone 1 expanded to 84 cells at x112-126, z145-153: the NE dig becomes the main warehouse.
- **Three heaters at x134-136, z136**: another new room being heated.

## Day 39 - Private bedrooms
- **Psyche "Studying crafting"** ordered ~20 times across days 39-40: Psyche is reading a crafting book/schematic and keeps dropping the job, so the player re-clicks every hour.
- Stumpy **strips then rescues Ishta**: Ishta downed again. With one arm and a go-juice deficiency this is most likely a collapse from the withdrawal/dependency rather than a fight. Clothes removed before carrying to bed, consistent with the parka/sash/T-shirt hauled urgently on day 40.
- Research **autodoor**.
- **Mine 13 cells at x131-135, z127-134**, two steel beds, jade and steel end tables, dressers: a new bedroom block east of the original, one pawn per room. Also a dresser in the old bedroom at 104,122.

## Day 40 - Finishing the bedroom block
- Hicklin repeatedly ordered to dig the sandstone cells of the new block (he keeps leaving).
- Four more beds and end tables, paved floor over the block, **SmoothWall x26** on its walls: bedroom impressiveness push.
- Psyche construct 0 -> 3: a third builder, finally.
- **Jade large sculpture at 104,127** hauled in by Zimmerman: very high beauty in the original bedroom.
- Wall at 129,126 deconstructed and rebuilt: squaring up the block's corner.

## Days 41-46 - (gap)

## Day 46-47 - Steady state, recruiting
- Small paving patches.
- **Arctic wolf slaughtered** and hauled to stockpile 3: a tamed or self-tamed wolf converted to meat and fur.
- Zimmerman forced onto cooking ten hours straight: meal stock ran out (feeding 5 colonists + 3 prisoners).
- Zimmerman **feeds Koork, Meaty, Bakya** then **attempts to recruit Meaty and Bakya**: prisoners have been converted and are now being recruited.

## Days 48-54 - (gap)

## Day 54 - End of record
- **8 colonists**, wealth 55097 (items 21156, buildings 25056, pawns 8885). Three new colonists match the three prisoners (Koork, Meaty, Bakya) being recruited after conversion.

---

## What the player was going after, overall

1. **Survive the cold**: paved slab, heaters in every room, roof, then hydroponics under a sun lamp as the only food source. Fungus and hunting bridged the first week.
2. **Steel is finite, wood is the plan**: every ore vein within reach was chased cell by cell because the map has little steel and no wood. Per the player's day 18-24 annotation, steel is treated as non-renewable until Deep Drilling and Ground-Penetrating Scanner, reserved mostly for military gear, and a 15x15 fibercorn room was dug to make wood the renewable material for furniture and traps.
3. **Dig into the mountain** rather than build outward: farm room (day 6), south room (day 24), NE warehouse (day 32), bedroom block (day 39). Mountain rooms are pre-insulated and cheap.
4. **Mood first**: horseshoes on day 1, dining table, individual bedrooms, art bench, jade furniture, sculpture, enforced recreation schedule after Stumpy's break.
5. **Ideology-driven population growth**: raiders are captured, not killed; converted first (even their own colonist Ishta), then recruited; one (Chaffinch) was harvested instead. Prisoners kept on simple meals and herbal medicine.
6. **Heavy micromanagement of Stumpy** for 17 days, which produced the mental break; after that the player spread work (Hicklin doctor, Psyche construct) and fixed schedules.
