# Skill: letting a Claude Code agent play through the agent inbox

What is here:
- `rimworld-play\` : the Claude Code skill (SKILL.md and its PowerShell scripts).
- `PLAYBOOK.md` : the manual for the instrument (inbox, time, places, sentences).
- `DIFFICULTY.md` : Randy Random / Losing is Fun in numbers.
- `reference_play\REFERENCE_HUMAN_PLAY-Autosave-5.analysis.md` : a human 54-day play of a 3-colonist
  crashlanded start, day by day with the reasoning; every playing agent reads it before its first order.

## Install
1. Copy the folder `rimworld-play` to `%USERPROFILE%\.claude\skills\rimworld-play` (make `skills\` if it
   is missing). Claude Code finds the skill there by name.
2. In the mod settings tick "Agent inbox: run orders from text files in the inbox folder" and load a colony.
3. Start Claude Code and ask it to play RimWorld (or run `rimworld-play\launch_play.ps1`, which starts Claude
   Code with only the tools play needs and the other skills off).

The skill reads `PLAYBOOK.md`, `Tips\INDEX.md` and `reference_play\...analysis.md` from the installed mod
folder, so the mod must stay where RimWorld loads it from. The agent writes its own notes to
`rimworld-play\play_log\` in its skill folder; nothing is written to the mod folder, the game's `Config`
folder or the saves.

## Optional: resume after a compaction
`resume_hook.ps1` prints the newest `play_log\day_*.md` back into the context after `/compact`, only in the
session that is playing. Add to `%USERPROFILE%\.claude\settings.json`:
```
"hooks": {
  "SessionStart": [
    { "matcher": "compact",
      "hooks": [ { "type": "command",
                   "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"%USERPROFILE%\.claude\skills\rimworld-play\resume_hook.ps1\"" } ] }
  ]
}
```

## Scripts
- `send.ps1 -Text "show status."` : one order in, the outbox JSON out. `-Mode "raw apply"` applies at once;
  `-Reply apply|cancel` answers a plan that waits; `-Model <id>` on a session's first order.
- `play.ps1 -Do ... -Plan ... -Reply ... -Ask ...` : a whole step of play in one call.
- `watch.ps1` : armed once per session with the Monitor tool; every new game event, inbox wait and
  stop/start becomes a chat notification.
- `launch_game.ps1 [-Save <name>] [-Exe [-ExePath <...\RimWorldWin64.exe>]]` : starts the game on a save
  (through Steam by default) and waits for the colony to answer. It turns dev mode on in `Prefs.xml` for the
  autostart load; turn it off in Options if unwanted.
- `launch_play.ps1` : Claude Code with `play_settings.json` (bundled skills and connectors off; add your
  own skills to `skillOverrides` as `"off"`) and the tools PowerShell, Read, Edit, Write, Glob, Grep.
