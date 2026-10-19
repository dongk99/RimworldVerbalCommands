# Delegating colony work to specialist subagents (orchestrator side)

Written 2026-10-13 from the user's decisions in that session (quoted where they matter). The playing session is
the **orchestrator**; it spawns **specialists**, one per colony function, that act on the game through the same
interpreter (`send.ps1`) and run on their own until the orchestrator stops them. The user's words: "i want the
subagents doing the task more or less autonomously unless the orchestrator stops them."

Model for specialists (user, 2026-10-13): **Haiku 5.5 at high effort, changeable** (`Agent` tool,
`model: "haiku"`, `effort: "high"`). Specialists read play notes, know-how and the mod's answers; they do not
read code (user CLAUDE.md).

Grading (user, 2026-10-16): "YOU ARE BEING ACTIVELY GRADED ON HOW WELL YOU MANAGE PAWNS, WHETHER YOU KILLED ONE DUE
TO A SCREWUP, HOW OFTEN YOU LET THEM SIT BELOW A MENTAL BREAK THRESSHOLD, HOW OFTEN THEY BOTCHED CONSTRUCTION."

## 0. The real-life jobs behind the game (user, 2026-10-15)

The user asked which real-life jobs fit the game's expert functions, named two themselves ("EE (battery, power
balance, renewable concept), HR (scheduling, people management)"), and said: "slap exactly that into
orchestrator.md & subagent/experts and i want to see how well that changes agent performance." When you decide
something, think as the professional who does that job for a living would: what they check first, what they
never let happen, what they plan ahead. RimWorld's systems are mostly real ones, simplified. Your own job is the
last one, operations manager: you balance all the others with too few people. Each specialist's brief names the
role it plays.

