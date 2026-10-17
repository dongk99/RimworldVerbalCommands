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
  `resume_hook.ps1`, and the agent's own `play_log\`.

## The one rule
Everything you see and do in the game goes through the interpreter: a router sentence, sent to the mod's
inbox, parsed by `router.txt`, answered in the outbox. Nothing else touches the game:
- no screenshots, no OCR, no reading the game window, no key or mouse input;
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
   session. It is the mod author's own 54-day play of the same kind of start, day by day with reasoning,
   and it carries the end-of-day note rule (loop step 6).
1c. User, 2026-10-16: "models may not read reference playlog unless user explicitely allows it."
2. If `send.ps1` answers `NOT RUNNING`, RimWorld is closed and nothing was sent: tell the user to start the
   game, load the colony and tick "Agent inbox" in the mod settings. Do not go on without it.
2b. **Arm the watcher**, once, with the Monitor tool:
   `Monitor({ command: 'powershell -File "<skill folder>\watch.ps1"', description: 'RimWorld inbox_state
   events', timeout_ms: 1800000 })`. Every new game event (letter, message, pawn state), every change of
   what the inbox waits for, and every stop/start of the game then arrives in your chat as a notification
   the moment the mod writes it, with nothing sent to the game. Re-arm it when it expires (30 min) or
   prints `NOT RUNNING`. Act on an `EVENT` or `WAITING ask` line as you would on a `show events.` answer.
3. First orders: `show questions for show.`, `show orders.`, then `show status.` The mod's own lists are the
   truth about what sentences exist; the documents can lag behind.

## Sending
```
powershell -File "<skill folder>\send.ps1" -Text "show status."
powershell -File "<skill folder>\send.ps1" -Text "build campfire near Bob." -Mode "raw dry"
powershell -File "<skill folder>\send.ps1" -Text "set game speed to fast." -Mode "raw apply"
powershell -File "<skill folder>\send.ps1" -Reply apply        (or: -Reply cancel)
```
- On the session's first order add `-Model <your model id>` (e.g. `-Model claude-opus-5-5`; `play.ps1` takes it
  too). The inbox file names then carry your model, the harness and your session id, so the mod's token counter
  finds your transcript. Later orders reuse the name start; `-Model` is not needed again.
- A result can carry tips: `TIP:` lines at the end of `answers` and of `reasons` (also in `tips`), short tips
  from the know-how files that fit your order or what just happened. A `TIP:` line in `reasons` is not a failure. For a whole file send `send.ps1 -Text "I need tips on <name>"`.
- `-Mode` default is `raw`: your text is router sentences, parsed as written, no Haiku call. Several
  sentences: one per line, or `. ` between them. Write `raw` always; plain-language mode (no `raw`) costs a
  Haiku call per order and is for testing the prompt only, on the user's word.
- A question (`show ...`, `where ...`, `who ...`, `how much ...`, `list ...`) is answered at once.
- A change comes back as `planned` with `plan_lines`, `notes` and `risky`. Read them, then
  `-Reply apply` or `-Reply cancel`. Use `-Mode "raw apply"` only for runs and for changes you have already
  seen planned once. Never `apply` blind on a plan marked `risky`.
- An order is all questions or all changes, never both.
- The script prints the outbox JSON. `result`: `answer`, `planned`, `applied`, `dry_run`,
  `nothing_to_change`, `ask`, `cannot`, `failed`, `problem`, `cancelled`, `rejected`; `reasons` say why.
- Numbers (coordinates, counts, sizes) must be in your sentence because you chose them from an answer; the
  router rejects a number that is not in the order.
- `move chunks.` moves all stone chunks inside rooms to stockpile, if there is one, to make rooms prettier (user, 2026-10-16). The mod always waits for `-Reply apply` or `-Reply cancel`.

## The loop
1. `show events.` and `show status.` (after every stop, before any order).
2. Decide; look up the know-how file if the situation is new.
3. Orders: plan, read, apply.
4. Never `run N hours.` / `run until event.` (mod author: "never run play for x hour", "you can only
   unpause/pause, play at 1x/2x/3x speed"). `show windows.` and close what holds the pause; then `set game
   speed to normal.` / `fast.` / `superfast.` with `-Mode "raw apply"`. The agent never pauses the game
   unless necessary, e.g. busy doing tasks like writing memos, checking game status, reading memos,
   delegating tasks to other agents (earlier wording: "Game should *not* be paused by you (it already
   pauses itself for most message events)."). Pause for the task, unpause when it is done; never leave the
   game paused while idle. While it moves, the watcher (step 2b) tells you what happens; do not poll
   `inbox_state.json` by hand or sleep in a shell. PLAYBOOK.md section 4. The end-of-day note (step 6) is
   one such task.
5. Keep your own short notes in the session of what you built where (cells), since the mod names no
   building you placed.
6. **End of every game day**: when the day turns (hour 0; `show speed.` or `inbox_state.json` tick, 60000
   per day), pause with `set game speed to paused.` (`-Mode "raw apply"`), write
   `<skill folder>\play_log\day_NN.md` with: what you did today (orders, cells, refusals quoted); your
   short-term goal (1-3 days) and why; your long-term goal for the colony and why; which pawns you must
   secure and the reasoning (only researcher / doctor / builder / rifle carrier ...); one line comparing with
   the human's same day in the reference file. Before unpausing into the new day, re-read the previous
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
   something the mod can not do or show is C# in the mod's `Agent*.cs` / `Form*.cs` files, compiled to a
   scratch folder first; a know-how gap is a `Tips\*.md` file. Rules for that work: the interpreter's own
   C# (`RouterScript*`) is never changed; a build that deploys to the game runs only on the user's word in
   that turn, never while the game runs, and the game must be restarted to load it; no git commit or push
   without the user's word; no Haiku test runs.
4. If it can not be done within those rules, stop and tell the user what is missing.

## Handoff and compaction
The session can not run `/compact` itself; the user does, or it happens when the context fills. So that
either one finds a handoff:
- At the start of play, write this session's id (the folder name above `scratchpad` in your scratchpad
  path) as the only line of `<skill folder>\play_log\active_session.txt`. The `SessionStart` hook
  `resume_hook.ps1` (matcher `compact`, in the user's `settings.json`; see `<mod folder>\Skill\README.md`)
  prints the newest `day_*.md` into the context after a compaction, for that session only.
- Every game day (the end-of-day note, loop step 6) and before stopping, write
  `<skill folder>\play_log\day_NN.md`: state, cells, what happened, mistakes, instrument problems,
  short- and long-term goals, pawns to secure with reasoning.
- After a compaction go on playing without waiting for the user, if the user allowed that for RimWorld
  play: `show speed.` and `show status.` first, and trust the game over the log. This covers play only;
  mod changes, builds, git and anything outside RimWorld still wait for the user.

## Reporting to the user
Short. What you asked, what the game answered, what you ordered and whether it was applied, what stopped the
run. Quote the mod's refusals as they are. Say plainly when a sentence did not parse or the mod refused, and
never report an order as done unless the outbox says `applied` with every action `done`.
