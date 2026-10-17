# drafter_mover notes

## Call 1, round 1: day 1, 7h, -22C, clear (2026-10-16)
- Sent (all raw questions, nothing changed): `show status.` (o21), `show threats.` (o28), `show colonists.` (o34), `show health of Stumpy.` (o45), `show health of Zimmerman.` (o51), `show health of Hicklin.` (o57).
- Answers: no threats, no alerts, no letters. Nobody drafted (colonists show work jobs only).
- Positions at 7h, all outdoors: Zimmerman 125,133 (hauling steel to stockpile zone 1); Stumpy 119,132 (hauling steel to wall blueprint, then building); Hicklin 126,139 (hauling steel to stockpile zone 1).
- Health: Zimmerman "Hypothermia (shivering) 4% of lethal", Hicklin "5% of lethal", Stumpy none. Zimmerman and Stumpy also have Cryptosleep sickness (3-4h left), which is why `show status.` lists them as sick.
- Brief's 30% threshold read as "% of lethal" on the `show health` line (assumption, check on the next round).
- No indoor move now: the room (104,122 to 113,128) is not roofed, so its cells are at outdoor temperature. The geyser heats only when sealed. Re-check each round.
- Standing direction overrides the brief: undraft on arrival (not one hour later).
- Wait: 2 game hours (not the brief's 4) because hypothermia climbs about 5% per outdoor hour.
- Refusals or gaps: none. Interpreter answers were complete; `show health of X.` gives the hypothermia % directly.

## Call 1, round 2: day 1, 9h to 12h (2026-10-16)
- 9h: Zimmerman and Hicklin "wandering" (idle) outdoors; Stumpy building the roof. Hypothermia 16% of lethal on both (up from 4% and 5% at 7h, about 4% per hour).
- 11h: `show temperature.` gives position and room temperature. Room (108,125 area) -3C, then 16C once the room counted as "barracks" (sealed); Hicklin at 117,126 outside at -15C. Blueprints: beds and a research bench still unbuilt (not mine).
- Drafted Hicklin (o145), moved to 110,125 (o149). Then `show colonists.` said "watching for targets, drafted" while he was still outside, and I undrafted him at 115,123 (o158, applied). MY MISTAKE: `show colonists.` does not show arrival; the undraft cancelled the walk. Rule now: confirm the cell with `show temperature.` (position) before any undraft.
- Redrafted (o164), moved again (o167), position confirmed at 110,126 (room "barracks" 16C), undrafted (o172 failed: "None of them is drafted", the draft had already dropped on arrival; no action needed).
- Result at 12h: Hicklin hypothermia 7% of lethal, back on hauling steel to the bed blueprint. Zimmerman and Stumpy inside at 16C.
- Refusals: none. Note: `undraft` after a completed move fails with "None of them is drafted"; that is a no-op, not an error.
- Wait: 2 game hours again (hypothermia 16% in the outdoor pawns at 10h).

## Call 1, round 3: day 1, 15h (2026-10-16)
- Sent (all raw questions, nothing changed): `show temperature.` (o222), `show threats.` (o224), `show colonists.` (o225), `show health of Zimmerman.` (o226).
- Threats: none. Nobody drafted.
- Zimmerman and Hicklin "wandering" (idle) in the barracks; Stumpy eating. Hicklin's health not checked this round (last 7% at 12h).
- Zimmerman hypothermia 4% of lethal (16% at 10h, 4% at 7h peak trend down inside).
- FLAG for orchestrator: barracks at 41C with the geyser. Safe maxima: Zimmerman 39C, Stumpy 40C, Hicklin 40C. Not a drafter action; a heater, cooler or vent is a build (gated).
- Wait: 2 game hours.

## Call 1, round 4: day 1, 18h to 19h (2026-10-16)
- 18h: `show temperature.` (o257): outdoor -11C; barracks 23C (1 room with open roof follows outdoors); Zimmerman at 113,131 outside (-11C), Stumpy 117,127 outside (-11C), Hicklin 111,123 inside. `show colonists.` (o260): Zimmerman wandering, Stumpy building roof, Hicklin equipping knife. No threats (o261).
- Health at 18h: Zimmerman 10% of lethal, Stumpy 9%, Hicklin 5%.
- Drafted Zimmerman (o270), moved to 110,125 (o271). 19h `show temperature.` (o274): Zimmerman at 109,125 inside barracks (30C). Undrafted (o278, applied, "drafted: none" confirmed).
- 19h `show colonists.` (o281): nobody drafted. Zimmerman and Stumpy wandering (idle), Hicklin researching. Stumpy idle outside at 121,126 at -12C (not mine: work priority).
- Stumpy's roof build at 121,126 area: the room at 116,126 is at -5C (open roof).
- Lesson: `show temperature.` shows positions, so arrival check = position within about 2 tiles of the spot. Wait between draft/move/undraft rounds only as needed.
- Wait: 2 game hours.

## Call 1, round 5: day 1, 21h to 23h (2026-10-16)
- 22h: `show temperature.` (o302): outdoor -16C; "Hicklin's barracks" 47C with Hicklin sleeping inside (107,127); room 116,126 at 0C; Zimmerman outside at 107,129 (-16C) wandering; Stumpy 118,129 in the 0C room, hypothermia shivering. `show colonists.` (o303): Zimmerman wandering, Stumpy resting, Hicklin sleeping. No threats (o304).
- Health 22h: Hicklin 100%, no hediffs (no heatstroke yet). Zimmerman 100%, no hediffs. Stumpy hypothermia 10%.
- Drafted Zimmerman and Hicklin in one order (o311, "draft Zimmerman, Hicklin.", applied, both). Moved both to 116,126 (o314, applied). Zimmerman's walk went around the outside (121,128 at -18C) before reaching 116,126 (o319 at 23h: Zimmerman at 116,126, 0C, hypothermia shivering).
- Undrafted both (o322, applied, "drafted: none" confirmed).
- Plural orders work: "draft X, Y." and "move X, Y to P." and "undraft X, Y." all applied with one order each.
- Flag for orchestrator: barracks 36-47C from the geyser; Stumpy went there on his own (40C at 23h). Beds in a 40C+ room is a build/heat question (gated), not mine.
- Wait: 2 game hours.
