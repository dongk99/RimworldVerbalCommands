tell your favorite model providers to add hooks similar to this

# Hook list for setup

Claude Code: add these to `%USERPROFILE%\.claude\settings.json`. Replace `<skill folder>` with the folder holding the
rimworld-play scripts, written out in full. The hooks only act in a play session: `RIMWORLD_PLAY=1` (set by
`play_here.ps1`) or the session id in `<SaveData>\VerbalCommands\play_sessions\active_session.txt`.

this might conflict with auto mode if you have claude add into your computers. ask claude where these powershells/hooks would go. for claude: expect auto mode to give you a hiccup since a manual compaction hook triggers [Tmux Self Drive]. Notify user and have them change to manual mode.

| Event | Matcher | Script | What it does |
|---|---|---|---|
| SessionStart | compact | resume_hook.ps1 | After a compaction, prints the newest day note into the play session. |
| PreCompact | auto | compact_gate.ps1 | Lets an auto-compaction run only when one is due, game paused. |
| PostToolUse | PowerShell\|Bash | compact_warn.ps1 | At the warn limit, tells the orchestrator once to append to the day note. |
| PostToolUse | * | rimworld_skill_hint.py | When the agent writes "skill", hints `show skills of PAWN.` once per compaction. |
| PostToolUse | PowerShell\|Bash | bills_hook.ps1 | Puts bills.md (every colonist's bills) into the play session when it changes. |
| PreToolUse | Bash\|PowerShell\|Monitor\|Write\|Edit\|MultiEdit\|NotebookEdit | rimworld_play_scripts.py | Only the skill folder's scripts run, by full path; no new scripts, no pipe or redirect on a result; game speed 1x only. |
| PreToolUse | Bash\|PowerShell | compact_block.ps1 | While a compaction is due, refuses every game order. |
| PreToolUse | Read\|Grep\|Glob\|Bash\|PowerShell\|Monitor\|Write\|Edit\|MultiEdit\|NotebookEdit | rimworld_play_folder.py | Reads and writes only inside the mod folder and `<SaveData>\VerbalCommands\play_sessions\` / `delegates\`. |
| PreToolUse | * | compact_read_first.py | Once any compaction file (compact_*.ps1/.json/.md, resume_hook.ps1, play_here.ps1) is read or written, blocks every tool call until all compaction-relevant files were read with the Read tool; the block lists them. Register it in the project's `.claude\settings.json`, not the global one. |
| PreToolUse | Bash\|PowerShell | rimworld_required_reads.py | Blocks .ps1 commands until every file in required_reads.txt was read in full. |
| Stop | | compact_stop.ps1 | Compaction due at turn end: pauses the game, types /compact. |

rimworld_play_scripts.py, rimworld_play_folder.py, rimworld_skill_hint.py, rimworld_required_reads.py and compact_read_first.py need Python 3 (`python` on PATH).

Add this to `agent_player\.claude\settings.json` (play sessions only):
```json
{
  "permissions": {
    "deny": ["AskUserQuestion", "ExitPlanMode", "EnterPlanMode"]
  }
}
```

```json
{
  "hooks": {
    "SessionStart": [{ "matcher": "compact", "hooks": [
      { "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<skill folder>\\resume_hook.ps1\"" }] }],
    "PreCompact": [{ "matcher": "auto", "hooks": [
      { "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<skill folder>\\compact_gate.ps1\"", "timeout": 15 }] }],
    "PostToolUse": [{ "matcher": "PowerShell|Bash", "hooks": [
      { "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<skill folder>\\compact_warn.ps1\"", "timeout": 15 },
      { "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<skill folder>\\bills_hook.ps1\"", "timeout": 15 }] },
      { "matcher": "*", "hooks": [
      { "type": "command", "command": "python -I \"<skill folder>\\rimworld_skill_hint.py\"", "timeout": 10 }] }],
    "PreToolUse": [
      { "matcher": "Bash|PowerShell|Monitor|Write|Edit|MultiEdit|NotebookEdit", "hooks": [
        { "type": "command", "command": "python -I \"<skill folder>\\rimworld_play_scripts.py\"", "timeout": 10 }] },
      { "matcher": "Bash|PowerShell", "hooks": [{ "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<skill folder>\\compact_block.ps1\"", "timeout": 15 }] },
      { "matcher": "Read|Grep|Glob|Bash|PowerShell|Monitor|Write|Edit|MultiEdit|NotebookEdit", "hooks": [
        { "type": "command", "command": "python -I \"<skill folder>\\rimworld_play_folder.py\"", "timeout": 10 }] },
      { "matcher": "*", "hooks": [
        { "type": "command", "command": "python -I \"<skill folder>\\compact_read_first.py\"", "timeout": 10 }] },
      { "matcher": "Bash|PowerShell", "hooks": [
        { "type": "command", "command": "python -I \"<skill folder>\\rimworld_required_reads.py\"", "timeout": 10 }] }],
    "Stop": [{ "hooks": [
      { "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<skill folder>\\compact_stop.ps1\"", "timeout": 30 }] }]
  }
}
```
