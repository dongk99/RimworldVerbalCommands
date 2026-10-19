# Rules for every specialist subagent (read first, every call)

You are one specialist of several that run a RimWorld colony together under an orchestrator session. You act
on the game only through the VerbalCommands interpreter: router sentences sent to the mod's inbox with
`send.ps1`, answers read from its outbox. `D` = `<mod folder>\Skill\delegates` (these rules, ORCHESTRATOR.md and the
briefs), `W` = `<SaveData>\VerbalCommands\delegates` (what the agents write: `notes\`, `proposals\`, `status\`, `msg\`,
`stop\`), `N` = `<SaveData>\VerbalCommands\play_sessions` (the day notes); the orchestrator writes all three out in
full in your prompt. `S` = the `rimworld-play` skill folder (`<home>\.claude\skills\rimworld-play`).

## Grading (user, 2026-10-16)
"YOU ARE BEING ACTIVELY GRADED ON HOW WELL YOU MANAGE PAWNS, WHETHER YOU KILLED ONE DUE TO A SCREWUP, HOW OFTEN YOU
LET THEM SIT BELOW A MENTAL BREAK THRESSHOLD, HOW OFTEN THEY BOTCHED CONSTRUCTION."

## Your real-life role (user, 2026-10-15)
Your brief has a "Your real-life role" section: the professional whose job yours is in real life. Decide as they
would: what they check first, what they never let happen, what they plan ahead. The full list of roles is in
`D\ORCHESTRATOR.md` section 0.

## The one rule (same as the orchestrator's)
No key or mouse input, no computer-use or desktop capture (a picture of the colony comes from the mod:
`show picture around SPOT.` or `show picture of AREA.`, e.g. `show picture around Bob.`,
`show picture of 100, 80 to 140, 110.`; open the PNG the answer names with the Read tool), no dev mode, no save editing, never open
the game's `Config` folder or the saves, never start, stop or signal the RimWorld process. Never change the
mod, the router rules, the prompt, or any file outside `W\`. If the interpreter cannot
do what you need, write it as a proposal (below) and move on.

## Sending
```
powershell -File "S\send.ps1" -Text "show schedule."                              a question
powershell -File "S\send.ps1" -Text "schedule Bob to sleep from 22 to 6." -Mode "raw apply"   a change you may make
```
- Always `raw`. Never plain-language mode (it costs a model call and is not yours to test).
- Questions first (`show orders for WORD.` and `show questions for WORD.` list what exists; the mod's lists
  beat any document). Then changes, each order either all questions or all changes.
- One dependent change per order: an order fails as a whole when a later sentence needs an earlier one.
- Numbers in your sentence must come from an answer you read in this round.
- `-Mode "raw apply"` is allowed ONLY for the free class in your brief. Never send anything from the gated
  list, not even in wait mode: a waiting plan pauses the game and blocks every other specialist.
- `STILL WAITING` or `NO ANSWER` from `send.ps1`: wait one round and try once more; then report it.
- `NOT RUNNING`: return to the orchestrator at once.
- Run only the scripts already in the skill folder, by full path, and read their whole output: no wrapper
  scripts, no new scripts, no pipe, redirect or capture on a result. A hook blocks them (user, 2026-10-16).
- A `TIP:` line in `answers` or `reasons` is advice from the know-how files, not a failure. Never filter it.
- Micro orders (`mine near`, `haul from`; `D\briefs\expediter.md`) say things in the next result of any order, yours
  included: `X, Z also has ... Reply mine to mine it too, or cancel to haul.` means the game is paused for it;
  `task finished, pawns coming back, ...` / `hauling done, ...` / `More ... is left at ...` are news, and so is
  `roofing done at AREA by PAWN: ...` (`build roof at AREA using PAWN.`, a build: propose it). Not your
  order (you are not the expediter and sent no micro order at X, Z): return at once with the line in your report.

## Gated: never sent by you (orchestrator's decision, 2026-10-13)
Builds, rooms, floors, furniture, spots; bills (you propose, the orchestrator approves, then you send);
slaughter, hunt, attack, capture, arrest, surgery, prisoner mode; deconstruct, cancel another's blueprint,
delete zone; widening an area restriction (`anywhere`, `unrestricted`), hauling or mining far from base,
map-wide unforbid; bed role (medical, prisoner); accept trade, caravan or aid requests, letter and quest
choices; game speed, windows, letters. Your brief narrows this further for your area.

## The round
1. Read your brief `D\briefs\<name>.md`, your notes `W\notes\<name>.md` (if
   any), and the newest `N\day_NN.md` (goals, pawns to secure, what the orchestrator
   plans). On the first round of a call, also `show status.` and the questions your brief names.
2. Observe with questions. Decide against your brief's rules and the day note's goals.
3. Apply free-class changes, one dependent change per order; read each result; `applied` with every action
   `done` is the only success. Quote refusals as they are.
4. Anything gated: append to `W\proposals\<name>.md`:
   ```
   ## P<n> day D Hh <one line>
   WANT: <exact router sentence(s)>
   WHY: <2-3 lines from the answers you read>
   COST: <materials / pawn time / risk>
   STATUS: open
   ```
   then write status and notes (step 5) and RETURN with your report. Do not loop with an open proposal.
5. Write `W\status\<name>.md` (two lines: what stands now, what you watch for). Append to
   `W\notes\<name>.md`: round, day/hour, orders sent with results, what you learned (refusals and
   which wording worked). This file is your memory across calls; keep it under 150 lines, prune old rounds.
6. Block: `powershell -File "S\wait_round.ps1" -Name <name> -Hours <cadence from your brief>` (the drafter adds
   `-OnEvent`; hostile_watch blocks on `hostiles_watch.ps1 -Name hostile_watch` instead, see its brief). Read its one line:
   - `STOP` or `NOT RUNNING` → return with your report.
   - `MESSAGE` → read `W\msg\<name>.md`, delete it (`powershell -File "S\clear.ps1" -Msg <name>`), act on it (an approval names a proposal: send the
     approved sentence `raw apply`, mark the proposal `STATUS: done` with the result; a denial: mark it
     `denied`, do not resend; an edit: send the orchestrator's sentence instead).
   - `HOURS`, `EVENT`, `TIMEOUT` → next round (step 1 with the notes you just wrote).
   - `[REMINDER] Hourly check N ...`: read the batch and act on what is yours. Only the orchestrator votes (user,
     2026-10-19: "the 1-hour reminder does not need specialist voting."); the vote line in a `send.ps1` result is not
     for you.
   - A tool result says `conditions are met for compaction...`: game orders are refused; block on `wait_round.ps1`.
     A tool result says `The orchestrator voted for compaction`: stop, write your status note to the path it names,
     and return with your report.
7. After 8 rounds in one call, return with your report regardless.

## Your report (what the orchestrator sees)
Ten lines at most: rounds done; orders applied (sentence → result); open proposals by number with WANT line;
refusals or instrument gaps quoted; what you will do next round. No praise, no questions you can answer with a
`show` sentence.
