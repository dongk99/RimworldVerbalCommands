tell your favorite model providers to add hooks similar to this

# Hook list for setup

Claude Code: add these to `%USERPROFILE%\.claude\settings.json`. Replace `<skill folder>` with the folder holding the
rimworld-play scripts, written out in full. The hooks only act in a play session: `RIMWORLD_PLAY=1` (set by
`play_here.ps1`) or the session id in `<SaveData>\VerbalCommands\play_sessions\active_session.txt`.

| Event | Matcher | Script | What it does |
|---|---|---|---|
| SessionStart | compact | resume_hook.ps1 | After a compaction, prints the newest day note into the play session. |
| PreCompact | auto | compact_gate.ps1 | Lets an auto-compaction run only after the orchestrator's compaction vote, with the game paused and the specialists' notes written (or 30 s after the vote). |
| PostToolUse | PowerShell\|Bash | compact_due.ps1 | Tells every agent when the compaction conditions are met, and the specialists what to do after the vote. |
| PostToolUse | PowerShell\|Bash | bills_hook.ps1 | Puts bills.md (every colonist's bills) into the play session when it changes. |
| PreToolUse | Bash\|PowerShell\|Monitor\|Write\|Edit\|MultiEdit\|NotebookEdit | rimworld_play_scripts.py | Only the skill folder's scripts run, by full path; no new scripts, no pipe or redirect on a result; game speed 1x only. |
| PreToolUse | Bash\|PowerShell | compact_block.ps1 | While the compaction conditions are met, refuses every game order except the compaction vote. |
| PreToolUse | Read\|Grep\|Glob\|Bash\|PowerShell\|Monitor\|Write\|Edit\|MultiEdit\|NotebookEdit | rimworld_play_folder.py | Reads and writes only inside the mod folder and `<SaveData>\VerbalCommands\play_sessions\` / `delegates\`. |

rimworld_play_scripts.py, rimworld_play_folder.py and rimworld_skill_hint.py need Python 3 (`python` on PATH).

```json
{
  "hooks": {
    "SessionStart": [{ "matcher": "compact", "hooks": [
      { "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<skill folder>\\resume_hook.ps1\"" }] }],
    "PreCompact": [{ "matcher": "auto", "hooks": [
      { "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<skill folder>\\compact_gate.ps1\"", "timeout": 15 }] }],
    "PostToolUse": [{ "matcher": "PowerShell|Bash", "hooks": [
      { "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<skill folder>\\compact_due.ps1\"", "timeout": 15 },
      { "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<skill folder>\\bills_hook.ps1\"", "timeout": 15 }] }],
    "SubagentStop": [{ "hooks": [
      { "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<skill folder>\\subagent_stop_hook.ps1\"", "timeout": 15 }] }],
    "PreToolUse": [
      { "matcher": "Bash|PowerShell|Monitor|Write|Edit|MultiEdit|NotebookEdit", "hooks": [
        { "type": "command", "command": "python -I \"<skill folder>\\rimworld_play_scripts.py\"", "timeout": 10 }] },
      { "matcher": "Bash|PowerShell", "hooks": [{ "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<skill folder>\\compact_block.ps1\"", "timeout": 15 }] },
      { "matcher": "Read|Grep|Glob|Bash|PowerShell|Monitor|Write|Edit|MultiEdit|NotebookEdit", "hooks": [
        { "type": "command", "command": "python -I \"<skill folder>\\rimworld_play_folder.py\"", "timeout": 10 }] }]
  }
}
```
