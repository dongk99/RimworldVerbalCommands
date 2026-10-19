# wait_round.ps1 - a specialist subagent blocks here between its rounds (user, 2026-10-13: specialists work "more or
# less autonomously unless the orchestrator stops them"). Prints ONE line and exits; the specialist reads it and
# either does its next round or returns to the orchestrator.
#
#   powershell -File "<skill folder>\wait_round.ps1" -Name schedule -Hours 6
#   powershell -File "<skill folder>\wait_round.ps1" -Name drafter -Hours 2 -OnEvent 'raid|threat|manhunter|mental|downed|hostile'
#
# Lines (first word is the verdict):
#   STOP       <name>: the orchestrator put a stop file down (delegates\stop\<name> or delegates\stop\ALL) -> return now
#   MESSAGE    <name>: delegates\msg\<name>.md exists -> read it, delete it, act on it
#   HOURS      day D Hh: at least -Hours game hours passed since the call began -> next round
#   EVENT      seq=N [day D, Hh] kind: text  (only with -OnEvent; one line per matching event, then exit) -> react
#   TIMEOUT    -MaxMinutes real minutes passed with the game paused or slow -> next round anyway (check `show speed.`)
#   NOT RUNNING: RimWorld process not found -> return to the orchestrator
#   [REMINDER] Hourly check N ...  (the mod's open hourly check: its batch, once per check for this name) -> read, act
#              on what is yours. Only the orchestrator votes (user, 2026-10-19: "the 1-hour reminder does not need
#              specialist voting" / "Yes, they do need a reminder, but no vote."); the check last handed to this name
#              is kept in play_sessions\hourly_seen\<name>.txt.
# Nothing is sent to the game. Only inbox_state.json is read (tick, events, hourly) and the delegates folder.

param(
    [Parameter(Mandatory = $true)][string]$Name,
    [double]$Hours = 6,
    [string]$OnEvent = "",
    [int]$MaxMinutes = 25,
    [int]$IntervalMs = 2000
)
$ErrorActionPreference = "Continue"
$dl = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\delegates"
$state = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\inbox_state.json"
$stopMine = Join-Path $dl "stop\$Name"
$stopAll = Join-Path $dl "stop\ALL"
$msg = Join-Path $dl "msg\$Name.md"
$seenDir = Join-Path (Split-Path $dl -Parent) "play_sessions\hourly_seen"
$seenFile = Join-Path $seenDir "$Name.txt"

# The open hourly check's batch, the first time this name meets that check, or $null.
function Hourly-Lines($j) {
    if ($j -eq $null -or -not $j.PSObject.Properties["hourly"] -or $j.hourly -eq $null) { return $null }
    $n = [int]$j.hourly.seq
    $last = 0
    try { if (Test-Path -LiteralPath $seenFile) { $last = [int](Get-Content -LiteralPath $seenFile -TotalCount 1) } } catch { }
    if ($n -eq $last) { return $null }
    try { New-Item -ItemType Directory -Force -Path $seenDir | Out-Null; [IO.File]::WriteAllText($seenFile, "$n") } catch { }
    return @("$($j.hourly.text)")
}

function Read-State {
    try { $raw = Get-Content $state -Raw -ErrorAction Stop; if (-not $raw) { return $null }; return ($raw | ConvertFrom-Json) } catch { return $null }
}
# Returns the STOP/MESSAGE line, or $null. (It used to print the line and return $true inside `if (Check-Files)`,
# which swallowed the line: the specialist got empty output on a stop.)
function Check-Files {
    if ((Test-Path $stopMine) -or (Test-Path $stopAll)) { return "STOP ${Name}: stop file found; return to the orchestrator now." }
    if (Test-Path $msg) { return "MESSAGE ${Name}: read and delete $msg, then act on it." }
    return $null
}

$line = Check-Files
if ($line) { $line; exit 0 }
$j = Read-State
if ($j -eq $null) { "NOT RUNNING: inbox_state.json unreadable"; exit 2 }
$hl = Hourly-Lines $j
if ($hl) { $hl; exit 0 }
$t0 = [long]$j.game.tick
$seq = 0
if ($j.PSObject.Properties["last_event_seq"]) { $seq = [int]$j.last_event_seq }
$target = $t0 + [long]($Hours * 2500)        # 2500 ticks = 1 game hour
$deadline = (Get-Date).AddMinutes($MaxMinutes)

while ($true) {
    Start-Sleep -Milliseconds $IntervalMs
    if (-not (Get-Process -Name RimWorldWin64 -ErrorAction SilentlyContinue)) { "NOT RUNNING: RimWorld process not found"; exit 2 }
    $line = Check-Files
    if ($line) { $line; exit 0 }
    $j = Read-State
    if ($j -eq $null) { continue }
    $hl = Hourly-Lines $j
    if ($hl) { $hl; exit 0 }
    if ($OnEvent -ne "" -and $j.PSObject.Properties["events"]) {
        $hit = $false
        foreach ($e in @($j.events)) {
            if ([int]$e.seq -le $seq) { continue }
            $seq = [int]$e.seq
            if ("$($e.kind): $($e.text)" -match $OnEvent) { "EVENT seq=$($e.seq) [$($e.when)] $($e.kind): $($e.text)"; $hit = $true }
        }
        if ($hit) { exit 0 }
    }
    if ([long]$j.game.tick -ge $target) { "HOURS day $($j.game.day) $($j.game.hour)h: $Hours game hours passed (speed $($j.speed))"; exit 0 }
    if ((Get-Date) -gt $deadline) { "TIMEOUT: $MaxMinutes real minutes passed; game at day $($j.game.day) $($j.game.hour)h, speed $($j.speed), paused=$($j.paused)"; exit 0 }
}
