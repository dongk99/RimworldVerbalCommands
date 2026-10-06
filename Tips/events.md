# Events: what stopped the run, what to ask, what to order

A run (`run 6 hours.`, `run until event.`) pauses by itself and `show speed.` says why. The game then
stays paused until you send the next run. Always read first, then order.

First two questions after any stop: `show events.` (what happened, short lines) and `show status.`

| What stopped it | Ask | Then |
|---|---|---|
| Threat letter: raid, manhunter pack, prison break (mod: pauses) | `show threats.` | `defense.md`, "When the raid letter comes" |
| Siege: they camp and shell you with mortars (user) | `show threats.` (hostile buildings line = the camp) | under a mountain you are safe, your power outside is not; hide and repair, or go out and break the camp: `defense.md` |
| Breachers: they go round the defenses and break the wall at its weakest spot (user) | `show threats.` between short runs: where is the group heading | move colonists to a second position behind that wall before it goes: `defense.md` |
| Colonist downed (mod: pauses) | `show health of NAME.`, `show threats.` | `rescue NAME.` then `tend NAME with DOER.`; no bed yet: `build bed near NAME.` or a sleeping spot |
| Colonist bleeding out within a day (mod: pauses) | `show health of NAME.` | `tend NAME with DOER.` now; `turn on self tend for NAME.` if nobody else can |
| Mental break (mod: pauses) | `show mood of NAME.` | fix the biggest thought; a violent one: `arrest NAME with DOER.` is risky, often better to keep others away |
| Starving (mod: pauses) | `show food.` | hunt (`hunt deer.`, see `show wildlife.`), harvest (`harvest berries.`), a cooking bill; sow now for later |
| Fire in the home area (mod: pauses) | `show threats.` (fire lines) | `extinguish fire near NAME.`; rain puts it out too (unchecked) |
| A letter that needs a choice: joiner, ransom, visitors (mod: pauses) | `show letters.` | `choose OPTION for letter LETTER.` |
| Death letter (mod: pauses) | `show status.` | the run is lost if it was one of the three |
| Disease (unchecked whether it pauses: the letter kind is in the game's data, not checked) | `show health of NAME.` | `have NAME rest.`, `tend NAME with DOER.` every time it is due, best doctor, best medicine: `assign NAME to medicine group herbal medicine.`; a bed set to medical |
| Cold snap, heat wave, toxic fallout and the like (unchecked whether they pause) | `show weather.`, `show temperature.` | heat or cool a closed room (`build campfire ...`, heater, cooler), parkas, keep people indoors with an allowed area |
| Trader caravan or orbital trader (mod: does NOT pause; it is in `show events.`) | `show interactable pawns.` | `trade.md`: send one colonist to the one pawn that trades, then the trade lines |
| Visitors, travellers, a quest giver (mod: does not pause) | `show interactable pawns.` | `use option WORDS on NAME with PAWN.` for what the list offers; else nothing needed |
| Animals join, cargo pods, a good event (mod: does not pause) | `show events.` | `unforbid items near SPOT.` for dropped cargo; `haul ...` |
| The run ended with nothing | `show pending.` | give the next orders, run again |

## Habits
- Short runs when anything is wrong (1 to 3 hours), long ones when all is calm (`run until event.`).
- A run is a change: send it with `mode: raw apply`, or it waits for `apply` and the game stays paused.
- `set game speed to normal.` un-pauses with no end and no auto-pause. Use `run`, not this.
- After every fight: `show status.`, tend, rescue, then `undraft everyone.` or nobody works.

## Not in the mod yet
Your own caravans and the world map, a list of quests, cover and line of sight (see `defense.md`).

## After a fight: the tame animals too (user)
- (user, live game 2026-10-04, day 15, after a mad snowhare hurt the cat: "You forgot to RESCUE alvin after
  tending it, and didnt make animal sleeping spot, so i did it for you.") `show status.` lists colonists
  only. After any fight or manhunter pack ask `show animals.` and look for a hurt or downed tame animal.
  A downed animal has to be rescued to an animal bed or animal sleeping spot before it can be tended and
  can rest; with no such spot on the map there is nowhere to carry it.
- So: every colony with a tame animal gets an animal sleeping spot indoors on day 1 (it costs nothing).
  Then after a fight: rescue (right-click order on the animal's cell, `use option rescue on X, Z with
  NAME.`), then tend.

## Venerated animals are not food (user; game code)
- Live game 2026-10-04, day 8-9: the food ran out and `slaughter Alvin.` (the cat) was planned twice. The
  plan already said "Warning: Cats are venerated by all colonists, and will not be harmed." The mark was
  never carried out, three colonists starved, and the right-click order said "Cannot slaughter Alvin:
  Ideoligion forbids" (the user got the same in the game). Read the plan's warning: when it says an
  animal is venerated, find food elsewhere (`show food.`, hunt, harvest, trade) at once.
- Game code (`Data\Ideology\Defs\PreceptDefs\Precepts_Animal.xml`, Assembly-CSharp): a venerated animal
  "may never be harmed": slaughtering and hunting it are refused for believers. Eating its meat gives "ate
  venerated animal meat" -8 mood for 5 days; a tame one dying gives everyone "venerated ANIMAL died" -5 for
  5 days; having them around gives "venerated ANIMAL" +1 and up.
- Selling one (user: "my 300 day colony doesnt have that cat. I guess selling them must be allowed."): no
  trade check for venerated animals was found in the game code, so selling looks allowed; it loses the
  "venerated ANIMAL" mood bonus. Not tried through the mod.
- Getting rid of one without harming it (user: "sterilizing them has a surgery fail chance and let them
  bleed out."): vanilla `Sterilize` (`Data\Core\Defs\HediffDefs\Hediffs_Local_Misc.xml`, the recipe is in
  that file) works on any creature, needs Medicine 3, and has no death chance on failure (0%). A failed
  surgery still hurts: `Data\Core\Defs\RecipeDefs\SurgeryOutcomeEffectDefs.xml` rolls the outcomes in
  order (success at most 98%, then death, then 45% "failed catastrophically" on the operated part, then 5%
  of the rest "failed in a ridiculous way" on a random part, else a minor failure). Of failures with no
  death that is about 45% catastrophic and 2.75% ridiculous, each 65 damage, which can make it bleed out. So:
  the worst surgeon who still has Medicine 3. Not checked: whether the venerated rule objects to the
  surgery (no check for it was found in the game code). A tame venerated animal that dies still gives
  everyone -5 for 5 days.