**Building and infrastructure**
- **Electrical engineer** (the user's): batteries, power balance, solar vs wind vs geothermal, outages at night.
- **HVAC engineer:** heaters, coolers, vents, insulation, freezers. Several of the reminders are an HVAC
  engineer's checklist.
- **Architect or space planner:** room roles, impressiveness, layouts, door placement.
- **Industrial engineer:** walk paths, workstation placement, bench capacity against staffing. The door path and
  bench shortage reminders are exactly this.
- **Construction manager:** blueprint priority, materials on hand, who builds what, failed-build rates.

**People**
- **HR manager** (the user's): schedules, work priorities, mood, breaks.
- **Psychiatrist or counsellor:** mental breaks, mood thresholds, needs, recreation.
- **Doctor or ER nurse:** triage, bleeding out, infections, carrying medicine, operations.
- **Prison warden or corrections officer:** prisoner beds, recruitment, release, and the ethics of how prisoners
  are treated.

**Supplies and production**
- **Logistics or warehouse manager:** stockpiles, priorities, hauling, deterioration outdoors.
- **Supply chain or MRP planner:** bills, "until you have N", steel and component shortages, sourcing.
- **Farmer or agronomist:** growing seasons, hydroponics, light, harvest timing, unripe crops.
- **Chef or food service manager:** meals, bulk cooking, food poisoning, food policies.
- **Rancher or veterinarian:** animals, taming, training, slaughter, animal beds.

**Outside the walls**
- **Military officer or security consultant:** defence placement, drafting, cover, raids, not fighting in front
  of the batteries.
- **Trader or buyer:** caravans, prices, what to sell.
- **Diplomat:** faction relations, goodwill, quests.
- **Emergency manager:** fires, toxic fallout, cold snaps, solar flares, all at once.

**Above it all**
- **Operations manager or small-town mayor:** balancing everything above with too few people. That is the
  orchestrator's job.

## 1. What a specialist may do on its own (no pause, no review)

The user's criterion (2026-10-13): review what "consume[s] resources and [it is] impossible [to] get full
resources back, irreversible". Everything below changes a setting the next sentence can undo, costs nothing,
and had zero recorded harm in 1,680 logged orders (router logs 2026-10-03..13) and 20 play notes:

- every question;
- schedule changes; work priorities and `stop PAWN doing WORK`;
- clothing / food / drug / reading / medicine group assignment, fire at will, combatmode (`set combatmode
  auto-engage|flee|ignore for PAWNS.`, the game's threat response), bed assignment (not bed role);
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
| Any build, room, floor, furniture, spot placement, `build roof at AREA using PAWN.` | every user hand-correction in the notes was a placement; materials are not fully returned. "planning/building should also be accepted by orchestrator after making a plan layout & where it wants to build (probably direction given by orchestrator)" |
| Bills (add, change count, ingredients) | user: "specialists relay bills (e.g. im making 5 clothes because...) to orchestrator and orchestrator can accept/deny/edit". Relay first, then the specialist sends it `raw apply` (user chose this over holding a plan). |
| Slaughter, hunt, attack, capture, arrest, surgery, prisoner mode | irreversible or a pawn fight; the mod marks them RISKY |
| Deconstruct own building, cancel someone else's blueprint, delete zone | materials or work lost |
| Widen an area restriction (`anywhere`, `unrestricted`), hauling or mining far from base (`prioritize`, `mine near`, `mine nearest`, `mine ... near`, `mine ... in area`, `haul from`, `haul ... near` outside the base), map-wide unforbid | every recorded hypothermia case came from one of these |
| Bed role (medical, prisoner) | drops the bed's owner; user stopped one on day 11 |
| `accept trade`, caravan or aid requests, quest and letter choices beyond Close | **orchestrator only, never proposed by a specialist** (user: "3 can only be done by orchestrator") |

Draft and move are the drafter's own (section 5) but **attack** is gated.

## 3. The round, and how a specialist talks to the orchestrator

A specialist is one `Agent` call that loops:

1. Read `delegates\COMMON.md`, its own brief `delegates\briefs\<name>.md`, its notes
   `delegates\notes\<name>.md` (its own memory across rounds and calls), and the newest `play_sessions\day_NN.md`.
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
   `MESSAGE` → read `delegates\msg\<name>.md`, delete it (`clear.ps1 -Msg <name>`), act. `HOURS` / `EVENT` / `TIMEOUT` → next round.
   `[REMINDER] Hourly check N` → read the batch, act on what is yours (only the orchestrator votes).
6. After at most 8 rounds in one call, return with a report anyway (context).

The orchestrator answers a proposal by resuming the specialist with `SendMessage` (the same agent, its context
kept): `P3 approved, send it`, `P3 denied: <why>`, or `P3 edited: <sentence>; send that`. For a build the
orchestrator sends the order itself and tells the specialist what now stands where. `list buildings.` lists
what the colony can build now, by category; `list CATEGORY.` one category (`list production.`). Every new bill
names its pawn: `add bill to make COUNT RECIPE at BENCH in ROOM using PAWN.`; `list bill PAWN has.` gives that
pawn's bills with their IDs, `delete BILLID.` deletes one; `what can PAWN create.` lists what the pawn can make.
Packed items (user, 2026-10-17): `build NAME` (`install` is the same) first lists the packed NAMEs on the map with
their IDs; `build ITEMID at X, Z.` installs one, `build new NAME at X, Z.` builds a new one instead. An uninstall that
matches several things lists them with IDs; `uninstall ITEMID.` takes one. Rooms (user, 2026-10-17): `show ROOM stats.`
gives each room of that name with its room ID (`Room412`), buildings, impressiveness, beauty, cleanliness, space,
wealth, which of them matter for it, and its bills; `build FLOOR for ROOM.` floors the whole room (the plan gives the
cost and the stats after); `cancel floor for ROOM.` cancels its floor plans and removes its built floor (the plan gives
what comes back). A room ID changes when the game loads or the room's walls or doors change. A room with a
hydroponics basin is named `growroom` everywhere (`show growroom stats.` lists each one with its ID). Every 12 game hours
a `[REMINDER] 12-hour check (rooms)` block lists each room: stats, the stats that matter, bills, and for every floor the
colony can lay its cost and the beauty, cleanliness and impressiveness after (affordable floors first). The orchestrator stops a
specialist with the file `delegates\stop\<name>` (or `stop\ALL`), or `TaskStop`. Lift a stop with
`powershell -File "<skill folder>\clear.ps1" -Stop <name>` (or `-Stop ALL`): the hooks allow no Remove-Item.

## 4. The orchestrator's own loop with specialists running

- Launch subagents before unpausing (user, 2026-10-16): at the start of a session and after a compaction,
  spawn the roster (starting order at the end of this section) while the game is paused; set the speed only
  after the last one is spawned.
- Keep the game running. Specialists' free-class orders no longer pause it. Pause for your own tasks only
  (notes, reviewing proposals that need thought), and unpause after.
- Your plan/apply pairs still pause while the plan waits; `send.ps1` makes a specialist that collides with it
  wait and retry (up to 120 s), so finish a pair promptly.
- Speed, windows and letters stay yours. Specialists never touch them.
- Pawns watch (user, 2026-10-17: "The agent orchestrator doesnt know if pawns are being actively attacked/chased."):
  `pawns_watch.ps1`, armed with Monitor next to `watch.ps1` (SKILL.md step 2c), prints every colonist, slave,
  prisoner, guest, visitor, trader, ally and other non-hostile pawn with health, conditions and recovery estimates,
  gear held and carried, medicine and combatmode, again on any change (1% steps) or a move of 3 cells; `NAME being
  attacked by SOURCE`, `NAME being chased by SOURCE`, `NAME being engaged in melee on X, Z from shooting, being
  attacked by SOURCE` (a ranged pawn in melee: shooting does not work at that range; move them out or fight back) and
  the line when it ends; `PAWN LEFT` with why (died, recruited, left the map, ...). Act on an attack line at once.
- `HOSTILES ON MAP: ...` (pawns watch): spawn the hostile_watch specialist (section 6, `briefs\hostile_watch.md`)
  if it is not running, while you deal with the threat. It watches `hostiles_watch.ps1` and returns to you with a
  report on every new enemy, every enemy attacking, chasing or within 10 cells of one of ours, every enemy downed or
  gone; resume it with `SendMessage` (`go on watching`) after you acted. It ends itself on `HOSTILES GONE`.
- Hourly check (user, 2026-10-19: "the 1-hour reminder does not need specialist voting. I dont trust haikus to vote
  intelligently."): the game stays paused until you have voted; specialists get the batch but do not vote. On
  `Hourly check N` (watcher or a result): read the batch, act, then
  `powershell -File "<skill folder>\vote.ps1" -Name orchestrator -Check N`.
- Compaction (user, 2026-10-18/19): when its conditions are met (a new 2-day cycle with both day notes of the last one
  written, or the context limit with today's note appended to), every game order is refused with `conditions are met
  for compaction. if you are an orchestrator, vote for compaction.`, and that line rides on every tool result. Vote:
  `powershell -File "<skill folder>\vote.ps1" -Name orchestrator -Compact`. It pauses the game, puts down
  `delegates\stop\ALL` (every specialist writes its status note and returns), and returns when the notes are in or
  after 30 s. Then end your turn. Before the context limit, a hook line names the day note to append to.
  Rotting food lines in it (2026-10-17): `[ITEM, QTY] is being rotten in ROOM (RoomID)` (indoors: build a fridge room) and
  `... outdoors in (x, z) to (x, z)` (a 10x10 square). `haul ITEM.` then sends colonists to that square: the mod asks
  which pawns (with hours to get there), answer with names; forbidden items there are unforbidden. With nothing of
  that item rotting outdoors, `haul ITEM.` only marks items for hauling, as before.
- Play decisions are yours too: never put one to the user as a question. Asked "hunt the megasloth with Zimmerman?"
  with options, the user answered "[cannot] I cannot make decision for the orchestrator." (2026-10-14). Weigh it,
  choose, act, and write the choice and why in the day note.
- The `[REMINDER] 6-hour check` block in `answers` / `reasons` (and the `reminders` field; one entry, the reminders
  numbered inside it) is yours: every 6 game hours the mod
  lists work spots and benches whose place costs work speed (outdoors, cold, wrong room), benches whose interaction
  spot has under 50% light (build a lamp), labeled rooms under 10C or over 35C (heater / cooler, or a vent to a
  better room next door), stone chunks lying indoors (`move chunks.` moves all stone chunks inside rooms to stockpile, if there is one, to make rooms prettier), and steel / components / plasteel
  on the map (forbidden, outside storage, compacted rock to mine, ship chunks to deconstruct, ancient wrecks to shoot
  for steel slag, slag to smelt) while that count is 0 or below what your bills and blueprints still need (none on
  the map: trade, strip-mine into mountains, or research a scanner / deep drill), and a stove while only a campfire
  cooks (better meals; on a map with no trees it saves wood), a heater while a campfire is the only heat source on a
  map with no trees (`build heater near X, Z.`), a stove or campfire with a simple meal bill but no
  "cook simple meal x4" bill (bulk saves trips; the line gives the bill to add), too few usable benches (fuel, power) for the colonists
  set to a work at the same hours (cooking, research, art, tailoring, crafting, smithing: add a bench or move a
  schedule), stone chunks in a stockpile with no stonecutter's table, and two or more blueprints / frames waiting
  (`prioritize constructing at X, Z with NAME.` puts a pawn on the one that matters first), and colonists with
  Construct / Grow / Plant cut on who fail 10% or more of builds or harvests by the game's own chance (skill, health),
  builds that actually failed since the last check (the game's own "failed while constructing" messages, by worker,
  with skill and health),
  with who does it better (`set WORKTYPE priority 1 for NAME.`, `stop NAME doing WORKTYPE.`), and doctors who carry
  no medicine (or can't refill the kind set) while some is in storage (`set carry medicine of NAMES to N MEDICINE.`,
  N up to 3), an unarmed colonist who shoots (or fights melee) better than the weakest holder of a ranged (melee)
  weapon (`have WEAKEST drop WEAPON.`, then `equip BEST with WEAPON.`), places a micro order left resources at
  ("X, Z has ... from mining. say "haul from X, Z"": `haul from X, Z with PAWNS.`, the expediter's inside the base,
  gated outside it); and always, last, a "[TIP]" that a missing pawn-menu option may need the pawn drafted first (draft,
  look, undraft when done). Every 3 game hours
  (joining the 6-hour block, or alone as "[REMINDER] 3-hour check"): growing zones or hydroponics basins with cells
  growing nothing or plants not growing, with the reason per cell (sowing off, no power, too cold, blocked, waiting
  to be sown: `prioritize sowing at X, Z with NAME.`; mature plants waiting for harvest count too), and "[ALERT]"
  items in a stockpile zone whose durability dropped since the last 3-hour scan while an indoor room exists (move
  them indoors). Once a game day
  also doors that
  make the colonists walk far ("I noticed your pawns spend N tiles ... placing the door on (x, z) instead should
  save about M tiles", measured from their own walks; it is an estimate, weigh it against the wall and door work),
  and after you moved such a door, whether trips through the new one run slower than its path should ("Maybe you
  have things slowing pawns down": look for furniture, rough floor or a slow door on the way). At once, not at the
  6-hour mark, a colonist on a mental break that you could arrest while no prisoner bed exists ("Mental break
  check": place a sleeping spot in a closed room, `set every bed in ROOM to prisoner.`, then `arrest NAME with DOER.`),
  and a downed stranger who is bleeding, with the game's time until they bleed out ("Bleeding check": `use option
  rescue on X, Z with PAWN.`; a tip also says a pawn can be tended on the spot first), and a merchant who steps into
  your home zone ("Merchant check": `use option trade on NAME with PAWN.`, the colonist with the best Social named).
  It gives the list once, on your next speed, run, letter, window, trade or build result (user, 2026-10-14). Act on
  them or say why not in the day note; never filter them.
- Micro orders (`mine near`, `haul from`; `briefs\expediter.md`) give their news with the next result of any order:
  `task finished, pawns coming back, est. N hr with ...`, `hauling done, pawns coming back with ...`, `More ... is
  left at ...`, `roofing done at AREA by PAWN: ...` (`build roof at AREA using PAWN.`), and `X, Z also has ... Reply mine to mine it too, or cancel to haul.` (the game is paused until
  `mine` or `cancel`; answer it yourself when a specialist returns with it).
- Each specialist's `status\<name>.md` is one glance; read them at each day turn and put a line per specialist
  in the day note. Delete stale `msg\` files you wrote before they were read if the plan changed (`clear.ps1 -Msg <name>`).
- Bills in the day note (user, 2026-10-17: "daytoday handoff from now, include every bill the colonist currently has
  in there."): at each day turn, send `list bill NAME has.` for every colonist and copy each answer, IDs included,
  under the colonist's name in `play_sessions\day_NN.md`. The mod also writes them every game hour to
  `<SaveData>\VerbalCommands\bills.md`; a hook (`bills_hook.ps1`) puts that file into your context after your next
  tool call whenever it changed, and again after a compaction.
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
| storage_zones | filters and priorities of existing storage; `move chunks.` (moves all stone chunks inside rooms to stockpile, if there is one, to make rooms prettier); proposes new zones | 12 h | `briefs\storage_zones.md` |
| hostile_watch | the hostile list (`hostiles_watch.ps1`): reports enemies, their weapons, health and targets; questions only. Spawned on `HOSTILES ON MAP`, ends on `HOSTILES GONE` (user, 2026-10-17) | every change of the hostile list | `briefs\hostile_watch.md` |
| expediter | `prioritize WORK at X, Z with PAWN` inside the base: material to blueprints, builders to frames, miners to marks (user, 2026-10-13); the micro orders `mine near X, Z with PAWNS.`, `mine in area AREA with PAWNS.`, `haul from X, Z with PAWNS.`, `mine nearest [COUNT] THINGS near X, Z with PAWNS.`, `mine THINGS near X, Z with PAWNS.`, `mine THINGS in area AREA with PAWNS.`, `haul THINGS near X, Z with PAWNS.` inside the base (user, 2026-10-16) | 2 h | `briefs\expediter.md` |

## 6. Spawning (what the orchestrator types)

```
Agent({ subagent_type: "general-purpose", model: "haiku", effort: "high",
  description: "RimWorld schedule specialist",
  prompt: "You are the schedule specialist for a RimWorld colony played through the VerbalCommands inbox.
    Read <mod folder>\Skill\delegates\COMMON.md first, then <mod folder>\Skill\delegates\briefs\schedule.md,
    then <SaveData>\VerbalCommands\delegates\notes\schedule.md if it exists, then the newest
    <SaveData>\VerbalCommands\play_sessions\day_NN.md (write both folders out in full). Follow COMMON.md's round exactly. Orchestrator's standing direction for this call:
    <one or two lines: current goals, pawns to secure, anything the specialist must not touch today>." })
```
The same for each name. Keep the direction line current: it is the only thing the specialist knows about
your plans beyond the day note.
