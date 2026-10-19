# compact_common.ps1 - the compaction rules, dot-sourced by compact_block.ps1 (PreToolUse), compact_gate.ps1
# (PreCompact) and resume_hook.ps1 (SessionStart). Defines functions only; prints nothing.
#
# The rule (user, 2026-10-19: "the hook for compaction just needs to see files being there. no fucking votes from anyone,
# not even orchestrator." / "All it needs is day notes from orchestrator in order to compact. that's literally all it
# does."). No votes, no specialist notes ("I dont care what specialist status is. that gets compacted regardless.").
#   - Cycle path (user, 2026-10-18: "pre-compaction hook requirement from 3 days of writing .md to 2 days (every other
#     day)"): cycles of 2 game days, counted from 1 (game days 0-1 = cycle 1, 10-11 = cycle 6). Due once a new cycle has
#     begun (cycle above lastCycle in play_sessions\compact_state.json) and both notes of the cycle that just ended exist
#     (at day 12: day_10.md and day_11.md; a note is named after the in-game day it is written on).
#   - Context path, limits in compact_limits.json ("270,000 and 300,000"): from warn the size of the current day's note is
#     saved; from valve a compaction is due once the note is
#     larger than that size and the previous day's note exists too (user, 2026-10-19: "you need TWO days of note to
#     compact. NOT one."). On day 0 this path never fires.
#   - From due until done (user, 2026-10-19: "From due until done") every game order is refused (compact_block.ps1); the
#     gate pauses the game and lets the compaction run (compact_gate.ps1, "you pause the game before compaction actually
#     happens"); nothing but the orchestrator unpauses it ("It doesnt unpause unless an orchestrator does it.").
# The play session: RIMWORLD_PLAY=1 (play_here.ps1) or its id in play_sessions\active_session.txt.
$CC_Proj = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands"   # delegates\ and play_sessions\ live in <SaveData>\VerbalCommands
$CC_Log = Join-Path $CC_Proj "play_sessions"
$CC_GameState = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\inbox_state.json"
$CC_LimitsFile = Join-Path $PSScriptRoot "compact_limits.json"
$CC_CycleFile = Join-Path $CC_Log "compact_state.json"     # lastCycle, and the context path's saved note size
$CC_Message = "conditions are met for compaction."   # user's words (2026-10-19), verbatim

