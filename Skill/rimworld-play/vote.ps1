# vote.ps1 - an agent's vote to unpause after an hourly check (user, 2026-10-16: "Every goddamn subagent AND ORCHESTRAOR
# votes to UNPAUSE."). The mod (src\VerbalCommands\AgentHourlyCheck.cs) pauses the game every game hour that its scan has
# lines, hands the batch "[REMINDER] Hourly check N ..." to every agent (outbox results, watch.ps1, wait_round.ps1), and
# resumes at normal speed once every voter has voted for N: the orchestrator, and every specialist whose wait_round.ps1
# heartbeat is fresh. N is only in the batch, so a vote needs the batch.
#
#   powershell -File "<skill folder>\vote.ps1" -Name orchestrator -Check 17
#   powershell -File "<skill folder>\vote.ps1" -Name schedule -Check 17        (a specialist: its own -Name of wait_round.ps1)
#
# Writes <SaveData>\VerbalCommands\votes\<N>\<Name>.txt, then prints one line (wording approved by the user, 2026-10-16).
# Nothing is sent to the game's inbox.
# Stopped specialists (2026-10-17): every name N still waits for that has a stop file (delegates\stop\<name> or
# stop\ALL) gets its heartbeat <SaveData>\VerbalCommands\agents\<name>.txt deleted, so the mod drops it from N. A
# specialist whose call had already ended never ran wait_round.ps1 again to delete it, so the stop file alone left it
# on the vote (hostile_watch on check 466).

param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][int]$Check
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
if (-not (Get-Process -Name RimWorldWin64 -ErrorAction SilentlyContinue)) { "NOT RUNNING: RimWorld process not found"; exit 2 }

$j = Read-State
$h = if ($j -ne $null -and $j.PSObject.Properties["hourly"]) { $j.hourly } else { $null }
if ($h -eq $null) { "No hourly check is open."; exit 0 }
if ([int]$h.seq -ne $Check) { "$($h.pause_line)"; exit 0 }

$dl = Join-Path $root "delegates"
$stopAll = Test-Path (Join-Path $dl "stop\ALL")
$dropped = @()
foreach ($v in @($h.waiting_for)) {
    if (-not $v -or $v -eq "orchestrator") { continue }
    if ($stopAll -or (Test-Path (Join-Path $dl "stop\$v"))) {
        $b = Join-Path $root ("agents\" + $v + ".txt")
        try { if (Test-Path -LiteralPath $b) { Remove-Item -LiteralPath $b -Force -Confirm:$false } } catch { }
        $dropped += "$v"
    }
}

$dir = Join-Path $root ("votes\" + $Check)
New-Item -ItemType Directory -Force -Path $dir | Out-Null
[IO.File]::WriteAllText((Join-Path $dir ($Name + ".txt")), (Get-Date).ToUniversalTime().ToString("o"))

# The mod counts votes (and drops the deleted heartbeats) on its next poll; wait for it to show (at most about 10 s).
$deadline = (Get-Date).AddSeconds(10)
$missing = @(@($h.waiting_for) | Where-Object { $_ -and $_ -ne $Name -and -not ($dropped -contains $_) })
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
    $j = Read-State
    if ($j -eq $null) { continue }
    $h2 = if ($j.PSObject.Properties["hourly"]) { $j.hourly } else { $null }
    if ($h2 -eq $null -or [int]$h2.seq -ne $Check) { $missing = @(); break }
    $now = @(@($h2.waiting_for) | Where-Object { $_ })
    if (-not ($now -contains $Name) -and @($now | Where-Object { $dropped -contains $_ }).Count -eq 0) { $missing = $now; break }
}
if ($missing.Count -eq 0) { "Hourly check ${Check}: every vote is in; the game runs at normal speed." }
else { "Hourly check $Check is waiting for votes from: " + ($missing -join ", ") + "." }
exit 0
