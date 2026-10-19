# vote.ps1 - the orchestrator's votes. Only the orchestrator votes (user, 2026-10-19: "the 1-hour reminder does not need
# specialist voting. I dont trust haikus to vote intelligently. same goes for compaction vote").
#
#   powershell -File "<skill folder>\vote.ps1" -Name orchestrator -Check 17     unpause after hourly check 17
#   powershell -File "<skill folder>\vote.ps1" -Name orchestrator -Compact      vote for compaction
#
# Hourly check (user, 2026-10-16): the mod (src\VerbalCommands\AgentHourlyCheck.cs) pauses the game every game hour that
# its scan has lines, hands the batch "[REMINDER] Hourly check N ..." to every agent (outbox results, watch.ps1,
# wait_round.ps1), and resumes at normal speed once the orchestrator has voted for N. N is only in the batch, so a vote
# needs the batch. Writes <SaveData>\VerbalCommands\votes\<N>\orchestrator.txt, then prints one line (wording approved
# by the user, 2026-10-16). Nothing is sent to the game's inbox.
#
# -Compact (user, 2026-10-19; rules in compact_common.ps1): only while a compaction is due (compact_block.ps1 wrote
# play_sessions\compact_now.json for this very call). It pauses the game ("Compact vote pauses"), records the vote with
# the size of every running specialist's delegates\status\<name>.md in play_sessions\compact_vote.json, puts down
# delegates\stop\ALL (a specialist waiting in wait_round.ps1 / hostiles_watch.ps1 gets STOP at once; the PostToolUse
# hook then tells it to write its note and return), and returns once every one of those notes has grown, or 30 s after
# the vote ("no 90s, 30s"), so the next request reaches the PreCompact gate with the condition already met.

param(
    [Parameter(Mandatory = $true)][string]$Name,
    [int]$Check = 0,
    [switch]$Compact
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

if ($Compact) {
    . (Join-Path $PSScriptRoot "compact_common.ps1")
    $sid = [string]$env:CLAUDE_CODE_SESSION_ID
    $now = CC-ReadJson $CC_NowFile
    if ($null -eq $now -or -not $now.due -or ($sid -and [string]$now.session -ne $sid)) { "No compaction is due."; exit 0 }
    if ($null -ne (CC-Vote $sid)) { "The compaction vote is already in. End your turn."; exit 0 }

    & (Join-Path $PSScriptRoot "send.ps1") -Text "set game speed to paused."

    $notes = @{}
    foreach ($n in ((CC-Running $sid).Values | Sort-Object -Unique)) { if ($n) { $notes[$n] = CC-Size (CC-StatusPath $n) } }
    $utc = (Get-Date).ToUniversalTime()
    CC-WriteJson $CC_VoteFile @{ session = $sid; utc = $utc.ToString("o"); path = [string]$now.path; day = [int]$now.day
                                 cycle = [int]$now.cycle; notes = $notes }
    $stopDir = Join-Path $CC_Proj "delegates\stop"
    New-Item -ItemType Directory -Force -Path $stopDir | Out-Null
    [IO.File]::WriteAllText((Join-Path $stopDir "ALL"), "orchestrator: compaction vote`n")

    # Wait for the notes: woken by changes in delegates\status, never past 30 s after the vote.
    $deadline = $utc.AddSeconds($CC_WaitSec)
    $left = @($notes.Keys)
    $fsw = $null
    if ($left.Count -gt 0 -and (Test-Path -LiteralPath $CC_Status)) { $fsw = New-Object IO.FileSystemWatcher($CC_Status, "*.md") }
    while ($true) {
        $left = @($left | Where-Object { (CC-Size (CC-StatusPath $_)) -le [long]$notes[$_] })
        $ms = [int]($deadline - (Get-Date).ToUniversalTime()).TotalMilliseconds
        if ($left.Count -eq 0 -or $ms -le 0 -or $null -eq $fsw) { break }
        [void]$fsw.WaitForChanged([IO.WatcherChangeTypes]::All, $ms)
    }
    if ($fsw) { $fsw.Dispose() }
    $done = $notes.Count - $left.Count
    "Compaction vote is in; status notes updated: $done of $($notes.Count)" + $(if ($left.Count) { " (not: " + ($left -join ", ") + ")" } else { "" }) + ". End your turn."
    exit 0
}

if ($Check -le 0) { "Give -Check N (the hourly check's number) or -Compact."; exit 1 }
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
