# PostToolUse hook: tells the RimWorld play session that a compaction is due and what to do before it can run (user,
# 2026-10-15: "with a precompact hook inject saying to stop subagents"). A PreCompact hook can only allow or block
# (compact_gate.ps1); the words have to reach the agent earlier, so they ride on its tool results as additionalContext
# (code.claude.com/docs/en/hooks). The play session: RIMWORLD_PLAY=1 (play_here.ps1) or its id in play_log\active_session.txt.
# Due when floor(game.day / 3) is above the cycle in play_log\compact_state.json (compact_gate.ps1 keeps it), or when the
# context reaches 400,000 tokens (the gate's safety valve opens at 420,000). At most once every 5 minutes.
$Warn = 400000

function Get-ContextTokens([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path)) { return 0 }
    $fs = [IO.File]::Open($path, 'Open', 'Read', 'ReadWrite')
    try {
        $len = $fs.Length; $take = [Math]::Min($len, 1048576)
        $fs.Seek($len - $take, 'Begin') | Out-Null
        $buf = New-Object byte[] $take; [void]$fs.Read($buf, 0, $take)
    } finally { $fs.Close() }
    $lines = [Text.Encoding]::UTF8.GetString($buf) -split "`n"
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $l = $lines[$i]
        if ($l -notmatch '"type":"assistant"' -or $l -notmatch '"usage"') { continue }
        try { $u = ($l | ConvertFrom-Json).message.usage } catch { continue }
        if ($u) { return [int]$u.input_tokens + [int]$u.cache_read_input_tokens + [int]$u.cache_creation_input_tokens }
    }
    return 0
}

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $in = $raw | ConvertFrom-Json
    $proj = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands"
    $log = Join-Path $proj "play_sessions"   # new sessions' folder (2026-10-16)
    $marker = Join-Path $log "active_session.txt"
    $byId = (Test-Path -LiteralPath $marker) -and ([string]$in.session_id -eq (Get-Content -LiteralPath $marker -TotalCount 1).Trim())
    if (-not ($env:RIMWORLD_PLAY -eq "1" -or $byId)) { exit 0 }

    $statePath = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\inbox_state.json"
    $cfile = Join-Path $log "compact_state.json"
    if (-not (Test-Path -LiteralPath $statePath) -or -not (Test-Path -LiteralPath $cfile)) { exit 0 }
    $st = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $day = [int]$st.game.day
    $cycle = [math]::Floor($day / 3)
    $last = [int](Get-Content -LiteralPath $cfile -Raw | ConvertFrom-Json).lastCycle
    $cycleDue = $cycle -gt $last
    $ctx = 0
    if (-not $cycleDue) { $ctx = Get-ContextTokens ([string]$in.transcript_path) }
    if (-not $cycleDue -and $ctx -lt $Warn) { exit 0 }

    $shown = Join-Path $log "compact_due_shown.txt"
    if (Test-Path -LiteralPath $shown) {
        $at = [datetime]::Parse((Get-Content -LiteralPath $shown -TotalCount 1).Trim()).ToUniversalTime()
        if (((Get-Date).ToUniversalTime() - $at).TotalMinutes -lt 5) { exit 0 }
    }
    (Get-Date).ToUniversalTime().ToString("o") | Set-Content -LiteralPath $shown -Encoding UTF8

    $note = "day_{0:D2}.md" -f $day
    $missing = @()
    if ([string]$st.speed -ne "Paused") { $missing += "the game is running" }
    if ($cycleDue -and -not (Test-Path -LiteralPath (Join-Path $log $note))) { $missing += "$note is not written" }
    if (-not (Test-Path -LiteralPath (Join-Path $proj "delegates\stop\ALL"))) { $missing += "delegates\stop\ALL is not there" }
    $reason = if ($cycleDue) { "Game day $day (counted from 0) started a new 3-day cycle" } else { "The context is at $ctx tokens, near the limit (a forced compaction would come mid-game)" }
    $text = "[COMPACT DUE] $reason, so this session's compaction is due. Get ready, in this order: " +
        "1. 'set game speed to paused.' and keep it paused. " +
        $(if ($cycleDue) { "2. Finish the note play_sessions\$note for the day that just ended. " } else { "2. Bring the current day note up to date. " }) +
        "3. Stop every specialist: create $proj\delegates\stop\ALL, then wait until each one has returned with its final report. " +
        "4. End your turn and stay idle, game paused. " +
        "The compaction runs only while the game is paused and delegates\stop\ALL exists" +
        $(if ($missing.Count -gt 0) { " (still missing: " + ($missing -join "; ") + ")" } else { " (all set: just end your turn)" }) +
        ". After it you will be told what to read and to relaunch the specialists before unpausing."
    $out = @{ hookSpecificOutput = @{ hookEventName = "PostToolUse"; additionalContext = $text } } | ConvertTo-Json -Depth 4 -Compress
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::Out.Write($out)
} catch {
    exit 0
}
exit 0
