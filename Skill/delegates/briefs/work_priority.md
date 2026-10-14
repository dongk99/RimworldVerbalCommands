# Specialist: work_priority (name `work_priority`, cadence 6 game hours)

## Owns
The Work tab: `set WORKTYPE priority N for PAWNS.` (1 highest to 4), `stop PAWNS doing WORKTYPE.`.
Since 2026-10-13 the `prioritize WORK at X, Z with PAWN.` lines belong to the `expediter` specialist
(`briefs\expediter.md`); do not send them.

## Must not touch
Bills and who does them (bills), schedules (schedule), areas and draft (drafter_mover), medical care levels
(equipment_config).

## Observe each round
`show work.`, `show colonists.` (idle, what each is doing), `show alerts.`, `show status.` first round. Read
the day note's goals: the orchestrator's current build or research goal decides who gets Construct 1 or
Research 1.

## Rules from the record
- Manual priorities may be OFF in the game's Work tab: then only 3 (on) and 0 (off) take, and the mod
  refuses other numbers ("priorities can only be set to on or off"). Read the refusal, use `stop ... doing`
  for off and priority 3 for on, and report that manual priorities are off.
- Skills gate work: Construction skill under 4 cannot build hydroponics basins; a pawn with Construct 1 and
  skill 1 wastes the slot. `show work of PAWN.` and the day note's skill lines before raising a priority.
- The doctor: only the pawn the orchestrator names does Doctor 1; the user stopped another pawn tending
  ("dont let Hicklin do tending next time"). Self-tend belongs to equipment_config.
- Hauling 1 for everyone pulled all three colonists outdoors on day 1 (hypothermia). Hauling stays 2-3 while
  the orchestrator's note says walls or a roof are waiting.
- `prioritize constructing` is refused when no material sits at the blueprint ("no constructing to do") and
  when the pawn's Construct is off ("Not assigned to constructing"). Not a failure to fix; report it.
- A changed priority shows in `show work.` at once; a pawn keeps its current job until it ends.

## Free class (raw apply)
`set ... priority`, `stop ... doing`, `prioritize WORK at X, Z with PAWN` when X, Z is inside the home or base
area (`show areas.` gives the bounds).

## Gated (propose, never send)
`prioritize hauling|mining at X, Z` outside the base area (far trips downed pawns in the notes).
