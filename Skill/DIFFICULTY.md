# The difficulty: Randy Random, Losing is Fun

Written 2026-10-06 from the game's own files: `Data\Core\Defs\Storyteller\Storytellers.xml` (Randy, lines
666-804) and `Data\Core\Defs\Misc\DifficultyDefs\Difficulties.xml` (Losing is Fun is the def `Extreme`,
lines 163-195). The numbers are the game's; the plain-words reading of them is mine (Claude), not checked
in a game.

## Two separate settings
- The **storyteller** (Randy Random) decides *when* things happen and *what kind*.
- The **difficulty** (Losing is Fun) decides *how hard* each thing is and how the colony fares in general.

## Randy Random: no pattern
The game's own description: "Randy doesn't follow rules. He'll generate random events, and he doesn't care
if they make a story of triumph or utter hopelessness." and "he will sometimes send extremely difficult or
unfair groups of events at you."

- No quiet start beyond day 1: random events begin after 1 day.
- On average one random event every 1.35 days, but at random: two raids back to back, or a long calm, can
  both happen. The other storytellers space things out; Randy does not.
- What kind, by weight (of 9.22 in total): misc events 3.5 (about 38%), people arriving (traders, visitors,
  travellers) 2.4 (26%), big threats (raids and the like) 1.4 (15%), a trade ship in orbit 1.1 (12%),
  small threats 0.6 (7%), ship chunks falling 0.22 (2%).
- At least one big threat every 13 days, even if the dice have not rolled one.
- The size of a threat swings: each one gets between half and 1.5 times its normal strength.
- Traders can come early: Randy has no rule holding them back (Cassandra and Phoebe wait 5 days for the
  first trader caravan). One came on day 2 in the 2026-10-06 run.
- Disease can come from day 0.
- Quests start being offered after about 8 days (fully from day 15).

## Losing is Fun: the hardest preset
The game's own description: "This setting is designed to be unfair. Huge threats will crash upon you
without mercy until your colony dies."

Compared with the middle setting ("adventure story"):
| What | Losing is Fun | Adventure story |
|---|---|---|
| Threat strength (raids, sieges, manhunters) | 2.2 | 0.6 |
| Colonists' mood | -10 | +5 |
| Crops, mining and butchering give | 80% | 100% |
| Research speed | 90% | 100% |
| Disease interval (lower = more often) | 0.9 | 1.5 |
| Food poisoning chance | 1.2 | 0.75 |
| Colonist wound infection chance | 1.1 | 0.75 |
| Infestations from a deep drill | 1.3 | 0.75 |
| Trading: extra price loss | 0.20 | (not set) |
| How much threats ease off after the colony loses people or wealth | 0.4 | (not set) |

In plain words:
- Raids are about 3.7 times as strong as on the middle setting, and the game eases off less after you lose
  someone.
- Every colonist's mood carries a flat -10 all the time (the middle setting gives +5, so 15 lower): mental
  breaks come sooner.
- Food, stone, steel and meat come in at 80%; research is 10% slower.
- Sickness, food poisoning and infected wounds are more common.
- Trading costs more.
