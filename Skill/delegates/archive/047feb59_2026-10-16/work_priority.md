# work_priority notes

## Round 1 (call 1), day 1 7h
Observed: `show status.` (6h), `show work.`, `show colonists.`, `show alerts.`.
- Manual priorities are ON in the game's Work tab (1-4 accepted).
- Before: Construct Stumpy 3, Zimmerman off, Hicklin off. Grow: Stumpy 3 only. Haul: all 3.
- Colonists at 6h: Zimmerman and Hicklin hauling steel to stockpile zone 1; Stumpy building the steel door.
- Alerts: need warm clothes (all three), need colonist beds, need research bench.
Orders (raw apply):
- `set Construct priority 1 for Stumpy.` -> applied, done (Stumpy 3 -> 1).
- `set Haul priority 2 for Hicklin, Zimmerman.` -> applied, both done (Hicklin 3 -> 2, Zimmerman 3 -> 2).
- `show work.` after: Construct Stumpy 1, Zimmerman -, Hicklin -; Haul Zimmerman 2, Hicklin 2, Stumpy 3.
Learned:
- Worktype word that works: `Construct` and `Haul` (the plain Haul row). The `Haul+` row is a separate worktype; it stays at 3 for all three.
- Multi-pawn form `for Hicklin, Zimmerman.` works in one sentence.
- Steel reaches the stockpile first; getting it to the blueprint is the construction job's haul, not a worktype of mine.

## Round 2 (call 1), day 1 13h-16h
Observed: `show status.` (13h), `show colonists.`, `show alerts.`, `show questions for show.` (question list), `show blueprints.`, `show designations.`, `show pending.`, `show areas.`, `show temperature.`, `show roof map around 108, 125.`.
- At 13h: all three colonists hypothermia; Zimmerman wandering; Stumpy and Hicklin digging compacted steel at 129,129 outdoors (designation: mining 2 marked around 130,130, from the expediter's `mine near`).
- Blueprints left: bed frame 0%, simple research bench frame 28%. No wall blueprints.
- Roof map (16h): built roof over 104-113 x 122-128 (the whole shelter). Barracks enclosed at 36C. Shelter walled and roofed: the condition for the "after" phase is met.
- Alerts: need warm clothes (all three), need colonist beds, need research bench.
- Temperature at 15h: Zimmerman 36C indoors, Hicklin 36C indoors, both still hypothermia (shivering); Stumpy outdoors -10C, hypothermia. Expediter reported "task finished, pawns coming back" (40 steel, 4 medicine, meals).
Orders (raw apply):
- `set Doctor priority 1 for Zimmerman.` -> applied, done (Zimmerman 3 -> 1).
- `set Research priority 1 for Hicklin.` -> applied, done (Hicklin 3 -> 1).
- `set Haul priority 3 for Hicklin, Zimmerman.` -> applied, both done (both 2 -> 3). Hauling back to 3 because the shelter is now walled and roofed.
- `show work.` after: Doctor Zimmerman 1; Research Hicklin 1; Haul 3 for both; Construct Stumpy 1 only; Grow Stumpy 3 only; Hunt and Cook Zimmerman 3 (unchanged, no number given).
Watch:
- Stumpy and Hicklin dig outdoors at -10C while hypothermic; Mine 3 is on for both (not mine to change; the expediter's designation). Flag to orchestrator.
- Zimmerman Hunt 3 and Cook 3 are on; the day plan says "hunting and cooking" with no number. Ask orchestrator for a number if they want it raised.
Learned:
- The orchestrator's "walls or roof waiting" condition ended between 7h and 13h; no further change to Haul priorities without a note.
- `show roof map around X, Y.` reads roof per cell (r built roof, t thin rock roof, ? under fog).

## Round 3 (call 1), day 1 22h-23h
Observed: `show status.` (22h), `show work.`, `show alerts.` (23h).
- Work priorities unchanged since round 2 (Doctor Zimmerman 1, Research Hicklin 1, Construct Stumpy 1, Haul 3 for H and Z). Nothing changed.
- 22h: Zimmerman and Hicklin are DRAFTED ("watching for targets"); Zimmerman food 24%, rest 28%; Hicklin food 46%, rest 37%. Stumpy sleeping, food 51%, hypothermia. Outdoor -18C.
- Alerts (23h): only "need warm clothes" (Zimmerman, Stumpy, Hicklin). Beds and research bench alerts are gone.
- Not my area (drafter_mover): drafted pawns do not eat or sleep (MEMORY: draft-holds-needs). Flag to orchestrator.

## Round 4 (call 1), day 2 1h: orchestrator MESSAGE
Message (day 2 0h): orchestrator set Hicklin Construction 1 TEMPORARILY to deconstruct the inner steel door 113,125 (barracks hit 49C; merging with the storeroom). Do not touch it; orchestrator turns it off. Stumpy stays the only builder.
Done: message file read and deleted. `show work.` at 1h: Construct Stumpy 1, Hicklin 1 (orchestrator's); Research Hicklin 1; Doctor Zimmerman 1; Haul 3 both. Nothing changed by me.
Rule for me: Hicklin Construct stays as the orchestrator set it until the orchestrator turns it off. Do not touch.
