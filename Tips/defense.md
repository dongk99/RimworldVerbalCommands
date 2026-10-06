# Defense: walls, a killbox, cover

The mod has no idea of cover, line of sight, weapon range or where a raid will walk. It can build what you
name at the cells you name, put drafted colonists on the cells you name, and tell you where the enemy is.
So the plan below has to come from you.

## The idea (user)
1. **Run a wall around the colony.**
2. **Leave one way in: the killbox.** Its entrance has no door: it is an open gap, the one easy path in.
   The raiders' pathing is dumb: it takes the open path instead of breaking the wall.
3. **Make the way in long, not a maze.** A real maze does not work: they just pathfind out of it. A long
   winding corridor (switchbacks) works: every tile of it is time for you to draft and get into position.
4. **Defend at the chokepoint,** where the corridor ends: they come out a few at a time into the open, your
   colonists stand behind cover and shoot.
5. **Cover only counts when it is between the pawn and the shooter.** Many objects and furniture give cover,
   and stone chunks do too, but only if the wall or the object is in front of the pawn, not behind it.
6. **Stone chunks also slow pawns down.** A corridor filled with chunks is the poor colony's trap corridor,
   when you can not afford traps yet.

## The picture: `killbox_example.jpg` (the user's own killbox; what can be seen in it)
- Left: three or four long parallel walls make a switchback corridor, one tile wide, several times the
  length of the box. Small devices line the corridor walls (traps).
- The corridor comes out at the bottom, into a wide open floor.
- Facing that opening: lines of sandbags and barricades with standing places behind them, and blocks of
  turrets (two blocks of four and six) set back at the sides, behind walls on their far side.
- The defenders' side is roofed and lit; the open floor in front of them has nothing to hide behind.
- Top: power generation sits behind the firing line, inside the wall.

## Building it through the mod (mod)
Read the ground first: `show terrain map around SPOT.`, `show buildings map of AREA.`, `list mountains on
map.` (a rock face is free wall). Then, with your own coordinates:
- Perimeter and corridor walls: `build wall made of granite blocks from 100, 80 to 100, 110.` One straight
  line per order; a corner is two orders. Leave the gap by ending a line one cell short.
- Sandbags or barricades for the firing line: `build sandbags from 120, 90 to 128, 90.`
- A turret, a trap, a lamp: `build mini-turret at 124, 86.` Only what is on the `buildings` vocabulary line
  can be built; `show research path to PROJECT.` says what unlocks the rest.
- Chunks in the corridor: `zone dumping in area 101, 81 to 101, 109.` makes a dumping stockpile over the
  corridor cells; colonists haul chunks there (`haul stone chunks.` marks loose ones). (unchecked: that one
  dumping cell holds one chunk and that haulers fill every cell.)
- No roof is needed on the corridor. The firing side roofs itself only if it is a closed box.
- Check the work: `show blueprints.`, `show pending.`

## When the raid letter comes
1. `show threats.`: each group's nearest member, the box round the group, weapons, how far from home.
2. `draft everyone.` (or the fighters), then one `move NAME to X, Z.` per colonist onto the cell behind the
   sandbag or wall corner you built. The mod will not pick the cell and does not know which side is safe:
   put the cover between the colonist and the corridor exit.
3. `attack nearest enemy with everyone.` once they come out, or name one: `attack raider 3 with Alice.`
4. `run 1 hours.` in short steps and `show threats.` between them; a run pauses by itself on a new threat
   letter, a colonist down, bleeding or dead.
5. After: `rescue NAME.`, `tend NAME with DOER.`, `capture raider 2.` (downed ones), `undraft everyone.`,
   `show status.`

## Raids that do not walk into the killbox (user)
- **Siege.** They do not come to you: they camp and throw mortar shells at your colonists. Inside a mountain
  you are safe from the shells. The catch: most of your power generation will not be inside the mountain,
  so it is what gets hit. What the mod shows: `show threats.` lists hostile buildings (the siege camp's
  sandbags and mortars) with where they are. Either keep everyone under the mountain and repair after, or
  go out and break the camp: `attack ...` from your own cover, since the killbox is no use against a camp.
- **Breachers.** They actively go around your defenses and break through the wall at its weakest spot. The
  open gap does not pull them in. So: no thin or weak stretch of wall, a second position behind the wall,
  and watch where the group heads (`show threats.` between short runs) to move your colonists there before
  the wall goes.
- Drop pods land inside the wall (unchecked). Keep a fallback position.

## What you can not get from the mod yet
- Which cells give cover and how much; whether a cell can see or shoot another; weapon ranges.
- The path a raid will take, which kind of raid it is (walk-in, siege, breachers), or which stretch of wall
  is the weakest.
- A single order that builds a killbox. Lay it out line by line, and keep your own note of its cells.

## Where NOT to fight (user)
- (user, live game 2026-10-04, day 14: "you fought that guy infront of wind turbine and you nearly managed
  to blow up both turbine. try not to do that next time.") A raider goes for what stands outside. Meet
  him before he reaches the turbines, batteries or anything that burns or explodes, and never place the
  shooters so that their line of fire passes over them. Send the melee fighter too (user: "why not send
  stumpy? stumpy is melee") - a lone archer is what a knife and a flak vest are for.
- Through the mod: `attack nearest enemy with NAMES.` is refused from indoors ("Cannot hit target");
  `move NAME to X, Z.` outside first, then attack. A raid's "beginning their assault" message does not
  pause a run: while a raider waits on the map, run one hour at a time and read `show events.`

## A hungry predator, and how the door fight went wrong (live game, day 15)
- (user: "hungry predators can chase colonists for food. And there is no food source outside the map.")
  A predator with no prey on the map comes for the colonists. `show wildlife.` says "predator"; when it
  hangs about the base, expect the letter "X hunting NAME". Walls round the yard would let people move
  between buildings without meeting it (user: "maybe should have built walls around your inner
  courtyard").
- What I did wrong: `move Stumpy to 113, 125.` (the door cell) put him at 114, 125, OUTSIDE the door; it
  closed; the two shooters inside got "Cannot hit target" and he fought a polar bear alone until downed.
  Then at one tile the guns got "Too close". An allowed-area rectangle named `indoors` also covered the
  open ground between the buildings, so "indoors" was not indoors.
- What works through the mod:
  - Shooters stand OUTSIDE, 3 to 6 tiles from where the animal will be, with a clear line; the melee
    fighter between them and it. Check each `move` result line for the cell actually reached.
  - Drafted pawns "watching for targets" did not open fire by themselves in two fights. Give the order:
    `attack nearest enemy with NAMES.`; and when the animal has downed its prey it is no longer listed as
    an enemy ("no enemy is in view"): then `use option Fire on X, Z with NAME.` on the animal's cell.
  - A run stops at every threat letter: orders and one-hour runs alternate within seconds of game time.
  - After the fight: undraft first (a drafted pawn is offered only "Go here"), then
    `use option rescue on X, Z with NAME.` and `use option tend on X, Z with NAME.` on the bed's cell.
