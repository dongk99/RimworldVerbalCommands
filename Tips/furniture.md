# Furniture: where things go and what placement is worth

The mod does not judge a layout. It places what you name where you name it, and for five room types it lays
the furniture out by the game's own rules. The rest is below. Lines marked (source) were looked up by agent
08 in the decompiled game code or the saved wiki pages, with the place named; (mod) is what the mod's own
code does; (unchecked) is neither.

## What the mod does for you (mod)
- `build bedroom AREA.`, `build barracks AREA with 3 beds.`, `build kitchen AREA.`, `build dining room AREA.`,
  `build research room AREA.` build the walls, the door and the furniture in one order:
  - a bed's head stands against a wall, as far from the door as it gets; beds in a barracks are not side by
    side (one cell between, where an end table can stand);
  - an end table, dresser or multi-analyzer goes only where the game's own link test accepts it for its bed
    or bench;
  - a bench, stove or butcher place stands at a wall with its worker spot inside the room and free;
  - a dining table goes to the middle with seats on its free sides, facing it;
  - a torch lamp at a wall;
  - the cell inside the door stays free, and every worker spot, bedside and seat stays reachable from it.
  The plan lines name each piece with its cell, a bed's head end and a bench's worker spot. Read them before
  `apply`. A piece that does not fit is named under "Left out"; a room too small for its bed or bench is
  refused with the reason.
- Anything else you place yourself: `build BUILDING at SPOT facing SIDE.` (exactly that cell) or
  `build BUILDING near SPOT.` (the nearest free cells). The confirm line says where a bed's head is and
  where a bench's worker stands.
