# equipment_config notes

## Round 1, day 1 6h to 12h (first call)
Pods had not landed at 6h; they had landed by 7h. Orders sent (all raw apply, all applied with done):
- `equip Zimmerman with revolver at 118, 129.` (revolver found by `where is nearest revolver.`; the answer came 6 tiles from Hicklin)
- `have Zimmerman pick up 1 medicine at 116, 126.` (medicine found by `where is nearest medicine.`; not in the free class list, ordered by the orchestrator)
- `set carry medicine of Zimmerman to 1 medicine.`
- `assign Zimmerman to medicine group herbal medicine or worse.`
- `assign Stumpy to medicine group herbal medicine or worse.`
- `assign Hicklin to medicine group herbal medicine or worse.`
Refusals and gaps:
- `show weapons.`, `where are rifles.`, `where is nearest rifle.`, `where is nearest weapon.`, `where is nearest gun.`, `where are knives.`: not known to the mod (the list of things it can find: steel, compacted machinery, ore, rock, ship chunk, geyser, trees, berries, rich soil, water, animals, hostiles, items). `where is nearest revolver.` works; `where are revolvers.` answered "0 in view" at the same hour (inconsistent).
- `where is nearest coat.`, `where is nearest synthread pants.`: not searchable. `where is nearest parka.`: "No parka in view."
- `show orders for wear.`: none; the wear verb is `have PAWN wear APPAREL at SPOT.`
- `show orders for make.`: only `make weapon group NAME holding RULE.`
- `show orders for set.` lists `set carry medicine of PAWNS to N MEDICINE.` (used).
- `show interactable pawns for Zimmerman.`: no one to interact with in view; self-tend needs `use option WORDS on NAME with PAWN.`
Watch: Hicklin is drafted (drafted pawns do not eat or sleep; the draft is not mine).

## Round 2, day 1 17h to 18h (orchestrator message: rifle in Stockpile zone 1)
Message handled and deleted (msg\equipment_config.md). Orders (raw apply, all applied with done):
- `equip Zimmerman with bolt-action rifle at 119, 127.` (`where is nearest bolt-action rifle.` answered 119, 127; revolver dropped at 119, 127)
- `equip Stumpy with revolver at 119, 127.` (`where is nearest revolver.` answered 119, 127)
- `equip Hicklin with knife at 118, 128.` (`where is nearest knife.` answered 118, 128; plan said plasteel knife)
Refused / not searchable: `where is nearest plasteel knife.` ("not something the mod can look for"); `where is nearest club.` ("No club in view."). `where is nearest bolt-action rifle.` and `where is nearest knife.` work (exact item labels).
Verified with show gear: Zimmerman equipped bolt-action rifle, Stumpy equipped revolver. Hicklin's equip not yet verified.
