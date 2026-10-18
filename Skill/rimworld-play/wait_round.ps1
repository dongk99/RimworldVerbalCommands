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
#   [REMINDER] Hourly check N ...  (the mod's open hourly check, while this name has not voted for it: the batch, then
#              "Hourly check N: ... Read them, then vote: vote.ps1 -Name NAME -Check N") -> read, act, vote
# Nothing is sent to the game. Only inbox_state.json is read (tick, events, hourly) and the delegates folder.
# Heartbeat (2026-10-16, hourly check): <SaveData>\VerbalCommands\agents\<name>.txt is rewritten while this waits; the mod
# counts a specialist as a voter while it is under 30 minutes old (src\VerbalCommands\AgentHourlyCheck.cs). STOP and
# NOT RUNNING delete it.

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
$agentsDir = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\agents"
$beat = Join-Path $agentsDir "$Name.txt"
$lastBeat = [datetime]::MinValue

function Write-Beat {
    try {
        New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
        [IO.File]::WriteAllText($beat, (Get-Date).ToUniversalTime().ToString("o"))
        $script:lastBeat = Get-Date
    } catch { }
}
function Remove-Beat { try { if (Test-Path $beat) { Remove-Item -LiteralPath $beat -Force } } catch { } }
# The open hourly check's batch and vote line while this name has not voted, or $null.
function Hourly-Lines($j) {
    if ($j -eq $null -or -not $j.PSObject.Properties["hourly"] -or $j.hourly -eq $null) { return $null }
    if (-not (@($j.hourly.waiting_for) -contains $Name)) { return $null }
    return @("$($j.hourly.text)", ("$($j.hourly.pause_line)" -replace '-Name NAME', "-Name $Name"))
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
if ($line) { if ($line -like "STOP*") { Remove-Beat }; $line; exit 0 }
Write-Beat
$j = Read-State
if ($j -eq $null) { Remove-Beat; "NOT RUNNING: inbox_state.json unreadable"; exit 2 }
$hl = Hourly-Lines $j
if ($hl) { $hl; exit 0 }
$t0 = [long]$j.game.tick
$seq = 0
if ($j.PSObject.Properties["last_event_seq"]) { $seq = [int]$j.last_event_seq }
$target = $t0 + [long]($Hours * 2500)        # 2500 ticks = 1 game hour
$deadline = (Get-Date).AddMinutes($MaxMinutes)

while ($true) {
    Start-Sleep -Milliseconds $IntervalMs
    if (-not (Get-Process -Name RimWorldWin64 -ErrorAction SilentlyContinue)) { Remove-Beat; "NOT RUNNING: RimWorld process not found"; exit 2 }
    $line = Check-Files
    if ($line) { if ($line -like "STOP*") { Remove-Beat }; $line; exit 0 }
    if (((Get-Date) - $lastBeat).TotalSeconds -ge 30) { Write-Beat }
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
