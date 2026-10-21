# Starts a plain Claude Code session for playing RimWorld, from the desktop shortcut "RimWorld Play" (user, 2026-10-15:
# "try that, put .ps1 on desktop shortcut, icon rimworld human meat"). Unlike launch_play.ps1 it does not touch the game
# or limit tools: the user loads the colony by hand (colony 3, a reload or another colony) as with the taskbar app.
# It only adds what the 2-day compaction needs, for this session alone:
#   RIMWORLD_PLAY=1                         marks the play session for compact_block.ps1 / compact_due.ps1 / compact_gate.ps1 / resume_hook.ps1
#                                           (they also accept the id in play_log\active_session.txt)
#   CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=20      auto-compact offered from 20% of the window; the gate decides
#   CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS     idle compaction from 100,000 tokens (gated the same way)
# Any arguments go on to claude (e.g. --resume <session id>).
. (Join-Path $PSScriptRoot "find_mod.ps1")
if (-not $ModDir) { $ModDirError; exit 1 }
Set-Location (Join-Path $ModDir "Skill")
$env:RIMWORLD_PLAY = "1"
$env:CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "20"
$env:CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS = "100000"
& "{YOUR DIRECTORY HERE}\claude.exe" @args
