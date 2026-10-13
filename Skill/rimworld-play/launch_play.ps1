# Starts Claude Code for playing RimWorld with only what play needs (mod author: "bare minimum skills needed to
# write .md and save it to directories, and be able to /compact if i type it", plus rimworld-play).
#   Tools: PowerShell (send.ps1, play.ps1), Read, Edit, Write, Glob, Grep. No Bash, web, subagents or MCP.
#   Skills: rimworld-play only (play_settings.json turns the others and the bundled ones off). /compact stays.
#   No auto memory, no claude.ai connectors. User settings still load (the after-compaction resume hook is there).
#   Transcripts go to the usual %USERPROFILE%\.claude\projects, where the mod's token meter reads them.
$skill = $PSScriptRoot
Set-Location $skill   # play_log\ is written here
$env:CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1"
$env:ENABLE_CLAUDEAI_MCP_SERVERS = "false"
$claude = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claude) { $claude = Join-Path $env:USERPROFILE ".localin\claude.exe" }
& $claude `
    --setting-sources user `
    --settings (Join-Path $skill "play_settings.json") `
    --strict-mcp-config `
    --tools "PowerShell,Read,Edit,Write,Glob,Grep"
