# Playbook: how to play RimWorld through the VerbalCommands mod (for the playing Claude)

This is a manual for the instrument, not a guide to the game. You get no screen of your own: no OCR, no
desktop capture, no dev mode. Everything you see and do goes through the mod's files; a picture of the
colony is one of them (section 6, "Pictures"). Expect to find things that do not work and
report them (section 9).

`<mod folder>` below is where the mod is installed (`...\RimWorld\Mods\VerbalCommands`, or the Workshop
copy under `...\steamapps\workshop\content\294100\<id>`); `<skill folder>` is
`%USERPROFILE%\.claude\skills\rimworld-play` (the copy of `<mod folder>\Skill\rimworld-play`).

The start: Crashlanded, 3 colonists, any playable map. Difficulty: Randy Random, Losing is Fun (what that
means: `<mod folder>\Skill\DIFFICULTY.md`).

What to do with the instrument (defending, a killbox, answering events, digging in) is in
`<mod folder>\Tips\`: start at `Tips\INDEX.md` whenever an event comes up and you are not sure what to do.

Required reading before the first order, every session:
`<mod folder>\Skill\reference_play\REFERENCE_HUMAN_PLAY-Autosave-5.analysis.md`, the mod author's own 54-day
play of this kind of start, read day by day with the reasoning. Its header also holds the end-of-day note
rule (section 4 below).

## 1. Switch it on (the human does this once)
Mod settings -> "Agent inbox: take orders from text files in the inbox folder" (off by default). The human
also sets the API key there. Never open the game's `Config` folder or the saves: the key is in `Config` in
plain text.

## 2. Folders
`<save data>` = `%USERPROFILE%\AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios`
- `<save data>\VerbalCommands\inbox\` : you write orders here.
- `<save data>\VerbalCommands\inbox\taken\` : taken files are moved here.
- `<save data>\VerbalCommands\outbox\` : one `<same name>.json` per taken file.
- `<save data>\VerbalCommands\inbox_state.json` : what the inbox is doing now. Whether the game is running is
  not read from it: `send.ps1` sends nothing while RimWorld is closed (`NOT RUNNING`). It also carries
  `events` (the last 20 AgentEvents entries: seq, when, kind, text) and `last_event_seq`, and the mod
  rewrites it whenever a new event comes, not only on a pause or a speed change. The skill's `watch.ps1 -Feed`,
  started in the background, writes each new entry to a feed file, and `next.ps1` hands the new lines to the agent
  as its own result (since 2026-10-19, SKILL.md step 2b; before, under the Monitor tool).
- `<save data>\VerbalCommands\logs\router_<date>.jsonl` : everything the router did (you may read it).

## 3. One order, start to end
1. Write `inbox\0007_name.tmp`, then rename it to `0007_name.txt` (only `*.txt` is taken; names that sort).
2. First line may be a header: `mode: raw`, `mode: dry`, `mode: apply`, `mode: raw apply` ...
   - `raw` : the rest is router sentences, parsed as they are, no Haiku call. Use this for everything you
     can write yourself; it is exact and costs nothing.
   - no `raw` : the rest is plain language; Haiku turns it into router sentences (it can ASK or say CANNOT).
   - `dry` : plan and report, never apply. `apply` : apply at once. Neither: the plan waits.
3. Read `outbox\0007_name.json`. `result` is one of: `answer` (questions answered, see `answers`),
   `planned` (a plan waits: see `plan_lines`, `notes`, `risky`), `applied` (see `actions`: done or refused,
   with the reason), `dry_run`, `nothing_to_change`, `ask` (see `question`), `cannot`, `failed`, `problem`,
   `cancelled`, `rejected` (see `reasons`).
4. A plan that waits: send a file whose whole text is `apply` or `cancel`. A question that waits: send the
   answer as a plain file, or `cancel`.
5. An order is all questions or all changes; a mix is refused as a whole.
6. The inbox pauses the game when it takes a file and never unpauses it. Time moves only when you say so.

## 4. Time
- Never `run N hours.`, `run N days.` or `run until event.` (mod author: "never run play for x hour",
  "you can only unpause/pause, play at 1x/2x/3x speed"). An earlier agent session sent 63 runs; they sat on
  hold behind windows it had left open (a research-finished box 5 times, a comms call it opened itself, the
  escape menu), and 7 times it sent a new run on top of one that was on hold ("replaced by a new run").
- Time moves only with `set game speed to normal.` (1x), sent with `mode: raw apply`. 2x and 3x are not
  allowed (user, 2026-10-16: "STOP AGENTS PLAYING RIMWORLD PLAY TO RUN AT 2X SPEED AND 3X SPEED."; a hook blocks them).
- The agent never pauses the game unless necessary, e.g. busy doing tasks like writing memos, checking game
  status, reading memos, delegating tasks to other agents. Earlier rule it replaces: "Game should *not* be
  paused by you (it already pauses itself for most message events)." So: `set game speed to paused.` only
  for such a task, and unpause as soon as it is done; never leave the game paused while idle or waiting.
- One such task, required: at the end of every game day (hour 0 of the next), pause with `set
  game speed to paused.` (`mode: raw apply`), write `<SaveData>\VerbalCommands\play_sessions\day_NN.md` (what you did today;
  short-term goal and why; long-term goal and why; which pawns to secure and the reasoning; one line against
  the human's same day in `reference_play\...analysis.md`), then `show windows.`, close what holds the
  pause, and set the speed again. Template at the top of the reference file.
- Before starting another day, read the previous day's note(s) in `play_sessions\day_NN.md`: at session start
  the newest two at least, and at every day turn the one just before the note you are writing. Check the
  new note against it; a goal dropped or a pawn no longer secured is said, with why.
- Before you unpause: `show windows.`. Close whatever holds the pause first (`close window.` or `close window
  with option WORDS.`), in an order of its own, and read its result; then the speed order. If the speed
  order's notes say a window holds the pause, the game did not move: close that window, do not send the
  speed again.
- While the game moves, wait without sending: `next.ps1` (since 2026-10-19, skill step 2b) hands you every new event
  from the watcher, every change of what the inbox waits for, and every stop/start since your last call; no
  polling by hand. The fields, if you ever read the file yourself: (`paused`, `speed`, `tick`; 2500 ticks
  = 1 game hour). Then one combined check (`show speed. show events. show status.`).
- `show speed.` (date, hour, speed, why the last run stopped), `show events.` (what happened since you last
  asked), `show events since day N.`, `show pending.` (what your orders started that is not finished).
- After every stop: read `show events.` and `show status.` before giving orders.
- Every order the mod takes pauses the game, questions included. No background task that sends a check
  after a sleep. Parse `<save data>\VerbalCommands\inbox_state.json` as JSON (a case-insensitive text match
  on "paused" also hits `"paused": false`). About 1k context tokens per game hour was the measured cost;
  one unpause and one check per stretch of play is the target.

## 4b. Your context window
- Your context window is 200k tokens.
- Your current context: `token_meter.agent_context_tokens` in `<save data>\VerbalCommands\inbox_state.json`
  (the mod reads it from your own session transcript after each order; `token_meter.agent_session` names the
  session). Read that one field (parse the JSON), not your transcript.

## 5. Places (a fresh map has no rooms)
- SPOT, one cell: `112, 87` (x grows east, z grows north, 0, 0 is the south-west corner), a name (a
  colonist, prisoner, colony animal, an entry of the `landmarks` or `zones` vocabulary line, a room), or
  `6 tiles north of Bob`.
- AREA, a rectangle: `100, 80 to 120, 95` (two corners, both included) or `10 by 10 around SPOT`.
- Every answer prints a cell as `112, 87 (6 tiles north of Bob)`: copy the numbers into the next order.
- You never get anything under fog, and you can not order anything under fog, except digging: `dig room` marks fogged cells inside for mining, as a player's drag does (see mining.md).
- Only numbers that stand in your order are accepted; a made-up coordinate or size is rejected.
- Go by names, as a human does: landmarks (`steam geyser 2`, `ship chunk 1`), `where is nearest steel.`, the
  colonists. Use them as SPOT (`build ... near steam geyser 2.`) and let the plan, or its refusal, give the exact cells
  (user, 2026-10-19: "you dont need entire goddamn cell by cell of mountain. humans dont play like this").

## 6. Seeing
- `show questions.` and `show orders.` list every sentence the mod knows, with one line each. `show orders
  for build.` lists the ones that start with a word. Ask these first; they are generated from the router's
  own table, so they are never out of date.
- The colony: `show status.` (the whole picture), `show colonists.`, `show needs of PAWN.`,
  `show health of PAWN.`, `show mood of PAWN.`, `show skills of PAWN.`, `show work.`, `show schedule.`,
  `show gear of PAWN.`, `show settings of PAWN.`
- What holds the game paused (a research-complete box, a message, a trade window; a speed order comes back applied and the 
  tick does not move): `show windows.` lists them top first with their text and buttons; `show speed.` names the one that holds the pause.
- Danger: `show threats.` (a bunch standing together is told as one group: its nearest member, the box round
  it, what it holds), `show alerts.`, `show letters.`
- Stores: `show food.`, `how much steel do i have.`, `show power.`, `show temperature.`, `show weather.`
- The map: `show map.` (coarse), `show terrain map around Bob.` (41 by 41 detail), `show roof map of 100, 80
  to 140, 110.`; layers: terrain, resources, buildings, roof, creatures. `where is nearest steel.`,
  `where is nearest berries to steam geyser 1.`, `where are ship chunks.`, `list mountains on map.` (a
  drawn picture of the whole map, `map.png`: rock, ore, snow, walls, stockpiles, colonists, animals, geysers,
  tagged, with every tag's name and cell in the text; it pauses the game: read it, then unpause; user,
  2026-10-19: "if they say "list mountains on map", then the game just takes picture of the entire map instead.").
- Pictures: `show picture around SPOT.` (the game's own view, 41 by 41 cells centred on SPOT) and
  `show picture of AREA.` (centred on the middle of AREA, zoomed so all of it is in the frame). Examples:
  `show picture around 120, 135.`, `show picture around Bob.`, `show picture around steam geyser 1.`,
  `show picture around 6 tiles north of Carl.`, `show picture of 100, 80 to 140, 110.`,
  `show picture of 30 by 30 around Bob.` The answer names the PNG (`picture.png` in the outbox folder); it
  appears once the game has drawn the frame, then open it with the Read tool. North is up; the game's UI is in
  it, cell numbers are not. If it does not come, `failed to make picture_png.md` in the same folder says why.
- What you set up: `show zones.`, `show areas.`, `show blueprints.`, `show bills at BENCH.`,
  `show storage of zone Stockpile zone 1.`, `show building campfire.`, `show designations.`,
  `show wildlife.`, `show research.`, `show research path to PROJECT.`

## 7. Doing (one example each; `show orders.` has all of them)
- Zones: `zone stockpile in area 8 by 8 around Bob.`, `zone growing rice in area 100, 80 to 109, 89.`,
  `zone dumping in area ...`, `set crop of zone Growing zone 1 to corn.`, `put only meals in zone Stockpile
  zone 1.`, `set zone Stockpile zone 1 to critical priority.` A zone made in one order has its name only in
  the next (`show zones.`).
- Areas: `area home add 40 by 40 around ship chunk 1.`, `create area safe over AREA.`,
  `restrict Bob to area safe.`
- Marking work: `chop trees near Bob.`, `harvest berries.`, `mine nearest steel near Bob.` (its whole
  vein, only what you can see), `mine everything in area AREA.`, `deconstruct nearest ship chunks near ship
  chunk 1.`, `haul ...`, `hunt deer.`, `tame ...`, `cancel all mining.`, `unforbid items near ship chunk 1.`
- Building: `build campfire near Bob.`, `build bed at 120, 88 facing north.`, `build wall from 10, 20 to
  10, 30.`, `build floor wood floor in area AREA.`, `cancel blueprint at SPOT.` BUILDING comes from the
  `buildings` vocabulary line, FLOOR from `floors`.
- Rooms. You choose the place; the mod never picks it.
  - `build room 7 by 7 around 120, 88 made of wood door south.` : an empty box of walls with one door. AREA
    is the outside, walls included.
  - `build bedroom AREA.`, `build barracks AREA with 3 beds.`, `build kitchen AREA.`, `build dining room
    AREA.`, `build research room AREA.` : the same box with its furniture, laid out by the game's own
    placement rules (bed heads at a wall, end tables where they link, worker spots free and reachable).
    The plan lines name every piece and its cell; read them before you apply.
  - `dig room AREA door east.` : a room dug into rock: rock inside is mined, rock at the edge stays as wall.
    Find rock with `list mountains on map.` (the whole-map picture) and `show roof map ...`. Furnish it later with the build lines.
    A dug area more than 12 cells both ways keeps columns of rock (one every 9 cells, named in the plan
    notes), in `dig room` and in `mine ... in area AREA` alike: a roof more than 6 cells from any wall or
    rock falls in. Do not mine the columns out.
  - Roofs: colonists roof a closed box of walls by themselves. The plan notes say when they will not (too
    big, a cell more than 6 tiles from any wall). Roof orders are only for the special cases:
    `area roof add AREA.` (build roof), `area no roof add AREA.` (remove roof and keep it open, for example
    a walled farm), `area roof remove AREA.` / `area no roof remove AREA.` (clear those marks).
- A window that holds the pause: `close window.` presses the only button of the top one. With several choices it refuses and lists them;
  name one with `close window with option WORDS.` (the research box has two: `close window with option ok.`). It never closes the trade window
  (`cancel trade.` does) and never the mod's own window.
- Colonists right now: `draft Bob.`, `move Bob to 112, 87.`, `attack raider 1 with Alice and Bob.`,
  `attack nearest enemy with everyone.`, `rescue Bob.`, `tend Bob with Alice.`, `capture raider 2 with
  Carl.`, `extinguish fire near Carl.`, `prioritize hauling at 120, 88 with Bob.`, `equip Carl with rifle.`,
  `have Alice wear parka.`, `have Bob pick up 3 herbal medicine.`, `have Alice rest.` Enemy names come from
  the `hostiles` vocabulary line; `(down)` there means downed.
- Other people and trading: `show interactable pawns.`, `use option trade on NAME with PAWN.`, then at the
  trade window `show trade.`, `trade buy 20 components.`, `trade sell 300 steel.`, `accept trade.`
  (`Tips\trade.md`).
- Standing settings: work priorities (`set Cooking priority 1 for Carl.`), schedules, bills
  (`add bill to make cook simple meal forever at fueled stove.`), research (`start research PROJECT.`),
  food / clothing / drug groups, medicine, beds, doors, temperature, prisoners, animals. See `show orders.`

## 8. RISKY
A plan whose outbox says `"risky": true` can kill, destroy or lose something: attack, capture, arrest,
drop, deconstruct, slaughter, hunting an animal that may turn on the hunter, prisoner mode execute or
release. Read the plan lines before `apply`; do not send these with `mode: apply`.

## 9. When something does not work
- A sentence that should parse and does not: the outbox `reasons` say what it came closest to and why. The
  forms and their checks are in the shared rules block of `<mod folder>\Router\router.txt`. Changing them
  needs the mod's source tree (see `<mod folder>\README.md`), not the installed copy: say to the user what
  is missing and what you would change.
- The mod does the wrong thing in the game: quote the order, the outbox JSON and the `[VerbalCommands]`
  lines of `Player.log` to the user. The C# lives in the source tree (`Agent*.cs`, one file per area, and
  `Form*.cs`); a build that deploys to the game runs only on the user's word, never while the game runs.
- Never change the interpreter itself (`RouterScript*` in the source tree).
- No dev mode, ever. Nothing is spawned, finished, healed or moved by the mod; colonists do the work.

## 10. What the mod still can not do
Known gaps: your own caravans and the world map, a list of quests, ideology and royalty screens, cover and
line of sight, naming a standing building as a SPOT (use its cell), landmarks for ruins and lakes, storage
orders on a zone made in the same order.
