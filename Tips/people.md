# People: prisoners, recruits, skills, clothing

## More hands (user)
- You are more or less encouraged to take prisoners and convert or recruit them, depending on what your
  pawns lack. Three colonists is thin; a downed raider is a possible fourth.
- For early-game pawns people prefer, among the non-combat skills: **art, construction, research**. Look at
  a prisoner's skills before deciding what to do with them.

## Doing it through the mod (mod)
- After a fight: `show threats.` lists who is downed. `capture raider 2 with Carl.` carries a downed enemy
  to a prisoner bed. It needs a prisoner bed first: `build bed near SPOT.` inside a closed room, then
  `set every bed in ROOM to prisoner.` (the room needs a name on the `rooms` line; a bed in the open or in
  your own bedroom does not hold a prisoner (unchecked)).
- Look them over: `show prisoners.`, `show skills of NAME.` (skills, passions, what they can not do,
  traits), `show health of NAME.`
- Decide: `set prisoner mode of NAME to recruit.` / `convert` / `release` / `no interaction`. The modes on
  offer are on the `prisoner modes` vocabulary line. `execute` and `release` are marked risky.
- A warden does the talking: `set Warden priority 1 for Alice.`; a good talker (social skill) is faster.
  `show prisoners.` shows the recruit numbers going down.
- Feed and treat them: `tend NAME with DOER.`, medicine with `assign NAME to medicine group ...`.

## Who does what
`show skills of NAME.` for each colonist, `show work.` for the priority grid, then
`set WORKTYPE priority N for NAME.` (1 is highest). Research needs someone on Research every day; construction and mining come first in the first days.

## What to make clothes from (user)
- **Cloth is the worst.** Use it only until you have something else.
- **Human skin sells well.** Only if your colonists' religion does not mind butchering and skinning people;
  some factions and religions do not like it. Check moods (`show mood of NAME.`) before making it a habit.
- Wool and the better fabrics beat cloth on nearly every number: see the table.

Fabrics, from the wiki table the user gave (picture: `fabrics_table.jpg`). The x numbers multiply the
garment's own value; insulation is degrees C added; market value is silver per unit.

| Fabric | Beauty | Max hit points | Flammability | Armor sharp | Armor blunt | Armor heat | Insulation cold | Insulation heat | Market value |
|---|---|---|---|---|---|---|---|---|---|
| Alpaca wool | x1.5 | x1 | x1.7 | x0.36 | x0 | x1.1 | +30 | +16 | 3.8 |
| Bison wool | x1.5 | x1 | x1.7 | x0.36 | x0 | x1.1 | +26 | +12 | 2.7 |
| Cloth | x1 | x1 | x1.2 | x0.36 | x0 | x0.18 | +18 | +18 | 1.5 |
| Devilstrand | x3.2 | x1.3 | x0.4 | x1.4 | x0.36 | x3 | +20 | +24 | 5.5 |
| Hyperweave | x5.5 | x2.4 | x0.4 | x2 | x0.54 | x2.88 | +26 | +26 | 9 |
| Megasloth wool | x1.5 | x1 | x1.7 | x0.8 | x0 | x1.1 | +34 | +12 | 2.7 |
| Muffalo wool | x1.5 | x1 | x1.7 | x0.36 | x0 | x1.1 | +28 | +12 | 2.7 |
| Sheep wool | x1.5 | x1 | x1.7 | x0.36 | x0 | x1.1 | +26 | +10 | 2.7 |
| Synthread | x2.3 | x1.3 | x0.7 | x0.94 | x0.26 | x0.9 | +22 | +22 | 4 |
| Mastodon wool | x1.5 | x1 | x1.7 | x0.36 | x0 | x1.1 | +32 | +14 | 2.7 |
| Muskox wool | x1.5 | x1 | x1.7 | x0.36 | x0 | x1.1 | +30 | +10 | 2.7 |

Reading it: for cold, megasloth, mastodon, alpaca and muskox wool are warmest; for armor, devilstrand and
hyperweave; wool burns easily (x1.7), devilstrand and hyperweave hardly (x0.4). Cloth is last or near last
in armor heat, beauty and value. Furs and leathers have their own table, not written down here yet: ask
the mod what a piece is worth once someone wears it (`show gear of NAME.`).

In the mod: the material goes after "made of" only for buildings. A tailoring bill picks its fabric from
what the bill allows: `use only muffalo wool in bill for RECIPE at BENCH.`, `never use cloth in bill for
RECIPE at BENCH.`

## Clothing (mod, for what it prints; unchecked for how the game uses the numbers)
- `show gear of NAME.` now prints each worn piece with its stats, not only its name: quality, hit points,
  armor (sharp, blunt, heat, in percent), insulation (cold and heat, in degrees C), and whether it was worn
  by a corpse (a mood penalty). The last line is the temperature range the pawn is comfortable in with
  everything it wears.
- `show temperature.` gives the outdoor and room temperatures to hold that range against;
  `show mood of NAME.` shows a clothing thought when there is one.
- `who wears parka.` / `who does not wear helmet.` find the gaps. `have NAME wear parka.` dresses one
  now; clothing groups (`assign NAME to clothing group Worker.`) set what they pick by themselves.
- The mod does not print the stats of clothes lying in storage or of what a tailor could make. To compare,
  have someone wear it and ask again.

## Recreation (user)
- (user, live game 2026-10-04, day 7: "your pawns are almost out of recreation.") `show status.` does not
  show it. Ask `show needs of NAME.` for every colonist each morning; Recreation under 30% is a fault to
  fix that day (a recreation source they can reach inside their allowed area, and time to use it).

## A downed colonist drops the weapon (user)
- (user, live game 2026-10-04, day 13: "colonists drop weapon when they incapacitate. (hickling dropped his
  revolver and i picked it up for you.)") After anyone was downed (starving, wounded, a break), ask
  `show gear of NAME.` once they are up; if "Equipped" is empty, the weapon lies where they fell: have them
  pick it up again (`use option equip on X, Z with NAME.`, the cell from the downed event) before the next
  fight. Nothing in `show status.` says a colonist is unarmed.
