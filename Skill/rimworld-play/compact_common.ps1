# compact_common.ps1 - the compaction rules, dot-sourced by compact_block.ps1 (PreToolUse), compact_due.ps1
# (PostToolUse), compact_gate.ps1 (PreCompact) and vote.ps1 -Compact. Defines functions only; prints nothing.
#
# The flow (user, 2026-10-18/19):
#   - "pre-compaction hook requirement from 3 days of writing .md to 2 days (every other day)": cycles of 2 game days,
#     counted from 1 (game days 0-1 = cycle 1, 10-11 = cycle 6). A cycle compaction is due once a new cycle has begun
#     (cycle above lastCycle in play_sessions\compact_state.json) and both notes of the cycle that just ended exist
#     (at day 12: day_10.md and day_11.md; a note is named after the in-game day it is written on).
#   - Context path, limits in compact_limits.json ("270,000 and 300,000"): from warn the orchestrator is told to append
#     to the current day's note and the note's size is saved; from valve a compaction is due once the note is larger than
#     that size (it was appended to after the warning; no clock) and the previous day's note exists too: two day
#     notes, as for a cycle (user, 2026-10-19: "you need TWO days of note to compact. NOT one." / "because there
#     wasnt two notes. that's the fucking bug."; one note was enough before). On day 0 this path never fires.
#   - "whenever the conditions are met, write a logic so that no model/specialist can interact with the game, and have
#     the logic output "conditions are met for compaction. if you are an orchestrator, vote for compaction."":
#     compact_block.ps1 refuses every game order except the compact vote, with that text.
#   - "you only let the orchestrator vote": vote.ps1 -Compact (orchestrator only) pauses the game, puts down
#     delegates\stop\ALL and records the specialists' status note sizes; the specialists are told by hook to pause and
#     write their note. "90 second after orchestrator vote no matter what. if the note has been updated for all the
#     specialist, then dont wait 90s." / "no 90s, 30s": the gate lets the compaction run once every note grew, or 30 s
#     after the vote.
$CC_Proj = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands"   # delegates\ and play_sessions\ live in <SaveData>\VerbalCommands
$CC_Log = Join-Path $CC_Proj "play_sessions"
$CC_Status = Join-Path $CC_Proj "delegates\status"
$CC_GameState = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\inbox_state.json"
$CC_LimitsFile = Join-Path $PSScriptRoot "compact_limits.json"
$CC_CycleFile = Join-Path $CC_Log "compact_state.json"     # lastCycle, and the context path's saved note size
$CC_NowFile = Join-Path $CC_Log "compact_now.json"         # the last evaluation (compact_block.ps1), read by vote.ps1
$CC_VoteFile = Join-Path $CC_Log "compact_vote.json"       # the orchestrator's compact vote
$CC_RestartFile = Join-Path $CC_Log "compact_restart.json" # written by the gate when it lets the compaction run
$CC_RunningFile = Join-Path $CC_Log "specialists_running.json"
$CC_WaitSec = 30   # user, 2026-10-19: "no 90s, 30s"
$CC_Message = "conditions are met for compaction. if you are an orchestrator, vote for compaction."   # user's words, verbatim

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
function CC-StatusPath([string]$name) { return (Join-Path $CC_Status "$name.md") }
function CC-Size([string]$path) { if (Test-Path -LiteralPath $path) { return [long](Get-Item -LiteralPath $path).Length } else { return [long]-1 } }

# The orchestrator's compact vote of this session, or $null.
function CC-Vote([string]$sid) {
    $v = CC-ReadJson $CC_VoteFile
    if ($v -eq $null) { return $null }
    if ($sid -and [string]$v.session -ne $sid) { return $null }
    return $v
}

# Specialists seen in this session (agent id -> the -Name it gave wait_round / hostiles_watch / vote), until SubagentStop.
function CC-Running([string]$sid) {
    $r = CC-ReadJson $CC_RunningFile
    $map = @{}
    if ($r -ne $null -and [string]$r.session -eq $sid -and $r.agents -ne $null) {
        foreach ($p in $r.agents.PSObject.Properties) { $map[$p.Name] = [string]$p.Value }
    }
    return $map
}
function CC-SaveRunning([string]$sid, $map) { CC-WriteJson $CC_RunningFile @{ session = $sid; agents = $map } }

# Are the conditions met? $in: the hook input (session_id, transcript_path). Saves lastCycle on a first run or a new
# game, and the note size when the context first reaches warn.
function CC-Evaluate($in) {
    $r = @{ ok = $false; due = $false; path = $null; day = -1; cycle = 0; last = 0; ctx = 0; warned = $false
            note = $null; prev = $null; missing = @(); speed = "" }
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

    # Cycle path: the cycle that just ended is cycle - 1, game days 2(c-1)-2 and 2(c-1)-1.
    $cycleDue = $false
    if ($cycle -gt $last) {
        $b = $cycle - 1
        $notes = @((CC-NotePath (2 * $b - 2)), (CC-NotePath (2 * $b - 1)))
        $r.missing = @($notes | Where-Object { -not (Test-Path -LiteralPath $_) })
        $cycleDue = ($r.missing.Count -eq 0)
    }

    # Context path.
    $contextDue = $false
    $note = CC-NotePath $day
    $r.note = $note
    if ($in -ne $null -and $in.transcript_path) {
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
    }
    if ($dirty) { CC-WriteJson $CC_CycleFile $state }

    $r.due = ($cycleDue -or $contextDue)
    if ($cycleDue) { $r.path = "cycle" } elseif ($contextDue) { $r.path = "context" }
    return $r
}