function CC-ReadJson([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try { return ([IO.File]::ReadAllText($path) | ConvertFrom-Json) } catch { return $null }
}
function CC-WriteJson([string]$path, $obj) {
    [IO.File]::WriteAllText($path, ($obj | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
}

# The play session: RIMWORLD_PLAY=1 (play_here.ps1) or its id in play_sessions\active_session.txt.
function CC-IsPlaySession($in) {
    if ($env:RIMWORLD_PLAY -eq "1") { return $true }
    $marker = Join-Path $CC_Log "active_session.txt"
    if (-not (Test-Path -LiteralPath $marker)) { return $false }
    return ([string]$in.session_id -eq (Get-Content -LiteralPath $marker -TotalCount 1).Trim())
}

# The mod rewrites inbox_state.json by delete-then-move (AgentInbox.WriteJsonAtomic), so a read can land in the gap: retry.
function CC-ReadGame {
    for ($try = 0; $try -lt 10; $try++) {
        try { $st = [IO.File]::ReadAllText($CC_GameState) | ConvertFrom-Json; if ($st -ne $null -and $st.game -ne $null) { return $st } } catch { }
        Start-Sleep -Milliseconds 50
    }
    return $null
}

# The newest assistant turn's usage at the end of the transcript (JSON lines): input + cache read + cache write.
function CC-ContextTokens([string]$path) {
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

function CC-Limits {
    $l = CC-ReadJson $CC_LimitsFile
    $warn = 270000; $valve = 300000
    if ($l -ne $null) { if ($l.warn) { $warn = [int]$l.warn }; if ($l.valve) { $valve = [int]$l.valve } }
    return @{ warn = $warn; valve = $valve }
}

function CC-NotePath([int]$day) { return (Join-Path $CC_Log ("day_{0:D2}.md" -f $day)) }
function CC-Size([string]$path) { if (Test-Path -LiteralPath $path) { return [long](Get-Item -LiteralPath $path).Length } else { return [long]-1 } }

# Is a compaction due? $in: the hook input (session_id, transcript_path). Saves lastCycle on a first run or a new game, the note size when
# the context first reaches warn.
function CC-Evaluate($in) {
    $r = @{ ok = $false; due = $false; path = $null; day = -1; cycle = 0; last = 0; ctx = 0; warned = $false
            note = $null; prev = $null; missing = @(); speed = ""; notesThere = $false; contextDue = $false }
    $st = CC-ReadGame
    if ($null -eq $st) { return $r }
    $r.ok = $true
    $r.speed = [string]$st.speed
    $day = [int]$st.game.day
    $r.day = $day
    $cycle = [int][math]::Floor($day / 2) + 1
    $r.cycle = $cycle
    $lim = CC-Limits

    $cs = CC-ReadJson $CC_CycleFile
    $state = @{}
    if ($cs -ne $null) { foreach ($p in $cs.PSObject.Properties) { $state[$p.Name] = $p.Value } }
    $last = $null
    if ($state.ContainsKey("lastCycle")) { try { $last = [int]$state.lastCycle } catch { $last = $null } }
    $dirty = $false
    if ($null -eq $last -or $last -gt $cycle) {
        # First run, or a new game (days went back): count from the cycle we are in now.
        $last = $cycle; $state.lastCycle = $cycle; $state.day = $day; $dirty = $true
    }
    $r.last = $last

    # Cycle path: the cycle that just ended is cycle - 1, game days 2(c-1)-2 and 2(c-1)-1. notesThere: both its notes
    # exist (what the gate and resume_hook.ps1 read); due: and no compaction has run in this cycle yet (lastCycle).
    $r.notesThere = $false
    if ($cycle -ge 2) {
        $b = $cycle - 1
        $notes = @((CC-NotePath (2 * $b - 2)), (CC-NotePath (2 * $b - 1)))
        $r.missing = @($notes | Where-Object { -not (Test-Path -LiteralPath $_) })
        $r.notesThere = ($r.missing.Count -eq 0)
    }
    $cycleDue = ($cycle -gt $last) -and $r.notesThere

    # Context path.
    $contextDue = $false
    $note = CC-NotePath $day
    $r.note = $note
    $ctx = CC-ContextTokens ([string]$in.transcript_path)
    $r.ctx = $ctx
    if ($ctx -ge $lim.warn) {
        $r.warned = $true
        if ([string]$state.noteFile -ne $note) { $state.noteFile = $note; $state.noteSize = (CC-Size $note); $dirty = $true }
        $r.prev = $(if ($day -ge 1) { CC-NotePath ($day - 1) } else { $null })
        if ($ctx -ge $lim.valve) {
            $contextDue = ((CC-Size $note) -gt [long]$state.noteSize) -and $r.prev -and (Test-Path -LiteralPath $r.prev)
        }
    } elseif ($state.ContainsKey("noteFile") -and $state.noteFile) {
        $state.noteFile = $null; $state.noteSize = $null; $dirty = $true
    }

    $r.contextDue = $contextDue
    $due = ($cycleDue -or $contextDue)
    if ($dirty) { $state.utc = (Get-Date).ToUniversalTime().ToString("o"); CC-WriteJson $CC_CycleFile $state }

    $r.due = $due
    if ($cycleDue) { $r.path = "cycle" } elseif ($contextDue) { $r.path = "context" }
    return $r
}

# A compaction has run (resume_hook.ps1, SessionStart compact): the cycle's compaction is done, so the block lifts.
function CC-Compacted($ev) {
    $cs = CC-ReadJson $CC_CycleFile
    $state = @{}
    if ($cs -ne $null) { foreach ($p in $cs.PSObject.Properties) { $state[$p.Name] = $p.Value } }
    if ($ev.notesThere) { $state.lastCycle = $ev.cycle; $state.day = $ev.day }
    $state.noteFile = $null; $state.noteSize = $null
    $state.utc = (Get-Date).ToUniversalTime().ToString("o")
    CC-WriteJson $CC_CycleFile $state
}
