# Babies: crying, the nursery, baby food

## Crying spreads to everyone nearby
(game code: `Verse.AI.MentalState_BabyFit`, `MentalState_BabyCry`, `Verse.GenClamor`;
`Data\Biotech\Defs\ThoughtDefs\Thoughts_Memory_Childcare.xml`, `MentalStateDefs\MentalStates_BabyFits.xml`)
- A crying baby is heard by everyone within 9.9 cells (`BabyScreamRadius`), shortened by the hearer's
  Hearing; a deaf pawn does not hear it.
- The sound only goes through open space and open doors: a closed door stops it.
- Each hearer gets "baby crying" -8 mood (the baby's own mother or father "my baby is crying" -4 instead),
  for a quarter day, stacking up to 3 (each further one at 80%), once per crying fit. Each hearer also
  thinks less of the baby: "cried" -12 opinion for 10 days, stacking up to 5.
- How often a baby cries goes with its mood: about every 2 hours at 0 mood, once a day at half, once in 8
  days at full mood. A giggling baby does the opposite: +4 mood to hearers, +12 opinion of the baby, and
  happy babies giggle often.

## Where the nursery goes (user)
- Crying babies cost mood, so put the nursery where pawns do not work. From the game code above: more
  than 10 cells away from work spots, or behind a door that stays shut.
- Keep the baby happy: a happy baby rarely cries. A good crib gives the baby +2 mood, excellent more
  (`ThoughtDefs\Thoughts_Situational_Children.xml`, `CribQuality`; normal or worse gives nothing).

## Baby food and food poisoning
- (user) Milk can give food poisoning, so take milk out of the baby food bill.
- What the game code shows (`Data\Core\Defs\ThingDefs_Items\Items_Resource_AnimalProduct.xml`,
  `RimWorld.Thing.Ingested`, `RimWorld.CompFoodPoisonable`):
  - Raw milk has a fixed 2% food poisoning chance each time it is eaten raw, and babies may eat raw milk
    (`babiesCanIngest`).
  - Baby food does not take over its ingredients' chance. Baby food is poisoned when it is made: by a
    dirty kitchen (the room's food poison chance) or by the cook (their food poison chance, from Cooking
    skill). Milk in the bill does not change that.
  - Not checked: whether taking milk out of the bill leaves more raw milk in storage for the babies to be
    fed directly.
