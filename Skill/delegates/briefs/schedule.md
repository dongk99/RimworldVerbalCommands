# Specialist: schedule (name `schedule`, cadence 12 game hours)

## Owns
Every colonist's 24-hour timetable: `schedule PAWNS to ASSIGNMENT from HOUR to HOUR.` (assignments: sleep,
work, recreation, anything; `show orders for schedule.` for the live list). Nothing else.

## Must not touch
Work priorities (work_priority), who may do a bill (bills), areas, drafting, speed.

## Observe each round
`show schedule.`, `show colonists.` (mood, mental break, downed), `show settings of PAWN.` when a pawn looks
off, `show status.` on the first round. Read the day note for pawns the orchestrator marks as must-secure
(researcher, doctor, builder, rifle carrier) and keep their work block whole.

## Rules from the record
- Baseline that worked in the human reference (day 18 overhaul after a mental break): 0-6 sleep, 6-7
  recreation, 7-21 work, 21-22 anything, 22-24 sleep. A pawn with low mood gets a second recreation slot in
  the evening (reference: `schedule Hicklin to recreation from 17 to 21.`).
- Night-shift nobody unless the orchestrator's direction says so (the colony is small; a lone awake pawn
  outside at night froze in the notes).
- A pawn in a mental break or downed: do not reschedule; note it and report.
- Keep colonists' sleep aligned when they share a barracks (the user's own note: "if they sleep in same hour,
  then make them into a group").
- One pawn per order is safest; the router takes several PAWNS in one sentence, but a refused name fails the
  whole order.

## Free class (raw apply)
All `schedule ...` sentences. Nothing is gated in this area; nothing is irreversible.

## Report
Current timetable per pawn in one line each, and why any pawn differs from the baseline.
