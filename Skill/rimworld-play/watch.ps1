# watch.ps1 - hand every new line of inbox_state.json to the playing agent as a notification.
#
# Arm it ONCE per session with the Monitor tool (not Bash): each stdout line becomes a prompt in the agent's chat
# the moment it is printed, with nothing sent to the game. Re-arm when the monitor expires (30 min at most).
#   Monitor({ command: 'powershell -File "<skill folder>\watch.ps1"', description: 'RimWorld inbox_state events', timeout_ms: 1800000 })
#
# One line per NEW game event (`events` in inbox_state.json: letters, messages, pawn states; the mod rewrites the file
# whenever AgentEvents gets one, user 2026-10-12), one line when the inbox starts waiting for an answer, and one when
# the game stops or starts moving. Nothing else; nothing on a plain tick.
# Lines:  EVENT seq=12 [day 5, 14h] letter: Raid (big threat, needs a choice)
#         WAITING ask: <question>      WAITING plan   WAITING none
#         GAME paused day 5 19h (speed Fast)   /   GAME running day 5 19h (speed Fast)
#         NOT RUNNING: RimWorld process not found (then exits)
#         [REMINDER] Hourly check N ... and "Hourly check N: ... vote: vote.ps1 -Name orchestrator -Check N" when the mod
#         opens an hourly check (src\VerbalCommands\AgentHourlyCheck.cs, 2026-10-16), and once at the start if one is open.

param([int]$IntervalMs = 1000)
$state = "$env:USERPROFILE\AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\inbox_state.json"

function Read-State {
    try {
        $raw = Get-Content $state -Raw -ErrorAction Stop
        if ($raw -eq $null -or $raw.Trim() -eq "") { return $null }
        return ($raw | ConvertFrom-Json)
    } catch { return $null }
}

$j = $null
for ($i = 0; $i -lt 10 -and $j -eq $null; $i++) { $j = Read-State; if ($j -eq $null) { Start-Sleep -Milliseconds 500 } }
if ($j -eq $null) { "NOT RUNNING: inbox_state.json unreadable at $state"; exit 1 }

# Start from the current state: events already in the file were there before the watch, not new.
$lastSeq = 0
if ($j.PSObject.Properties["last_event_seq"]) { $lastSeq = [int]$j.last_event_seq }
$lastPaused = [bool]$j.paused
$lastWaiting = "$($j.waiting)"
$lastUtc = "$($j.utc)"
"WATCHING from event seq $lastSeq; game " + $(if ($lastPaused) { "paused" } else { "running" }) + " day $($j.game.day) $($j.game.hour)h (speed $($j.speed))"

# The open hourly check: its batch and vote line, each time a new one opens (and the one open now, if any).
$lastHourly = 0
function Show-Hourly($j) {
    if ($j -eq $null -or -not $j.PSObject.Properties["hourly"] -or $j.hourly -eq $null) { return }
    if ([int]$j.hourly.seq -eq $script:lastHourly) { return }
    $script:lastHourly = [int]$j.hourly.seq
    "$($j.hourly.text)"
    "$($j.hourly.pause_line)" -replace '-Name NAME', '-Name orchestrator'
}
Show-Hourly $j

while ($true) {
    Start-Sleep -Milliseconds $IntervalMs
    if (-not (Get-Process -Name RimWorldWin64 -ErrorAction SilentlyContinue)) { "NOT RUNNING: RimWorld process not found"; exit 2 }
    $j = Read-State
    if ($j -eq $null) { continue }
    if ("$($j.utc)" -eq $lastUtc) { continue }
    $lastUtc = "$($j.utc)"

    if ($j.PSObject.Properties["events"]) {
        foreach ($e in @($j.events)) {
            if ([int]$e.seq -le $lastSeq) { continue }
            $lastSeq = [int]$e.seq
            "EVENT seq=$($e.seq) [$($e.when)] $($e.kind): $($e.text)"
        }
    }
    Show-Hourly $j
    $waiting = "$($j.waiting)"
    if ($waiting -ne $lastWaiting) {
        $lastWaiting = $waiting
        if ($waiting -eq "ask") { "WAITING ask: $($j.question)" } else { "WAITING $waiting" }
    }
    $paused = [bool]$j.paused
    if ($paused -ne $lastPaused) {
        $lastPaused = $paused
        "GAME " + $(if ($paused) { "paused" } else { "running" }) + " day $($j.game.day) $($j.game.hour)h (speed $($j.speed))"
    }
}
