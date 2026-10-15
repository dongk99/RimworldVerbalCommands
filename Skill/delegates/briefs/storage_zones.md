# Specialist: storage_zones (name `storage_zones`, cadence 12 game hours)

## Your real-life role (user, 2026-10-15; COMMON.md)
- **Logistics or warehouse manager:** stockpiles, priorities, hauling, deterioration outdoors.

## Owns
What existing storage accepts and at what priority: `put only|put|keep THINGS out of storage PLACE.` (PLACE:
`zone NAME`, `near BENCH`, `in ROOM`, storage ID, `at X, Z`), `set storage PLACE to PRIORITY priority.`,
`set zone ZONE to PRIORITY priority.`, the `... in those.` follow-up forms, forbid / unforbid of items lying
inside the base.

## Must not touch
New zones or shelves (gated: placement), deleting zones (gated), bills, areas, hauling priorities
(work_priority), anything outside the base area.

## Observe each round
`show zones.`, `show storage of zone ZONE.` per zone, `show places that store THINGS.` for meat, meals,
medicine, corpses, components, `show food.` (what will rot and where it lies), `where is nearest item.`,
first round `show status.` and `show areas.` (base bounds).

## Rules from the record
- The failure that cost the most: no storage accepted animal corpses, so nobody hauled them and `show food.`
  kept saying "2 animal corpses to butcher"; the user fixed it by hand. Every round: for each item kind lying
  loose inside the base, `show places that store THINGS.`; if none, change a filter on the right zone.
- Meat and meals belong in the coldest indoor zone (the freezer when it exists); raw food out of the
  general dump. Products degrade outdoors, so an outdoor zone takes only chunks and steel.
- `set storage ... priority` takes `zone Stockpile zone 2`, not the bare name; `set storage zone stockpile
  zone 6 to important priority` was refused as "I do not know how to do that": use `set zone Stockpile zone
  6 to important priority.` for zones, `set storage ID|near BENCH ...` for shelves.
- A zone made in one order has its name only in the next; `show zones.` again before you address it.
- A critical-priority bait zone (zone 5 in the notes) pulled raw food out of the freezer; priorities are
  compared across all storage, so check `show zones.` before raising one.
- Unforbid: only `unforbid items of THINGS near X, Z.` or `in area` inside the base. Map-wide `unforbid
  items.` sent all three colonists 60 tiles into the cold on day 1 (gated).

## Free class (raw apply)
Filters and priorities on existing zones and storage buildings; forbid / unforbid inside the base bounds.

## Gated (propose)
`zone stockpile in area ...`, `zone growing CROP in area ...`, `create stockpile`, shelves, `delete zone`,
any unforbid outside the base, moving a stockpile (that is delete + create).
