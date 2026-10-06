# Power: nets, excess, batteries

## What you can ask (mod)
- `show power.` answers per power net (a net = everything joined by conduits):
  - made and used, in W, and the difference: `net +350 W, which is +350 Wd per day` (the excess, or the loss
    when it is negative);
  - batteries: `Stored 420 of 1200 Wd (35%)`;
  - when the net is losing power: `Batteries last about 9 hours at this draw` (it counts the 5 W every
    charged battery loses by itself);
  - `No battery on this net and it is losing power`, `Batteries are empty and the net is losing power`;
  - what is switched off, what is not getting power, and what is on no net at all, each with its place.
- `show status.` has the one-line version: nets, made, used, stored of capacity, buildings without power.
- `show building NAME.` : one building: on or off, its power, fuel.
- Units: W is the rate now. Wd (watt-days) is stored energy: 1 W for one game day. A net at +100 W fills a
  battery by 100 Wd per day.

## Battery events (mod)
While the game runs, the mod writes an event line each time the batteries of a power net fall below 90%, 75%,
50%, 35%, 20% and 10%: `power: Batteries of the power net with the battery at 118, 90 fell below 50%: 600 of
1200 Wd, net -210 W, about 6 hours left.` Each net is watched by itself (a colony can have separate grids),
and a net that charged back up gives the line again the next time it falls. The lines are in `show events.`;
they do not pause a run.

## Separate grids and the power switch (user)
- You can have separate grids: things joined by conduits are one net, and two nets with no conduit between
  them do not share power or batteries.
- A power switch turns a grid off to save excess power, mostly for defenses: turrets idle all day and only
  need power in a fight.
- The switch has to sit in the conduit line, in sequence: generator and batteries, conduit, switch, conduit,
  the things to cut off. If any other conduit goes round the switch, it cuts nothing.
- Through the mod: `build power switch at X, Z.` on the line (take the conduit cell out first if the game
  refuses the spot: `show blueprints.` says why); `switch off power switch at X, Z.` and `switch on power
  switch at X, Z.` for one switch out of several; a colonist walks over and flips it, so do it before the
  raid is at the door. `show power.` afterwards shows the cut-off part as its own net.

## Wind turbines: keep the wind path open (source, user)
- (user, live game 2026-10-04: "build them in open terrain OR YOU WILL GET NO POWER") Never stack turbines
  in front of or behind each other, and keep them away from walls, roofs, rock and trees.
- The turbine is 7 wide and 2 deep. `facing north` at X, Z it stands on x X-3 to X+3, z Z and Z+1 (seen in
  the live game's buildings map).
- Its wind path (`RimWorld\WindTurbineUtility.cs:8-58`) is two strips as wide as the turbine: for north or
  east facing, 10 cells in front and 6 behind; for south or west facing, 6 in front and 10 behind. Facing
  north at X, Z that is x X-3 to X+3, z Z+2 to Z+11 and z Z-6 to Z-1: keep that 7 by 18 box clear.
- Every path cell that is roofed or holds something that blocks wind takes 20% off the output
  (`RimWorld\CompPowerPlantWind.cs:46, 114-125, 208-239`): 5 blocked cells and the turbine makes nothing.
- Output is 2300 W times the wind speed, capped at 1.5 (`CompPowerPlantWind.cs:106-108`), so it swings
  between 0 and 3450 W. (The 2300 W is from memory of the game's data, unchecked.)
- Several turbines: side by side in one row, all facing the same way, so the strips lie next to each other
  and never cross a turbine. Conduits, stockpile zones and growing zones in the path are fine (unchecked for
  crops: tall plants such as trees block).
- Example: `build wind turbine at 110, 105 facing north.` then `build wind turbine at 102, 105 facing north.`
  with a conduit along the row next to them: `build power conduit from 102, 107 to 114, 107.`
- The mod does not warn about a blocked path when it plans a turbine: check the box yourself with
  `show buildings map of 99, 99 to 114, 116.` and `show roof map of 99, 99 to 114, 116.` first.

## What the answer does not tell you
- It is the rate right now. A solar generator makes nothing at night and a wind turbine varies (unchecked),
  so ask at night and in daylight before trusting an excess.
- No line per generator or per consumer: `show building NAME.` one at a time, or switch things off and ask
  again.
- No forecast (an eclipse, a solar flare, fuel running out). `show building wood-fired generator.` shows
  fuel; `show events.` shows the letters.

## Doing (mod)
- A geothermal generator can only stand on a steam geyser: `build geothermal generator anywhere.` puts it on
  the nearest free geyser in view (the plan line names the cell); for another one,
  `where are steam geysers.` then `build geothermal generator at X, Z.`
- Build: `build wood-fired generator near SPOT.`, `build battery at SPOT.`, conduits as a line:
  `build power conduit from 100, 80 to 100, 95.` Only what is on the `buildings` line can be built;
  Electricity research comes first (`show research path to electricity.`).
- Switch: `switch off NAME in ROOM.` / `switch on ...` for anything on the `switchable` line; fuel:
  `turn on auto refuel for NAME.`, `set fuel level to N for NAME.`
- A building that says "not getting power" is on a net that makes too little; one "on no net" needs a
  conduit to it.

## Things a player knows
- (user) Most power generation can not sit inside a mountain, so it is what a siege's mortars hit. Plan for
  repairs, and do not let the whole base depend on one outdoor generator block.
- (unchecked) Batteries on a net can short-circuit and start a fire; keep them in their own stone room and
  not in the rain.
- (unchecked) Heaters, coolers and benches draw only while they work; the excess moves with what the
  colonists are doing.
- The research benches for Microelectronics and Fabrication need power all day (see `furniture.md`): size
  the batteries for the night before you start.

## Heat from a steam geyser instead of heaters (user)
- (user, live game 2026-10-04, day 7: "you built your main area over geyser (smart), but your indoor farm
  is disconnected from it. maybe connect it so you dont need to waste power on heater?") A geyser inside
  a roofed room heats it for nothing; the geyser must be walled in (user, 2026-10-06). Join the rooms that
  need heat to that room (an opening or a vent in a shared wall) before building heaters; each heater that
  can go is power for something else.
