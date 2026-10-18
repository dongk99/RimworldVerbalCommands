# Starts Claude Code for playing RimWorld with only what play needs (user, 2026-10-05: "bare minimum skills needed to
# write .md and save it to directories, and be able to /compact if i type it", plus rimworld-play).
#   Tools: PowerShell (send.ps1, play.ps1), Read, Edit, Write, Glob, Grep. No Bash, web, subagents or MCP.
#   Skills: rimworld-play only (play_settings.json turns the others and the bundled ones off). /compact stays.
#   No auto memory, no claude.ai connectors. User settings still load (the after-compaction resume hook is there).
#   Transcripts go to the usual %USERPROFILE%\.claude\projects, where the mod's token meter reads them.
$skill = $PSScriptRoot
. (Join-Path $PSScriptRoot "find_mod.ps1")
if (-not $ModDir) { $ModDirError; exit 1 }
Set-Location (Join-Path $ModDir "Skill")
$env:CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1"
$env:ENABLE_CLAUDEAI_MCP_SERVERS = "false"
# 3-day compaction (user, 2026-10-15): Claude Code offers an auto-compact once context passes 20% of the auto-compact
# window, and idle compaction from 100,000 tokens; the PreCompact hook compact_gate.ps1 lets it run only at a 3-day turn
# with the game paused, the day note written and delegates\stop\ALL in place. Only this play session gets these values.
$env:CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "20"
$env:CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS = "100000"
& (Join-Path $env:USERPROFILE ".local\bin\claude.exe") `
    --setting-sources user `
    --settings (Join-Path $skill "play_settings.json") `
    --strict-mcp-config `
    --tools "PowerShell,Read,Edit,Write,Glob,Grep,Skill,Monitor,Agent,SendMessage,TaskStop"
