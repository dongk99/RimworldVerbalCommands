# PreCompact hook: lets the RimWorld play session compact only at a 3-day turn (user, 2026-10-15: "the game day changed
# since the last compaction, and that day's note in play_log is written ... every 3 days. 0,1,2, 3,4,5, 6,7,8 ... and
# compact doesnt run unles game is paused."). Claude Code: "Exit with code 2 to block compaction"; a proactive auto-compact
# that is blocked is skipped and the conversation goes on (code.claude.com/docs/en/hooks, PreCompact). A compaction forced
# by the context limit can't be held back, and a manual /compact (the user's) is never blocked here.
# The play session: RIMWORLD_PLAY=1 in its environment (play_here.ps1, the desktop shortcut "RimWorld Play"), or its id in
# play_log\active_session.txt. Any other session: allowed, untouched.
# Allowed when the game is paused (inbox_state.json speed "Paused") and the specialists were told to stop
# (agent_player\delegates\stop\ALL), and either
#   - a new 3-day cycle: floor(game.day / 3) is above the cycle of the last compaction (game.day counts from 0; the cycle
#     is kept in play_log\compact_state.json) and the note of the day just finished exists (play_log\day_DD.md, DD =
#     game.day, notes count from 1); or
#   - the safety valve (user: offered "a safety valve", accepted with "try that"): the context is at 420,000 tokens or more
#     (read from the end of the session's transcript), so a heavy stretch ends in a clean paused compaction instead of
#     one forced at the limit. It does not move the 3-day schedule.
$ErrorActionPreference = "Stop"
$ValveTokens = 420000   # not "$Valve": PowerShell names ignore case, and $valve below is the yes/no

function Get-ContextTokens([string]$path) {
    # The newest assistant turn's usage at the end of the transcript (JSON lines): input + cache read + cache write.
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
    $in = $null
    if (-not [string]::IsNullOrWhiteSpace($raw)) { $in = $raw | ConvertFrom-Json }
    if ($null -eq $in) { exit 0 }
    $proj = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands"
    $log = Join-Path $proj "play_sessions"   # new sessions' folder (2026-10-16)
    $marker = Join-Path $log "active_session.txt"
    $byId = (Test-Path -LiteralPath $marker) -and ([string]$in.session_id -eq (Get-Content -LiteralPath $marker -TotalCount 1).Trim())
    if (-not ($env:RIMWORLD_PLAY -eq "1" -or $byId)) { exit 0 }
    if ([string]$in.trigger -eq "manual") { exit 0 }

    $statePath = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\inbox_state.json"
    # The mod rewrites the file by delete-then-move (AgentInbox.WriteJsonAtomic), so a read can land in the gap and throw;
    # the catch below would then let the compaction through (2026-10-16, day 0 at 166k). Retry, and hold if it never reads.
    $st = $null
    for ($try = 0; $try -lt 10 -and $null -eq $st; $try++) {
        try { $st = [IO.File]::ReadAllText($statePath) | ConvertFrom-Json } catch { $st = $null; Start-Sleep -Milliseconds 50 }
    }
    if ($null -eq $st -or $null -eq $st.game) { [Console]::Error.WriteLine("Compaction held: the game state (inbox_state.json) can't be read."); exit 2 }
    $day = [int]$st.game.day
    $cycle = [math]::Floor($day / 3)
    $ctx = Get-ContextTokens ([string]$in.transcript_path)

    $cfile = Join-Path $log "compact_state.json"
    $last = $null
    if (Test-Path -LiteralPath $cfile) { try { $last = [int](Get-Content -LiteralPath $cfile -Raw | ConvertFrom-Json).lastCycle } catch { $last = $null } }
    if ($null -eq $last -or $last -gt $cycle) {
        # First run, or a new game (days went back): count from the cycle we are in now.
        $last = $cycle
        @{ lastCycle = $cycle; day = $day; utc = (Get-Date).ToUniversalTime().ToString("o") } | ConvertTo-Json | Set-Content -LiteralPath $cfile -Encoding UTF8
    }
    $note = Join-Path $log ("day_{0:D2}.md" -f $day)
    $cycleDue = ($cycle -gt $last) -and (Test-Path -LiteralPath $note)
    $valve = $ctx -ge $ValveTokens
    $why = @()
    if (-not $cycleDue -and -not $valve) {
        if ($cycle -le $last) { $why += "not yet a new 3-day cycle (day $day; next at day " + (($last + 1) * 3) + ") and the context ($ctx) is under $ValveTokens" }
        else { $why += "the note " + [IO.Path]::GetFileName($note) + " is not written" }
    }
    if ([string]$st.speed -ne "Paused") { $why += "the game is not paused" }
    if (-not (Test-Path -LiteralPath (Join-Path $proj "delegates\stop\ALL"))) { $why += "the specialists were not told to stop (delegates\stop\ALL)" }
    if ($why.Count -gt 0) { [Console]::Error.WriteLine("Compaction held: " + ($why -join "; ") + "."); exit 2 }

    if ($cycleDue) {
        @{ lastCycle = $cycle; day = $day; utc = (Get-Date).ToUniversalTime().ToString("o") } | ConvertTo-Json | Set-Content -LiteralPath $cfile -Encoding UTF8
    }
    exit 0
} catch {
    # A broken gate must not block compaction for good.
    exit 0
}
