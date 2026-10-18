# PostToolUse hook: shows the orchestrator every bill each colonist has (user, 2026-10-17: "have play session just print
# out .md and update on its own on what bill pawns have, and force-read orchestrator the file."). The mod writes
# <SaveData>\VerbalCommands\bills.md each game hour when it changed (FormBills.WriteBillsFile); this hook puts it into the
# play session's context as additionalContext after its next PowerShell/Bash call, once per change. resume_hook.ps1
# deletes play_sessions\bills_shown.txt after a compaction, so the file is shown again then.
# The play session only: RIMWORLD_PLAY=1 (play_here.ps1) or its id in play_sessions\active_session.txt (as compact_due.ps1).
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $in = $raw | ConvertFrom-Json
    $log = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\play_sessions"
    $marker = Join-Path $log "active_session.txt"
    $byId = (Test-Path -LiteralPath $marker) -and ([string]$in.session_id -eq (Get-Content -LiteralPath $marker -TotalCount 1).Trim())
    if (-not ($env:RIMWORLD_PLAY -eq "1" -or $byId)) { exit 0 }

    $bills = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\bills.md"
    if (-not (Test-Path -LiteralPath $bills)) { exit 0 }
    $text = Get-Content -LiteralPath $bills -Encoding UTF8 -Raw
    if ([string]::IsNullOrWhiteSpace($text)) { exit 0 }

    $sha = [Security.Cryptography.SHA256]::Create()
    $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))) -replace "-", ""
    $shown = Join-Path $log "bills_shown.txt"
    if ((Test-Path -LiteralPath $shown) -and ((Get-Content -LiteralPath $shown -TotalCount 1).Trim() -eq $hash)) { exit 0 }
    $hash | Set-Content -LiteralPath $shown -Encoding UTF8

    $out = @{ hookSpecificOutput = @{ hookEventName = "PostToolUse"; additionalContext = "bills.md:`n" + $text } } | ConvertTo-Json -Depth 4 -Compress
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::Out.Write($out)
} catch {
    exit 0
}
exit 0
