---
name: rimworld-play
description: Play or operate the user's running RimWorld game through the VerbalCommands mod's sentence interpreter only - router sentences sent to the mod's inbox in raw mode, answers read from its outbox. Use when the user asks to play RimWorld, give the colony an order, ask the game a question ("what's my power", "who can I trade with"), run game time, or test the mod live. The agent acts ONLY through the interpreter; it changes the mod, the router rules or the prompt only when the interpreter can not give what is needed.
---

# RimWorld through the interpreter

Two folders are named below:
- `<mod folder>`: where the VerbalCommands mod is installed (`...\RimWorld\Mods\VerbalCommands`, or for the
  Workshop copy `...\steamapps\workshop\content\294100\<id>`). It holds `Tips\` (know-how) and `Skill\`
  (the playbook, the reference play, and the copy of this skill).
- `<skill folder>`: this file's folder (`%USERPROFILE%\.claude\skills\rimworld-play`). It holds the scripts
  `send.ps1` (one order in, its result out), `play.ps1`, `watch.ps1`, `launch_game.ps1`, `launch_play.ps1`,
  `resume_hook.ps1`.

## The one rule
Everything you see and do in the game goes through the interpreter: a router sentence, sent to the mod's
inbox, parsed by `router.txt`, answered in the outbox. Nothing else touches the game:
- no key or mouse input, no computer-use or desktop capture. A picture of the colony comes from the mod,
  with two questions:
  - `show picture around SPOT.`: the game's own view of the 41 by 41 cells centred on SPOT, no cell numbers;
  - `show picture of AREA.`: the game's own view of exactly the cells of AREA, with its x and z drawn on every tile.
  SPOT: `X, Z`, a colonist, animal, landmark or zone name, or `N tiles DIRECTION of NAME`. AREA: `X, Z to X, Z`
  or `W by H around SPOT`. Examples: `show picture around 120, 135.`, `show picture around Bob.`,
  `show picture around steam geyser 1.`, `show picture around 6 tiles north of Carl.`,
  `show picture of 100, 80 to 140, 110.`, `show picture of 30 by 30 around Bob.`
  The answer names the PNG (`picture.png` in the outbox folder); it appears once the game has drawn the frame,
  then open it with the Read tool. The game's UI is hidden for the shot and the picture is cut to exactly those
  cells; north is up. A picture is refused while any game window is open (close it first). If it does not
  come, `failed to make picture_png.md` in the same folder says why;
- no dev mode, no save editing, never open the game's `Config` folder (the API key is there in plain text)
  or the saves; never start, stop or signal the RimWorld process;
- `Player.log`: only lines starting `[VerbalCommands]`. The mod's `VerbalCommands\logs\router_*.jsonl` may be
  read.

The one exception (the mod author's words: "it can only do something by reaching interpreter, unless direct
manipulation needs to be done, to say, build something ... if its not getting what it needs"): when the
interpreter can not do or show what you need, you may extend the instrument itself. See "When the
interpreter falls short". That is a change to the mod, never a way round it.

## Before the first order
1. Read `<mod folder>\Skill\PLAYBOOK.md` (how the inbox, time, places and sentences work) and
   `<mod folder>\Tips\INDEX.md` (what to do with them: defense, events, mining, people, trade,
   furniture, power). Open a know-how file when its question comes up, not all of them up front.
1b. Read `<mod folder>\Skill\reference_play\REFERENCE_HUMAN_PLAY-Autosave-5.analysis.md` in full, every
   session (user, 2026-10-12). It is the mod author's own 54-day play of the same kind of start, day by
   day with reasoning, and it carries the end-of-day note rule (loop step 6).
1c. User, 2026-10-16: "models may not read reference playlog unless user explicitely allows it."
2. If `send.ps1` answers `NOT RUNNING`, RimWorld is closed and nothing was sent: tell the user to start the
   game, load the colony and tick "Agent inbox" in the mod settings. Do not go on without it.
2b. **Start the watcher** (user, 2026-10-19: "do find a way to get rid of system notification - not user input."),
   once, in the background (PowerShell tool, `run_in_background: true`):
   `powershell -File "<skill folder>\watch.ps1" -Feed`. It writes every new game event (letter,
   message, pawn state), every change of what the inbox waits for, and every stop/start of the game to a feed
   file, with nothing sent to the game. **Read the feed with `powershell -File "<skill folder>\next.ps1"`** (PowerShell
   tool, foreground, `timeout: 600000`) whenever you wait for the game: it returns every line written since your
   last call, or waits until one comes; after 9 minutes with nothing it returns `NOTHING NEW` (call it again).
   Start the watcher again after it prints `NOT RUNNING`. Act on an `EVENT` or `WAITING ask` line as you would
   on a `show events.` answer.
   Before 2026-10-19 the watcher ran under the Monitor tool (user, 2026-10-12: "make it so that inbox_state.json's
   new messages get injected as prompt onto agent, not based on -run or based on whether they paused/changed
   speed."). Reason for the change, not the user's words: each Monitor notification carried about 170 tokens of
   Claude Code's "[SYSTEM NOTIFICATION - NOT USER INPUT]" text; a tool result carries none.
   On `Hourly check N` (from the watcher, once per check): read the batch, act, then vote: `powershell -File "<skill
   folder>\vote.ps1" -Name orchestrator -Check N`. The game stays paused until you have voted (only the
   orchestrator votes).
