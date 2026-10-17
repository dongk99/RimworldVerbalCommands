# expediter notes

## Round 1 (call 1, day 1 6h-8h)
- Read: COMMON.md, briefs/expediter.md, day_01.md. No prior notes or status existed.
- Observed at 6h: 25 of 29 wall blueprints unbuilt (0% frames), door frame 0%, steel 0 in storage, all three
  colonists already on steel (Zimmerman and Hicklin haul 3, Stumpy construct 3, Stumpy doctor/researcher off).
  Construction priorities already match the orchestrator's plan (Zimmerman/Hicklin construct off).
- Observed at 7h: steel in storage 310; wall blueprints 7 needed 35 more; door frame 53%.
- `prioritize hauling at 104, 122 with Zimmerman.` (raw apply) -> failed, "There is no hauling to do at 104, 122"
  (not a failure: hauling already covered at 8h). Blueprint at 104,122 done by 8h.
- `prioritize hauling at 104, 127 with Zimmerman.` (raw apply) -> failed, "There is no hauling to do at 104, 127"
  (covered by Hicklin hauling x5 at 8h). Zimmerman then on packaged survival meals to stockpile.
- 8h: 12 wall frames 8%, 2 wall blueprints at 104,127 need 10 steel, 275 in storage. Door frame 53%.
- Refusal wording learned: "There is no hauling to do at X, Z (...)" = covered; do not re-send the same cell.
- Researcher exclusion: Hicklin is the only researcher; hydroponics research 0/700 with no bench, so not chosen.
- Sickness: at 6h status showed Zimmerman and Stumpy "sick" (not mine; orchestrator's domain). Not seen at 7h/8h.

## Round 2 (call 1, day 1 10h)
- Wall shelter and door no longer in `show pending` (done). New builds: 3 bed blueprints/frames near 105,127 and
  simple research bench at 111,124 (frame per pending). Blueprints: beds need 135 more, bench needs 100 more,
  164 steel in storage (mod TIP: need 235, have 164; 135 steel already on the carriers).
- Colonists: Zimmerman hauling steel x65 to bed, Stumpy hauling steel x59 to bed (not constructing), Hicklin
  hauling steel x11 to bed. Nobody idle, nobody on construct.
- Not sent: no constructing on Stumpy. Frames show no per-frame delivery in `show blueprints`; the rule needs
  material delivered first. Stumpy's steel hauling is delivering to those frames. Hold; re-check next round.
- Steel after these builds: about 29 spare, then nothing in storage. Next steel comes from outside base (gated).

## Round 3 (call 1, day 1 13h-15h)
- 13h: wall shelter and door done. Bed frame 0% built near 105,127; bench frame 28% near 111,124. Pending: bed,
  bench (both frames).
- 13h colonists: Zimmerman wandering (idle) at 103,129, outside the room; Stumpy and Hicklin digging compacted steel
  at 129,129 (inside base bounds; not my designation: `show designations.` shows 2 mining marks near 128,130).
  All three show hypothermia (outdoor -10C, gentle snow); Stumpy food 26%, Hicklin food 26% at 14h.
- `prioritize constructing at 111, 124 with Stumpy.` (raw apply) -> failed, "There is no constructing to do at
  111, 124" (bench frame has no steel to build with; no construction job).
- `prioritize hauling at 105, 127 with Zimmerman.` (raw apply) -> failed, "There is no hauling to do at 105, 127"
  (no steel in storage to haul; the bed frame cannot take steel).
- `show steel.` is not a known question; no steel stock figure from the interpreter. Use `show blueprints.`.
- Read: steel in base is exhausted; compacted steel digging (Stumpy 31%, Hicklin 47% at 14h, a survival meal at
  14h) is the only steel source inside base. Zimmerman has no free-class job (Construct off, forbidden; Haul has no
  job; he is the doctor).
- Gated, not sent: steel outside base (day note: 720 at 56-57, 64-69), hauling far; orchestrator decides.

## Round 4 (call 1, day 1 17h)
- Bench frame 89% built, Stumpy building it (constructing). Bed frame no longer listed in `show blueprints.`
  (not mine; not in pending at 13h either; orchestrator's decision).
- New blueprint: wall (wood) at 116, 130, needs 5 more wood, 85 in storage. Hicklin gathering wood to deliver.
- Zimmerman hauling a sandstone chunk to stockpile zone 3 (not idle). Nothing sent this round.

## Round 5 (call 1, day 1 20h-21h)
- Nothing waiting to be built (`show blueprints.`). Bench done; no bed listed.
- Idle: Zimmerman and Stumpy wandering; Hicklin researching.
- One mining mark at 130, 130 (14 tiles east of Zimmerman), nobody on it.
- `prioritize mining at 130, 130 with Stumpy.` (raw apply) -> failed, "Cannot mine compacted steel: Outside allowed
  area (base)". `show areas.`: base is 92,108 to 135,142 (1206 cells), Stumpy, Hicklin and Zimmerman kept to it,
  so 130,130 should be inside. Instrument gap: refusal does not match the area bounds; quoted, not retried.
- Earlier at 14h Stumpy and Hicklin were digging compacted steel at 129,129 (accepted). Not retried.

## Round 6 (call 1, day 1 23h)
- Nothing waiting to be built. Night: Stumpy sleeping, Hicklin resting, Zimmerman eating a survival meal (mood 42%).
- Nothing sent.
