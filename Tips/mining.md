# Mining and digging in

## Where to live (user)
The user settles next to a mountain and digs the base into its foot: the rock is free wall and the mountain
is the roof. You choose the place; the mod never picks it.

## Finding rock and ore (mod)
- `list mountains on map.`: each mountain's nearest rock face, its span, how much is overhead mountain, the
  ore in view.
- `show roof map around SPOT.`: open sky, built roof, thin rock roof, overhead mountain.
- `show resources map.`, `where is nearest steel.`, `where is nearest compacted machinery.`
- Only what is in view counts. Rock behind the face is under fog until you dig to it.

## Digging
- A room: `dig room 9 by 7 around 50, 60 door east.` Rock inside is marked for mining, rock at the edge
  stays as wall, open edge cells get wall blueprints, one door. Furnish it afterwards with build lines.
- Clearing rock: `mine everything in area 40, 50 to 52, 60.` At most 500 cells in one order.
- Ore: `mine nearest steel near Bob.` takes the whole vein, but only as far as you can see it (user: you
  can not give a mine order for a vein you can not see). Ask again when more of it shows.
- Someone has to do it: `set Mining priority 1 for Carl.`; watch with `show designations.`, `show pending.`

## Columns (user; the numbers are from the game's code)
- A roof falls in where no wall or rock stands within about 6 cells of it. Under a mountain that kills.
- So a very large dug area needs columns. The mod leaves them by itself: any `dig room` or `mine ... in
  area` more than 12 cells both ways keeps one rock cell every 9 cells, the first 7 in from the edge. The
  plan notes say where.
- Do not mine the columns out later. If you want a wide hall, keep the columns or build walls inside first.
- The mod can only leave a column where rock stands. Where the grid cell is already open, the plan notes
  warn that cells are unsupported: build a wall cell there (`build wall at X, Z.`) before digging round it.
- Narrow is safe: anything up to 12 cells wide needs no column however long it is.

## Sieges (user)
Inside a mountain you are safe from siege mortars. Most power generation can not go inside a mountain, so
plan for it being hit: keep it apart from anything that burns, and be ready to repair.

## Things to expect (unchecked)
- Deep under a mountain, insects can appear. Fresh rooms under overhead mountain are where.
- Mining leaves stone chunks: haul them to a dumping zone, or use them in the killbox corridor
  (`defense.md`). A bill at a stonecutter's table turns them into stone blocks, for walls that do not burn.
- Compacted machinery gives components, one of the few early ways to get them.

## Ice or permanent-winter maps: the user's plan, and the numbers (user)
The user's Shivalbard run, from the same start as the agent's run:
- dug the base into the mountain from day 1;
- baited wild animals with food on a shelf (see `routine.md`);
- went for hydroponics basins as soon as it could; built nothing outside, since most of the ground is
  ice and crops on it give little.
Wealth from day 0 to day 17: the user's run went $13,823 -> $23,467 (+$573/day); the agent's run
(surface buildings, a greenhouse on soil, outdoor turbines) went $13,719 -> $16,682 (+$174/day).
On such a map, plan the mountain base and hydroponics first, not surface buildings and soil farms.