2c. **Start the pawns watch**, once, in the background next to the watcher (since 2026-10-19; before, under the
   Monitor tool): `powershell -File "<skill folder>\pawns_watch.ps1" -Feed`; its lines come with `next.ps1` too
   (step 2b). What it is for (user, 2026-10-17: "The agent orchestrator doesnt know if pawns are being actively
   attacked/chased. Solution: A perpetually opened shell that only updates/notifies agent if the values change.").
   It prints two tips, then every
   pawn (colonists, slaves, prisoners, guests, visitors, traders, allies, strangers, colony and wild animals) with
   health, pain, bleeding, capacities, conditions with recovery estimates, gear held and carried, medicine and
   combatmode, and again whenever a value changes (1% steps) or the pawn moves 3 cells; `NAME being attacked by
   SOURCE`, `NAME being chased by SOURCE`, `NAME being engaged in melee on X, Z from shooting, being attacked by
   SOURCE`, and a line when each ends; `PAWN NEW` / `PAWN LEFT` (with why). Leave out categories with `-Skip "wild
   animal"` (wildcards; `-Only` for the reverse; the categories are listed at the top of the script). Start it again
   after it prints `NOT RUNNING`. On `HOSTILES ON MAP` spawn the hostile_watch specialist
   (`delegates\ORCHESTRATOR.md` section 4); `hostiles_watch.ps1` is its shell (run by hand it exits at once with
   `NO HOSTILES` when nothing hostile is in view).
3. First order: `show status.` The sentences are in PLAYBOOK.md sections 6-7, already read: ask `show orders for
   WORD.` only for one the docs lack or the mod refused (user, 2026-10-19: "you should have gotten that memo from
   first time."; a hook refuses `show orders.` and `show questions.`).

## Sending
```
powershell -File "<skill folder>\send.ps1" -Text "show status."
powershell -File "<skill folder>\send.ps1" -Text "build campfire near Bob." -Mode "raw dry"
powershell -File "<skill folder>\send.ps1" -Text "set game speed to normal." -Mode "raw apply"
powershell -File "<skill folder>\send.ps1" -Reply apply        (or: -Reply cancel)
```
- On the session's first order add `-Model <your model id>` (e.g. `-Model claude-opus-5-5`; `play.ps1` takes it
  too). The inbox file names then carry your model, the harness and your session id, so the mod's token counter
  finds your transcript. Later orders reuse the name start; `-Model` is not needed again.
- A result can carry tips in `tips`: short tips from the know-how files that fit your order or what just happened.
  Reminders are in `reminders`. Each line is in a result once (user, 2026-10-19: "no duplicates."). For a whole file send `send.ps1 -Text "I need tips on <name>"`.
- `-Mode` default is `raw`: your text is router sentences, parsed as written, no Haiku call. Several
  sentences: one per line, or `. ` between them. Write `raw` always; plain-language mode (no `raw`) costs a
  Haiku call per order and is for testing the prompt only, on the user's word.
- A question (`show ...`, `where ...`, `who ...`, `how much ...`, `list ...`) is answered at once.
- A change comes back as `planned` with `plan_lines`, `notes` and `risky` (since 2026-10-19 there only when true). Read them, then
  `-Reply apply` or `-Reply cancel`. Use `-Mode "raw apply"` only for runs and for changes you have already
  seen planned once. Never `apply` blind on a plan marked `risky`.
- An order is all questions or all changes, never both.
- The script prints the outbox JSON on one line, with only the fields that say something (since 2026-10-19; user,
  2026-10-19: "how do you think you can get rid of them, without killing context outright."): a field that is not
  there is empty, `false` or `none`. `result`: `answer`, `planned`, `applied`, `dry_run`,
  `nothing_to_change`, `ask`, `cannot`, `failed`, `problem`, `cancelled`, `rejected`; `reasons` say why.
- Read the whole output. The 6-hour `[REMINDER]` batch comes once, on the result of an order only the
  orchestrator sends (a speed change, a run, a letter, a build), and is gone if that result is cut. Run only
  the scripts already in this folder, by full path: no wrapper scripts, no new scripts, no pipe, redirect or
  capture on a result; the PowerShell tool only calls these scripts. A hook blocks the rest (user, 2026-10-16).
- Numbers (coordinates, counts, sizes) must be in your sentence because you chose them from an answer; the
  router rejects a number that is not in the order.
- `move chunks.` moves all stone chunks inside rooms to stockpile, if there is one, to make rooms prettier (user, 2026-10-16). The mod always waits for `-Reply apply` or `-Reply cancel`.

## The loop
1. `show events.` and `show status.` (after every stop, before any order).
2. Decide; look up the know-how file if the situation is new.
3. Orders: plan, read, apply.
4. Never `run N hours.` / `run until event.` (mod author, 2026-10-08: "never run play for x hour", "you can only
   unpause/pause, play at 1x/2x/3x speed"). `show windows.` and close what holds the pause; then `set game
   speed to normal.` with `-Mode "raw apply"`: 1x only (user, 2026-10-16: "STOP AGENTS PLAYING RIMWORLD PLAY TO RUN AT 2X SPEED AND 3X SPEED."; a hook
   blocks `fast.` and `superfast.`). The agent never pauses the game
   unless necessary, e.g. busy doing tasks like writing memos, checking game status, reading memos,
   delegating tasks to other agents (user, 2026-10-12; earlier, 2026-10-09: "Game should *not* be paused
   by you (it already pauses itself for most message events)."). Pause for the task, unpause when it is
   done; never leave the game paused while idle. While it moves, call `next.ps1` (step 2b; since 2026-10-19) to hear what
   happens; do not poll `inbox_state.json` by hand or sleep in a shell. PLAYBOOK.md
   section 4. The end-of-day note (step 6) is one such task.
   Since the 2026-10-13 build the inbox itself pauses only while a plan or a question waits (user:
   "adding a bill or making a query shouldnt stop the game"); questions and `raw apply` orders are taken
   with the game running, and the speed comes back when the wait ends. Finish each plan/apply pair
   promptly: a waiting plan blocks every other sender.
4b. **A promise to act later needs an armed event** (user, 2026-10-15, after the agent wrote "will deal
   once they're closer" with nothing watching for it): whenever you write that you will act "once X", "when X" or
   "after X" and the watcher (step 2b) does not report X, arm `wait_for.ps1` for X in the same turn, with the
   PowerShell tool and `run_in_background: true` (one notification when X holds). Modes: `-Tick N` (day turns),
   `-Near NAME -X x -Z z -Within d` (a trader or visitor close to the base), `-Question "show ..." -Match REGEX`
   (research done, a frame built; `-NoMatch` for "gone"). Say which one you armed. A promise with no armed event
   is not allowed.
5. Keep your own short notes in the session of what you built where (cells), since the mod names no
   building you placed.
6. **End of every game day** (user, 2026-10-12): when the day turns (hour 0; `show speed.` or
   `inbox_state.json` tick, 60000 per day), pause with `set game speed to paused.` (`-Mode "raw apply"`),
   write `<SaveData>\VerbalCommands\play_sessions\day_NN.md` (NN counts from 1: the game's 1st day is 01) with: what you did today (orders, cells, refusals quoted);
   your short-term goal (1-3 days) and why; your long-term goal for the colony and why; which pawns you must
   secure and the reasoning (only researcher / doctor / builder / rifle carrier ...); one line comparing with
   the human's same day in the reference file; the WHY.md and README pointers. Before unpausing into the new day, re-read the previous
   day's note (`day_NN-1.md`) and check your new note against it: a goal dropped or a pawn no longer
   secured must be said in the new note, with why. Then `show windows.`, close what holds the pause, and
   set the speed again. Template at the top of the reference file.

## When the interpreter falls short
Order of preference:
1. Another sentence. `show orders for WORD.` and `show questions for WORD.` list what starts with a word;
   `use option WORDS on NAME with PAWN.` gives any right-click order the game offers.
2. Read the outbox `reasons`: "does not parse ... (looks like X, but ...)" tells you which form came
   closest and why. The forms and their checks are the shared rules block of `<mod folder>\Router\router.txt`.
3. Only then change the instrument, and say so to the user first with what is missing and what you will
   change. That needs the mod's source tree (the GitHub repository named in `<mod folder>\README.md`), not
   the installed mod: a wording the router should accept is a synonym row or a form in the router rules;
   something the mod can not do or show is C# in the mod's `Agent*.cs` \ `Form*.cs` files, compiled to a
   scratch folder first; a know-how gap is a `Tips\*.md` file. Rules for that work: the interpreter's own
   C# (`RouterScript*`) is never changed; a build that deploys to the game runs only on the user's word in
   that turn, never while the game runs, and the game must be restarted to load it; no git commit or push
   without the user's word; no Haiku test runs.
4. If it can not be done within those rules, stop and tell the user what is missing.

## Delegating to specialist subagents
User, 2026-10-13: colony functions run as Haiku 5.5 (high effort, changeable) specialists that act on
their own through the same inbox until you stop them. Read `<mod folder>\Skill\delegates\ORCHESTRATOR.md` before
unpausing (user, 2026-10-16), and before the first spawn. Spawn subagents before unpausing (user,
2026-10-16): at the start of a session and after a compaction, spawn the roster while the game is paused,
then set the speed. ORCHESTRATOR.md holds the roster (schedule, work_priority, drafter_mover, equipment_config, bills,
storage_zones), what each may apply without you (settings-type orders, nothing irreversible), what it must
propose instead (builds, bills, RISKY orders, far trips, bed roles; trade and letters are yours alone), the
spawn prompt, and how proposals come back (the specialist returns; you answer with `SendMessage`, or stop it
with `<SaveData>\VerbalCommands\delegates\stop\<name>`). Every specialist reads `<mod folder>\Skill\delegates\COMMON.md`
and its brief in `<mod folder>\Skill\delegates\briefs\`. `send.ps1` holds a mutex across senders and retries an order that hit another
agent's waiting plan; `wait_round.ps1` is what a specialist blocks on between rounds. Nothing in this
section is a way round "The one rule": specialists are bound by it too.

## Handoff and compaction
The session can not run `/compact` itself; the user does, or it happens when the context fills. So that
either one finds a handoff:
- At the start of play, write this session's id (the folder name above `scratchpad` in your scratchpad
  path) as the only line of `<SaveData>\VerbalCommands\play_sessions\active_session.txt`. The `SessionStart` hook
  `resume_hook.ps1` (matcher `compact`, in the user's `settings.json`; see `<mod folder>\Hook_list_for_setup.md`)
  prints the newest `day_*.md` into the context after a compaction, for that session only.
- Every game day (the end-of-day note, loop step 6) and before stopping, write
  `<SaveData>\VerbalCommands\play_sessions\day_NN.md`: state, cells, what happened, mistakes, instrument problems,
  short- and long-term goals, pawns to secure with reasoning, and the WHY.md and README pointers. This
  replaces the older every-2-days `day_NN-NN.md`.
- Every colonist's bills (user, 2026-10-17): the mod writes them each game hour to
  `<SaveData>\VerbalCommands\bills.md`; the `PostToolUse` hook `bills_hook.ps1` (user's `settings.json`) puts the file
  into this session's context whenever it changed, and again after a compaction. The day note copies them (ORCHESTRATOR.md section 4).
- Compaction (since 2026-10-19 no vote; user, 2026-10-19: "no fucking votes from anyone, not even orchestrator."):
  once the day notes make a compaction due, every game order is refused with `conditions are met for compaction.`; once a
  compaction can run, the hook pauses the game and lets it run (ORCHESTRATOR.md section 4). Afterwards the game stays paused until you unpause it.
- After a compaction go on playing without waiting for the user, if the user allowed that for RimWorld
  play: `show speed.` and `show status.` first, and trust the game over the log. This covers play only;
  mod changes, builds, git and anything outside RimWorld still wait for the user.

## Reporting to the user
Short. What you asked, what the game answered, what you ordered and whether it was applied, what stopped the
run. Quote the mod's refusals as they are. Say plainly when a sentence did not parse or the mod refused, and
never report an order as done unless the outbox says `applied` with every action `done`.