- Spots (user, 2026-10-04: "you cant "BUILD" something like animal sleeping spots or bed spots. you have to
  PLACE them." / "Same for butcher spot. expect anything with "SPOT" to be placeable, more or less. If they
  dont, THEN try to BUILD."): anything named "spot" (sleeping spot, animal sleeping spot, butcher spot, ...)
  is placed first; build it only if placing fails. Days 5-17 the mod made the butcher spot as a blueprint a
  builder had to build. Since 2026-10-06: `place BUILDING at SPOT.` / `place COUNT BUILDING near SPOT.` put a
  spot down at once (user: "build sleeping spots need to be blocked with "you can only place them". same for
  other SPOTS"); `build` refuses a spot, and `place` refuses anything that is not one.
- Facing (source: `RimWorld\BedUtility.cs:22-26`, `Verse\ThingUtility.cs:55-87`): a bed `facing north` has
  its head at the SOUTH end, `facing south` at the north end, east = head west, west = head east. A bench
  with the usual work spot `facing north` has its worker on the south side, looking north.
- There is no workshop, hospital, storeroom or rec room type: build `build room AREA.` and place the pieces.
- `show building NAME.` reads back a standing piece; `show blueprints.` what is not built yet and why.

## What a room is worth (source)
- Space (`RimWorld\RoomStatWorker_Space.cs:8-27`): +1.4 for each standable cell, +0.5 for each cell that
  can be walked but not stood on, capped at 350. Furniture eats standable cells: leave walking room.
- Impressiveness (`RoomStatWorker_Impressiveness.cs:8-23`): wealth, beauty, space and cleanliness together,
  65% on their average and 35% on the weakest, and space caps it: a tiny room can not be impressive however
  rich it is.
- Beds, tables, workbenches, lamps and heaters reduce space; stools and chairs do not (wiki, Space).
- Bedroom size (wiki, Bedroom): an inside of 5 by 5 or 4 by 6 is fine for a furnished bedroom, with bed,
  dresser, end table, lamp and plant pot. The sentences take the OUTSIDE: 5 by 5 inside is `7 by 7`.
- What makes a room what it is (`RimWorld\RoomRoleWorker_*.cs`): one bed for people makes a bedroom, two or
  more a barracks; a stove a kitchen; an eating table a dining room; a research bench a laboratory. One bed
  put into a dining room or laboratory turns it into a bedroom (wiki, Room roles), so keep beds out of
  workrooms. More than half medical beds makes a hospital.
- A box of walls is only called "room" until something in it gives it a role; `in ROOM` sentences work
  once it has one (`VocabularyText.cs:212-221`).

## What makes work faster (source)
- Linked furniture (`RimWorld\CompProperties_Facility.cs:13, 25`): a facility links to a bench within 8
  tiles by default. Put it in the same room, within 8 tiles.
  - Tool cabinet (wiki, Tool_cabinet): +6% work speed to a linked workbench; a bench uses at most 2, for 12%.
    One cabinet between two benches serves both (the user's example workshop does this).
  - Multi-analyzer (saved wiki `goal\Multi-analyzer.txt:54, 64`): links to hi-tech research benches only,
    +10% research speed, and Fabrication needs it linked.
  - End table (wiki, End_table): must stand directly next to the head of the bed; a second one does nothing.
    Dresser: a small comfort bonus to nearby beds; one counts.
- Cleanliness and research (saved wiki `goal\Research.txt:83`): x0.75 in a very dirty room, x1.0 clean,
  x1.09 sterile. Floor the research room and keep it clean. (user: the research station's speed depends on
  being indoors, temperature, the room's cleanliness and linked facilities.)
- Light (`RimWorld\StatPart_Glow.cs:12-80`): work is slower in the dark. Light every workroom.
- A kitchen where animals are butchered gets dirty, which makes food poisoning more likely (user): butcher
  in another room when you can.
- Ingredients (`RimWorld\Bill.cs:33`): a bill looks 999 tiles away by default, so a stockpile next to the
  bench only saves walking. It saves a lot: put the stockpile for a bench's ingredients beside it.
- Food (`Verse\GenTemperature.cs:459-470`): rot stops below 0 C and runs at full rate from 10 C: a freezer
  below 0 C keeps food for good.

## Storage: keep things under a roof (user)
- (user, live game 2026-10-04: "putting certain things outdoor degrades them! youre lucky it wasnt
  raining/snowing.") A stockpile under open sky wears its contents down, and faster in rain or snow.
- (user, 2026-10-04, two game days later with the zone still unroofed: "many items degrade VERY FAST when
  outdoors.") Do not wait: an outdoor stockpile is a fault to fix the same day, before building anything
  else. Ordering a roof is not enough; check with the roof map that it was built.
- What suffers (unchecked, from memory of the game): components, medicine, clothes, weapons, cloth and
  leather, wood slowly, meals. What does not: steel, silver, stone blocks, rock chunks.
- So: the first general stockpile goes indoors or at least under a roof. Outdoors keep only metal and stone.
- Through the mod: `show roof map around SPOT.` shows whether a zone is under open sky;
  `area roof add 115, 119 to 118, 124.` has colonists roof it (each cell needs a wall within 6 tiles);
  better, give the delicate things an indoor zone: `put medicine in zone Stockpile zone 1.` and a higher
  priority there: `set zone Stockpile zone 1 to important priority.`
- `show storage of zone NAME.` says what a zone holds; it does not say whether it is roofed or what is
  wearing down.

## The way to Fabrication (source: saved wiki pages in `agent_player\wiki\goal\`)
Electricity (simple research bench) -> Microelectronics (hi-tech research bench, needs power) ->
Multi-analyzer -> Fabrication (hi-tech bench with a multi-analyzer linked within 8 tiles) -> fabrication
bench (steel 200, components 12, advanced components 2). `show research path to fabrication.` gives what is
still open.

## Research through the mod (mod)
- `show research.` : the current project with its progress and what it gives, and the projects that can be
  started now.
- `show research path to PROJECT.` : every unfinished project on the way, in order, each with its points,
  the bench it needs (and whether you have one), the facilities, techprints, what it comes after, whether it
  can start now, `unlocks:` (the buildings, products, plants, floors and operations it gives) and `opens:`
  (the projects that need it). Asked about a finished project it says what that one gave.
- `start research PROJECT.` sets it; a colonist with Research work does it at the bench:
  `set Research priority 1 for NAME.`
- There is no list of every project with its unlocks in one answer: ask project by project.

## Not known to the mod or to this file
- The mood numbers for bedroom against barracks, and for room impressiveness (they are in the game's data
  files, which were not read).
- How far a tool cabinet or a dresser reaches exactly (their own data may differ from the 8-tile default).
- No question shows a room's space, beauty or impressiveness. `show mood of NAME.` shows the thought a room
  gives once someone sleeps or eats in it.

## Walls that do nothing are wasted material (user)
- (user, live game 2026-10-04, day 7: "you have your wooden wall being wasted and you dont have a lot of
  wood.") On a map without trees every wall that closes nothing is wood standing idle: take it down
  (`deconstruct`) and use the wood. Look at the buildings map for such walls before spending any wood.
