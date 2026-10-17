# storage_zones notes

## Round 1 (call 047feb59), day 0 8h, cadence 12h
Orders sent (all questions, nothing changed):
- `show status.`, `show zones.`, `show areas.`, `show food.`, `show alerts.` → answers read.
- `show storage of zone 1.` → refused: "'1' is not a zone on the map". Use the full name.
- `show storage of zone Stockpile zone 1.` → answer: 35 cells at 115,123 to 119,129; priority normal; allows
  Foods, Manufactured, Raw resources, Items (part), Weapons, Apparel, Buildings; not Chunks, Plants, Corpses;
  holds steel 310, wood 240, sandstone chunk 7 (16 of 35 cells used).
- `show places that store meals / medicine / meat / components / potatoes.` → only Stockpile zone 1.
- `show places that store corpses.` → "No storage on the map accepts corpses." No corpses reported loose.
- `show questions for storage.` / `show questions for roof.` → no such question sentences.
- `show rooms.` → refused ("I do not know how to do that").

What I learned:
- Food loose on the ground, not in storage: 57 packaged survival meals, 10 potatoes (`show food.`).
  Zone 1 accepts both; colonists have not hauled them yet (they are on steel).
- Zone 1 says "not: Chunks" but holds a sandstone chunk. Unexplained; do not trust either side until checked.
- Roof: `show areas.` says Build roof 0 cells. The shelter (104,122 to 113,128) is NOT confirmed roofed.
  The indoor stockpile proposal waits for that.
- No medicine, components or corpses loose on the map.

Pending (orchestrator direction, day 1): superseded in round 2 (orchestrator made the indoor zone itself).

## Round 2 (msg from orchestrator, day 0 11h): indoor Stockpile zone 2 made by the orchestrator
Zone 2 = 105,123 to 107,124 (6 cells, inside the shelter, critical priority). `show zones.` gave the name.
Orders (raw apply) and results:
- `put only meals and medicine in storage zone Stockpile zone 2.` → refused "I do not know how to do that"
  (the `and` form is not read). Nothing changed.
- `put only meals in storage zone Stockpile zone 2.` → refused (the `storage zone` phrase is not read).
- `put only meals in zone Stockpile zone 2.` → applied (filter cleared, meals only).
- `put medicine in zone Stockpile zone 2.` → applied (medicine allowed).
- `keep meals out of zone Stockpile zone 1.` → applied.
- `keep medicine out of zone Stockpile zone 1.` → applied.
Checks: `show places that store meals.` and `... medicine.` now list only Stockpile zone 2. `show places that
store potatoes.` still lists only zone 1 (zone 2 refuses raw food).
Watch: `show storage of zone Stockpile zone 2.` still prints the old "allows: Foods (some: ... Raw food ...)"
line after the change, though the potatoes check is clean. Ask again if in doubt.
Wording that works: `put only X in zone NAME.` / `put X in zone NAME.` / `keep X out of zone NAME.`
Zone 2 holds packaged survival meal 47 and medicine 25 (6 of 6 cells used) at the time of the check.
Open: the 3 bed cells are not known to me; zone 2 (105-107, 123-124) must stay clear of them.

## Round 3 (msg from orchestrator, day 0 17h): zone 3 and the zone 1 storeroom
Orchestrator made Stockpile zone 3 = 100,122 to 102,128 (21 cells, outdoor, normal) and is walling zone 1 into
a storeroom (walls 113-120, 122-130, door 120,126).
- `put only stone chunks in zone Stockpile zone 3.` → applied (filter cleared, chunks only).
- `keep stone chunks out of zone Stockpile zone 1.` → applied.
Checks: `show places that store stone chunks.` → only Stockpile zone 3 (only stone chunks).
`show zones.` at 17h: zone 1 18 stacks, zone 2 6 stacks, zone 3 4 stacks (chunks part).
Note: the 7 sandstone chunks that were in zone 1 are not moved by me; say if you want `move chunks.` (free class).
