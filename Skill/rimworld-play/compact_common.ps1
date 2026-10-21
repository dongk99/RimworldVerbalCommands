# compact_common.ps1 - the compaction rules, dot-sourced by compact_block.ps1 (PreToolUse), compact_gate.ps1
# (PreCompact) and resume_hook.ps1 (SessionStart). Defines functions only; prints nothing.
#
# The rule (user, 2026-10-19: "the hook for compaction just needs to see files being there. no fucking votes from anyone,
# not even orchestrator." / "All it needs is day notes from orchestrator in order to compact. that's literally all it
# does."). No votes, no specialist notes ("I dont care what specialist status is. that gets compacted regardless.").
#   - Cycle path (user, 2026-10-18: "pre-compaction hook requirement from 3 days of writing .md to 2 days (every other
#     day)"): cycles of 2 game days, counted from 1 (game days 0-1 = cycle 1, 10-11 = cycle 6). Due once a new cycle has
#     begun (cycle above lastCycle in play_sessions\compact_state.json) and both notes of the cycle that just ended exist
#     (at game day 12: day_11.md and day_12.md). Notes count from 1 (SKILL.md, user 2026-10-21: "skill.md defines nn
#     counting from 1"): note number = game day + 1. A day_00.md the agent wrote anyway is renamed to day_01.md, only
#     that one ("compact_common needs to see if agent wrote day_nn as 00, and only for THAT, it writes as 01").
#   - Context path, limits in compact_limits.json ("270,000 and 300,000"). User, 2026-10-21: "that valve needs to fucking
#     work irregardless of day notes. same goes for warning." From warn the agent is told once (compact_warn.ps1); from
#     valve a compaction is due. No day note is looked at. Why: the old rule (valve due once today's note grew since warn)
#     never fired on 2026-10-21 (session 9dff3c40, 489k): the agent's notes were one day ahead of the game's day count,
#     so every watched note was already finished (compact_common.ps1.event_2026-10-21_valve.mmd).
#   - From due until done (user, 2026-10-19: "From due until done") every game order is refused (compact_block.ps1); the
#     gate pauses the game and lets the compaction run (compact_gate.ps1, "you pause the game before compaction actually
#     happens"); nothing but the orchestrator unpauses it ("It doesnt unpause unless an orchestrator does it.").
# The play session: RIMWORLD_PLAY=1 (play_here.ps1) or its id in play_sessions\active_session.txt.
$CC_Proj = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands"   # delegates\ and play_sessions\ live in <SaveData>\VerbalCommands
$CC_Log = Join-Path $CC_Proj "play_sessions"
$CC_GameState = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\inbox_state.json"
$CC_LimitsFile = Join-Path $PSScriptRoot "compact_limits.json"
$CC_CycleFile = Join-Path $CC_Log "compact_state.json"     # lastCycle, and warnShown (compact_warn.ps1 told the agent)
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
# A compact boundary after the last usage line: that usage is from before the compaction, so 0.
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
        if ($l -match '"subtype":"compact_boundary"') { return 0 }
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

# $day: the game's day (from 0). Notes count from 1: game day 0 = day_01.md.
function CC-NotePath([int]$day) { return (Join-Path $CC_Log ("day_{0:D2}.md" -f ($day + 1))) }

# A day_00.md (the agent counted from 0) becomes day_01.md; only that one, and never over an existing day_01.md.
function CC-FixDayZero {
    $zero = Join-Path $CC_Log "day_00.md"; $one = Join-Path $CC_Log "day_01.md"
    if ((Test-Path -LiteralPath $zero) -and -not (Test-Path -LiteralPath $one)) {
        try { Move-Item -LiteralPath $zero -Destination $one } catch { }
    }
}

# Is a compaction due? $in: the hook input (session_id, transcript_path). Saves lastCycle on a first run or a new game,
# clears warnShown below warn.
function CC-Evaluate($in) {
    $r = @{ ok = $false; due = $false; path = $null; day = -1; cycle = 0; last = 0; ctx = 0; warned = $false; warn = 0
            note = $null; missing = @(); speed = ""; notesThere = $false; contextDue = $false }
    CC-FixDayZero
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

    # Cycle path: the cycle that just ended is cycle - 1, game days 2(c-1)-2 and 2(c-1)-1 (notes day_2(c-1)-1.md and
    # day_2(c-1).md). notesThere: both its notes
    # exist (what the gate and resume_hook.ps1 read); due: and no compaction has run in this cycle yet (lastCycle).
    $r.notesThere = $false
    if ($cycle -ge 2) {
        $b = $cycle - 1
        $notes = @((CC-NotePath (2 * $b - 2)), (CC-NotePath (2 * $b - 1)))
        $r.missing = @($notes | Where-Object { -not (Test-Path -LiteralPath $_) })
        $r.notesThere = ($r.missing.Count -eq 0)
    }
    $cycleDue = ($cycle -gt $last) -and $r.notesThere

    # Context path: no day note looked at. $r.note is only named in compact_warn.ps1's message.
    $contextDue = $false
    $r.note = CC-NotePath $day
    $ctx = CC-ContextTokens ([string]$in.transcript_path)
    $r.ctx = $ctx
    $r.warn = $lim.warn
    if ($ctx -ge $lim.warn) {
        $r.warned = $true
        if ($ctx -ge $lim.valve) { $contextDue = $true }
    } elseif ($state.ContainsKey("warnShown") -and $state.warnShown) {
        $state.warnShown = $false; $dirty = $true
    }
    # The old saved note size (noteFile / noteSize) is no longer used.
    foreach ($k in @("noteFile", "noteSize")) { if ($state.ContainsKey($k)) { $state.Remove($k); $dirty = $true } }

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
    $state.warnShown = $false
    foreach ($k in @("noteFile", "noteSize")) { $state.Remove($k) }
    $state.utc = (Get-Date).ToUniversalTime().ToString("o")
    CC-WriteJson $CC_CycleFile $state
}

# compact_warn.ps1: has the agent been told at warn since the context last dropped below it or a compaction ran?
function CC-WarnShown {
    $cs = CC-ReadJson $CC_CycleFile
    return ($cs -ne $null -and $cs.warnShown -eq $true)
}
function CC-SetWarnShown {
    $cs = CC-ReadJson $CC_CycleFile
    $state = @{}
    if ($cs -ne $null) { foreach ($p in $cs.PSObject.Properties) { $state[$p.Name] = $p.Value } }
    $state.warnShown = $true
    $state.utc = (Get-Date).ToUniversalTime().ToString("o")
    CC-WriteJson $CC_CycleFile $state
}
