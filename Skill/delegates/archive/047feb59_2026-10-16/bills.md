# bills notes

## Round 1 (call started day 0 6h, game paused at 7h)
- Read COMMON, brief bills, day_01 plan. Notes file did not exist; created.
- Observed: `show status.` (3 colonists in drop pods, Zimmerman sick, Stumpy sick, Hicklin healthy; food 7 meals, 0 raw; research hydroponics 0/700; no power; no alerts).
- `show food.`: 57 packaged survival meals loose (53 forbidden), potatoes x10 loose (forbidden). Nothing rotting. No growing zones. No wild food within 30 tiles.
- `show buildings map.` and `show map around 112, 125.`: no benches, no campfire, no butcher spot. Only blueprints (x) on the wall outline and stockpile zone (z). Steam geyser 2 at 108, 125.
- `how much meat do i have.`: 0.
- `show questions for bills.`: refused, "No question sentence starts with 'bills'." (use show bills at BENCH in ROOM once a bench exists)
- Orchestrator trigger (campfire/cooking spot AND butcher spot AND meat in) not met. Nothing proposed, nothing sent. Zero orders applied.
- Rules to apply on the next round: butcher bill `forever` at the butcher spot once a corpse exists; `simple meal until you have N` (N = colonists x 2 = 6) at the stove, campfire only until the stove exists; the best Cooking pawn does the meal bill (Zimmerman, Cooking 4, is the only cook so far; Stumpy and Hicklin have no cooking skill listed).
- Note for COST line: packaged survival meals are already 57 loose; a simple meal bill will consume raw meat/potatoes, not survival meals.

## Round 2 (day 0 13h-14h)
- `how much meat do i have.`: 0. `show food.`: 55 survival meals (47 in storage), potatoes x10 in storage, nothing rotting.
- `show map around 112, 125.` and detail maps: no corpse, no cooking spot, no butcher spot named. Two unnamed building blobs at 106-107/126-127 (2x2) and 109/123 (1x1); the interpreter does not name them.
- Name checks, all refused: `show bills at campfire in base.` ("'campfire' is not a bench on the map"), `show bills at butcher table in base.` ("'butcher table' is not a bench on the map"), `show bills at stove in base.` ("'stove' is not a bench on the map"). `show what is at X, Z.` is not a question the interpreter knows. `show questions for buildings.` and `show questions for bills.`: no such question sentence.
- Interpreter TIP (not a failure): butcher in another room, the kitchen makes food poisoning more likely.
- Orchestrator trigger still not met (no campfire/cooking spot, no butcher spot, no meat). Nothing proposed, nothing sent. Zero orders applied.

## Round 3 (day 0 21h)
- `how much meat do i have.`: 0. Re-checked `show bills at butcher table in base.`, `show bills at stove in base.`, `show bills at campfire in base.`: all three refused ("is not a bench on the map"). Nothing built, nothing proposed, nothing sent.
