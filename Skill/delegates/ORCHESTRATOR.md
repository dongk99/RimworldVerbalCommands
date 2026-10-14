# Delegating colony work to specialist subagents (orchestrator side)

Written 2026-10-13 from the user's decisions in that session (quoted where they matter). The playing session is
the **orchestrator**; it spawns **specialists**, one per colony function, that act on the game through the same
interpreter (`send.ps1`) and run on their own until the orchestrator stops them. The user's words: "i want the
subagents doing the task more or less autonomously unless the orchestrator stops them."

Model for specialists (user, 2026-10-13): **Haiku 5.5 at high effort, changeable** (`Agent` tool,
`model: "haiku"`, `effort: "high"`). Specialists read play notes, know-how and the mod's answers; they do not
read code (user CLAUDE.md).

## 1. What a specialist may do on its own (no pause, no review)

The user's criterion (2026-10-13): review what "consume[s] resources and [it is] impossible [to] get full
resources back, irreversible". Everything below changes a setting the next sentence can undo, costs nothing,
and had zero recorded harm in 1,680 logged orders (router logs 2026-10-03..13) and 20 play notes:

- every question;
- schedule changes; work priorities and `stop PAWN doing WORK`;
- clothing / food / drug / reading / medicine group assignment, fire at will, bed assignment (not bed role);
- storage filters and priorities on existing zones and shelves; forbid / unforbid **near a spot inside the
  base** (never map-wide: see 2);
- equip and wear (the item must be in view; "No X in view" is a harmless failure);
- undraft, cancel hunting / mining / blueprint of its own earlier marks;
- `set game speed`, `close window`, `choose Close for letter` (orchestrator only, see 4).

With the pause change in `AgentInbox.cs` (build of 2026-10-13) none of these pauses the game: the inbox pauses
only while a plan or a question waits.

## 2. What goes through the orchestrator (gated)

The specialist does **not** send these. It writes a proposal (section 3) and returns. The orchestrator reads,
edits if it wants ("orchestrator can adjust plan if needed, from specialist"), and sends the order itself in
wait mode, reads the mod's plan, then applies or cancels. The game is paused only while that plan waits.

| Gated | Why (from the record) |
|---|---|
| Any build, room, floor, furniture, spot placement | every user hand-correction in the notes was a placement; materials are not fully returned. "planning/building should also be accepted by orchestrator after making a plan layout & where it wants to build (probably direction given by orchestrator)" |
| Bills (add, change count, ingredients) | user: "specialists relay bills (e.g. im making 5 clothes because...) to orchestrator and orchestrator can accept/deny/edit". Relay first, then the specialist sends it `raw apply` (user chose this over holding a plan). |
| Slaughter, hunt, attack, capture, arrest, surgery, prisoner mode | irreversible or a pawn fight; the mod marks them RISKY |
| Deconstruct own building, cancel someone else's blueprint, delete zone | materials or work lost |
| Widen an area restriction (`anywhere`, `unrestricted`), hauling or mining far from base, map-wide unforbid | every recorded hypothermia case came from one of these |
| Bed role (medical, prisoner) | drops the bed's owner; user stopped one on day 11 |
| `accept trade`, caravan or aid requests, quest and letter choices beyond Close | **orchestrator only, never proposed by a specialist** (user: "3 can only be done by orchestrator") |

Draft and move are the drafter's own (section 5) but **attack** is gated.

## 3. The round, and how a specialist talks to the orchestrator

A specialist is one `Agent` call that loops:

1. Read `delegates\COMMON.md`, its own brief `delegates\briefs\<name>.md`, its notes
   `delegates\notes\<name>.md` (its own memory across rounds and calls), and the newest `play_log\day_NN.md`.
