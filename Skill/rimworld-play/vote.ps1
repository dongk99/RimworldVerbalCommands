# vote.ps1 - the orchestrator's votes. Only the orchestrator votes (user, 2026-10-19: "the 1-hour reminder does not need
# specialist voting. I dont trust haikus to vote intelligently. same goes for compaction vote").
#
#   powershell -File "<skill folder>\vote.ps1" -Name orchestrator -Check 17     unpause after hourly check 17
# The compaction vote (-Compact) is gone since 2026-10-19 (user: "no fucking votes from anyone, not even orchestrator.");
# compaction now follows the day notes alone (compact_common.ps1).
#
# Hourly check (user, 2026-10-16): the mod (src\VerbalCommands\AgentHourlyCheck.cs) pauses the game every game hour that
# its scan has lines, hands the batch "[REMINDER] Hourly check N ..." to the agents through watch.ps1 and wait_round.ps1,
# once per check (since 2026-10-19 no longer on outbox results; user, 2026-10-19: "it would be REMINDER list that would
# get spammed until they vote, which autopause game, so it shouldnt even be spamming to them."), and resumes at normal
# speed once the orchestrator has voted for N. N is only in the batch, so a vote
# needs the batch. Writes <SaveData>\VerbalCommands\votes\<N>\orchestrator.txt, then prints one line (wording approved
# by the user, 2026-10-16). Nothing is sent to the game's inbox.

param(
    [Parameter(Mandatory = $true)][string]$Name,
    [int]$Check = 0
)
$ErrorActionPreference = "Continue"
$root = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands"
$state = Join-Path $root "inbox_state.json"

function Read-State {
    # The mod rewrites the file by delete-then-move: a read can land in the gap, so try a few times.
    for ($i = 0; $i -lt 20; $i++) {
        try { $raw = [IO.File]::ReadAllText($state); if ($raw) { return ($raw | ConvertFrom-Json) } } catch { }
        Start-Sleep -Milliseconds 100
    }
    return $null
}

$Name = $Name.Trim()
if ($Name -notmatch '^[A-Za-z0-9_\-]+$') { "Name: letters, digits, _ and - only."; exit 1 }
if ($Name -ne "orchestrator") { "Only the orchestrator votes."; exit 0 }
if (-not (Get-Process -Name RimWorldWin64 -ErrorAction SilentlyContinue)) { "NOT RUNNING: RimWorld process not found"; exit 2 }

if ($Check -le 0) { "Give -Check N (the hourly check's number)."; exit 1 }
$j = Read-State
$h = if ($j -ne $null -and $j.PSObject.Properties["hourly"]) { $j.hourly } else { $null }
if ($h -eq $null) { "No hourly check is open."; exit 0 }
if ([int]$h.seq -ne $Check) { "$($h.pause_line)"; exit 0 }

$dir = Join-Path $root ("votes\" + $Check)
New-Item -ItemType Directory -Force -Path $dir | Out-Null
[IO.File]::WriteAllText((Join-Path $dir ($Name + ".txt")), (Get-Date).ToUniversalTime().ToString("o"))

# The mod counts the vote on its next poll; wait for it to show (at most about 10 s).
$deadline = (Get-Date).AddSeconds(10)
$closed = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
    $j = Read-State
    if ($j -eq $null) { continue }
    $h2 = if ($j.PSObject.Properties["hourly"]) { $j.hourly } else { $null }
    if ($h2 -eq $null -or [int]$h2.seq -ne $Check) { $closed = $true; break }
}
if ($closed) { "Hourly check ${Check}: every vote is in; the game runs at normal speed." }
else { "Hourly check $Check is waiting for votes from: orchestrator." }
exit 0
