# Routine: the daily survey (what the base holds, what the map holds)

(user, live game 2026-10-04, day 8: "you should write a ROUTINE on what kind of stockpiles are currently
in base, what resources are scattered throughout map (like food, or animal, or resources).")

`show status.` does not show any of this. Run the survey every game morning at 06:00, and again before
any order that spends a material. Write the answers into the play log under "Survey". All sentences below
were sent to the live game on day 8 and answered.

## 1. What the base holds (one order, all questions)
```
show zones.
show storage of zone Stockpile zone 1.     (one line per stockpile that show zones names)
how much wood do I have.
how much steel do I have.
how much components do I have.
show food.
```
- `show zones.` : every zone with place, priority, what it accepts and how many stacks are in it.
- `show storage of zone NAME.` : what it allows, what it does not, what is in it, cells used. A zone with
  all cells used means things are left lying outside: make room or a new zone.
- `how much THINGS do I have.` : the game's own count (in storage, not spoiled). Ask it for every material
  the next build needs. A number that fell since yesterday with no build to explain it has a cause to
  find (day 8: wood went 41 to 4 because the campfire burns it).
- `show food.` : meals, raw food, days of food, crops with days to harvest, what rots first.
  Read the brackets: "(1 in storage, 1 loose, 3 carried)". **Loose** food is lying somewhere on the map,
  outside every stockpile: find it and have it fetched the same day. (user, day 8: "sending zimmerman to
  pick up 1 packaged meal i found on map" - the answer had said "1 loose" for a day and I had not acted.)

## 2. What the map holds (one order, all questions)
```
show resources map.
show wildlife.
show interactable pawns.
where are ship chunks.
where is nearest steel.
where is nearest compacted machinery.
where is nearest tree.
where are berries.
show designations.
```
- `show resources map.` : the whole map, 1 character = 10 by 10 cells: s steel ore, m compacted machinery
  (components), $ silver, j jade, C ship chunk (steel and components when deconstructed), ^ steam geyser,
  b harvestable plant, i items, ? fog. `show resources map around X, Z.` gives 41 by 41 cells in detail.
- `where are items.` names only the first 10 of them; on this map nearly all "i" are rock chunks.
- `show wildlife.` : animals by kind with the nearest cell and whether hunting is safe. "No wild animals
  in view" means no meat until new ones wander in: ask again every morning.
- `show interactable pawns.` : travelers, visitors, traders, downed strangers, with what can be done with
  each. Ask it at once whenever an event names a person; they leave within hours.
- `show designations.` : what is marked and whether anyone works on it.
- Not askable: `where are corpses.` (refused); the list it offers is steel, compacted machinery, ore, rock,
  ship chunk, geyser, trees, berries, rich soil, water, animals, hostiles, items.

## 3. The colonists (one order)
```
show needs of NAME.      (each colonist: Recreation, Comfort, Food, Sleep)
show temperature.
show power.
```

## What to do with the answers
- Food under 3 days: every animal on the map is hunted that day; every passer-by is looked at for trade.
- A material under what the next build needs: mine or fetch it before placing the blueprint.
- Something in a zone that is under open sky: move it the same day (`furniture.md`, storage).
- A resource far out (ship chunk, loose steel): one trip by one colonist set to `anywhere`, back to the
  warm area afterwards.

## A bait shelf for meat (user)
- (user, live game 2026-10-04, day 11: "if you put a shelve (so there is no deteoriation debuff), starving
  wild animals come there to try to eat from it. rudimentary trap if you can figure out a way to see if
  theres animal and autohunt. Thats how i survived." The user played this same map, Shivalbard, and got
  through without eating corpses.)
- How through the mod (not tried yet): a shelf outdoors near the base with some food on it; after every
  run `show wildlife.`; when an animal is named near the shelf, `hunt KIND.` at once with the shooter set
  to `anywhere`. A run does not stop for a wild animal arriving, so keep runs short while bait is out.
  Predators (`show wildlife.` says "may attack the hunter") are not for one rifle.