2. Observe with questions (its brief says which).
3. Apply what section 1 allows, with `-Mode "raw apply"`, one dependent change per order.
4. Anything in section 2: append a proposal to `delegates\proposals\<name>.md`:
   ```
   ## P<n> <date/hour> <one line>
   WANT: <the exact router sentence(s) it would send>
   WHY: <two or three lines of reasoning from the answers it read>
   COST: <materials / pawn time / risk>
   ```
   then **return** (end the Agent call) with a report that lists the open proposals, so the orchestrator is
   notified at once. Do not wait in the loop with a proposal pending.
5. Otherwise write a two-line status to `delegates\status\<name>.md`, append to its notes, and block on
   `wait_round.ps1 -Name <name> -Hours <its cadence>` (drafter: `-OnEvent`). `STOP` or `NOT RUNNING` → return.
   `MESSAGE` → read `delegates\msg\<name>.md`, delete it, act. `HOURS` / `EVENT` / `TIMEOUT` → next round.
6. After at most 8 rounds in one call, return with a report anyway (context).

The orchestrator answers a proposal by resuming the specialist with `SendMessage` (the same agent, its context
kept): `P3 approved, send it`, `P3 denied: <why>`, or `P3 edited: <sentence>; send that`. For a build the
orchestrator sends the order itself and tells the specialist what now stands where. The orchestrator stops a
specialist with the file `delegates\stop\<name>` (or `stop\ALL`), or `TaskStop`.

## 4. The orchestrator's own loop with specialists running

- Keep the game running. Specialists' free-class orders no longer pause it. Pause for your own tasks only
  (notes, reviewing proposals that need thought), and unpause after.
- Your plan/apply pairs still pause while the plan waits; `send.ps1` makes a specialist that collides with it
  wait and retry (up to 120 s), so finish a pair promptly.
- Speed, windows and letters stay yours. Specialists never touch them.
- Each specialist's `status\<name>.md` is one glance; read them at each day turn and put a line per specialist
  in the day note. Delete stale `msg\` files you wrote before they were read if the plan changed.
- Ownership conflicts are settled by you, in the briefs, not in the game: bills (crafter time, materials) vs
  work priorities (who crafts) vs schedule (when). The briefs say what each one owns and must not touch.
- Starting order on a new session: schedule → work_priority → equipment_config → storage_zones → bills →
  drafter_mover (the drafter arms on events and should be last so it does not react to the others' setup).

## 5. The roster (user, 2026-10-13: all six from version one)

| name | owns | cadence | brief |
|---|---|---|---|
| schedule | timetables | 12 h | `briefs\schedule.md` |
| work_priority | work tab priorities, who does what | 6 h | `briefs\work_priority.md` |
| drafter_mover | draft, move, undraft, rescue; proposes attacks | on events | `briefs\drafter_mover.md` |
| equipment_config | equip, wear, medicine level, food/clothing groups, fire at will, self-tend | 12 h | `briefs\equipment_config.md` |
| bills | proposes bills (food, clothing, manufacturing); sends approved ones; pauses / resumes | 6 h | `briefs\bills.md` |
| storage_zones | filters and priorities of existing storage; proposes new zones | 12 h | `briefs\storage_zones.md` |
| expediter | `prioritize WORK at X, Z with PAWN` inside the base: material to blueprints, builders to frames, miners to marks (user, 2026-10-13) | 2 h | `briefs\expediter.md` |

## 6. Spawning (what the orchestrator types)

```
Agent({ subagent_type: "general-purpose", model: "haiku", effort: "high",
  description: "RimWorld schedule specialist",
  prompt: "You are the schedule specialist for a RimWorld colony played through the VerbalCommands inbox.
    Read C:\Users\dongk\.claude\projects\RimWorld-LLM-Integration\agent_player\delegates\COMMON.md first,
    then delegates\briefs\schedule.md, then delegates\notes\schedule.md if it exists, then the newest
    play_log\day_NN.md. Follow COMMON.md's round exactly. Orchestrator's standing direction for this call:
    <one or two lines: current goals, pawns to secure, anything the specialist must not touch today>." })
```
The same for each name. Keep the direction line current: it is the only thing the specialist knows about
your plans beyond the day note.
