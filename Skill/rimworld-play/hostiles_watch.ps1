# hostiles_watch.ps1 - every hostile in view, and every change of one (user, 2026-10-17: "shows pawns on entire map that is
# hostile (separate shell) with their coordinate, health (abbreviated, shows by how wounded they are, movement %, manipulation
# %, consciousness %, whether they are downed or not). Does not launch if there is no hostile pawns/animals present." / "hostile
# list should have separate shell and launch separate subagent for looking at hostile list" / "3 cells, not 5").
#
# Two ways to run it:
#   powershell -File "<skill folder>\hostiles_watch.ps1"
#       perpetual (Monitor tool): the whole list, then every change, until no hostile is standing (then exits).
#   powershell -File "<skill folder>\hostiles_watch.ps1" -Name hostile_watch
#       the hostile_watch specialist's round (delegates\briefs\hostile_watch.md): prints the list (all of it on the first call,
#       later only what changed since its last call), then blocks until something changes, gathers changes for -GatherSec
#       more seconds, prints them and exits. Like wait_round.ps1 it prints STOP / MESSAGE / the open hourly check's batch
#       (once per check; only the orchestrator votes, user 2026-10-19) and exits.
#   -Skip "animal" / -Only "humanlike","mech"   categories: humanlike, animal, mech, insect, entity, other (wildcards allowed)
#
# Exits at once with "NO HOSTILES: ..." when nothing hostile is in view. Reads only <SaveData>\VerbalCommands\pawn_watch.json
# (src\VerbalCommands\AgentPawnWatch.cs) and inbox_state.json; nothing is sent to the game. Lines:
#   HOSTILE raider 2 at 140, 92 (outdoors; 20 tiles east of Bob): raider 2 (Kowalski, pirate, Pirate Gang (hostile), humanlike)
#     holding bolt-action rifle (good) (ranged) | health 64%, pain 30%, bleeding 20%/day (bleeds out in 1.2 days), moving 80%,
#     manipulation 100%, consciousness 90% | 3 wounds | attacking Alice at 131, 88 | nearest colonist Alice 6 cells away
#                                  (one line; HOSTILE NEW for a hostile new on the list; again whenever a value changed)
#   HOSTILE raider 2 moved to 137, 92 (...) | nearest colonist Alice 3 cells away      moved 3 cells or more
#   HOSTILE LEFT raider 2 left the hostile list: killed     (captured / no longer hostile / out of view / left the map)
#   HOSTILES GONE: no hostile is standing ...               (perpetual mode exits after it)

param(
    [string]$Name = "",
    [string[]]$Skip = @(),
    [string[]]$Only = @(),
    [double]$Cells = 3,
    [int]$GatherSec = 5,
    [int]$MaxMinutes = 9,
    [int]$IntervalMs = 1000
)
$ErrorActionPreference = "Continue"
$root = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands"
$file = Join-Path $root "pawn_watch.json"
$stateFile = Join-Path $root "inbox_state.json"
$dl = Join-Path $root "delegates"

function Read-Json($path) {
    for ($i = 0; $i -lt 10; $i++) {
        try { $raw = [IO.File]::ReadAllText($path); if ($raw) { return ($raw | ConvertFrom-Json) } } catch { }
        Start-Sleep -Milliseconds 100
    }
    return $null
}
function Wanted([string]$category) {
    foreach ($s in $Skip) { if ($category -like $s) { return $false } }
    if ($Only.Count -eq 0) { return $true }
    foreach ($o in $Only) { if ($category -like $o) { return $true } }
    return $false
}
function Dist($a, $x, $z) { return [math]::Sqrt([math]::Pow([double]$a.x - $x, 2) + [math]::Pow([double]$a.z - $z, 2)) }
function Standing($j) { if ($j.PSObject.Properties["hostiles_standing"]) { return [int]$j.hostiles_standing } else { return 0 } }
function Gone-Line($j) {
    $names = (@($j.hostiles) | Where-Object { $_ } | ForEach-Object { "$($_.name) at $($_.where)" }) -join "; "
    "HOSTILES GONE: no hostile is standing" + $(if ($names) { "; still on the hostile list (downed): $names" } else { "" }) + "."
}

# The specialist's side (only with -Name): stop / message files, the open hourly check. Same as wait_round.ps1.
$seenDir = Join-Path $root "play_sessions\hourly_seen"
$seenFile = Join-Path $seenDir "$Name.txt"
function Check-Files {
    if (-not $Name) { return $null }
    if ((Test-Path (Join-Path $dl "stop\$Name")) -or (Test-Path (Join-Path $dl "stop\ALL"))) { return "STOP ${Name}: stop file found; return to the orchestrator now." }
    $msg = Join-Path $dl "msg\$Name.md"
    if (Test-Path $msg) { return "MESSAGE ${Name}: read and delete $msg, then act on it." }
    return $null
}
function Hourly-Lines {
    if (-not $Name) { return $null }
    $s = Read-Json $stateFile
    if ($s -eq $null -or -not $s.PSObject.Properties["hourly"] -or $s.hourly -eq $null) { return $null }
    $n = [int]$s.hourly.seq
    $last = 0
    try { if (Test-Path -LiteralPath $seenFile) { $last = [int](Get-Content -LiteralPath $seenFile -TotalCount 1) } } catch { }
    if ($n -eq $last) { return $null }
    try { New-Item -ItemType Directory -Force -Path $seenDir | Out-Null; [IO.File]::WriteAllText($seenFile, "$n") } catch { }
    return @("$($s.hourly.text)")
}

# What was last printed, kept between the specialist's calls (perpetual mode keeps it in memory only).
$memFile = if ($Name) { Join-Path $dl "status\$Name.hostiles_seen.json" } else { $null }
$seen = @{}       # id -> @{ text; x; z }
$lastLeft = -1
$lastTick = -1
if ($memFile -and (Test-Path $memFile)) {
    $m = Read-Json $memFile
    if ($m -ne $null) {
        $lastLeft = [int]$m.last_left; $lastTick = [long]$m.tick
        foreach ($e in @($m.seen)) { if ($e) { $seen["$($e.id)"] = @{ text = "$($e.text)"; x = [double]$e.x; z = [double]$e.z } } }
    }
}
function Save-Mem($j) {
    if (-not $memFile) { return }
    $list = @(); foreach ($k in $seen.Keys) { $list += @{ id = $k; text = $seen[$k].text; x = $seen[$k].x; z = $seen[$k].z } }
    try { [IO.File]::WriteAllText($memFile, (@{ last_left = $lastLeft; tick = [long]$j.tick; seen = $list } | ConvertTo-Json -Depth 4)) } catch { }
}

# The lines for what changed since $seen; updates $seen and $lastLeft.
function Diff-Lines($j) {
    $out = @()
    $now = @{}
    foreach ($h in @($j.hostiles)) {
        if (-not $h -or -not (Wanted $h.category)) { continue }
        $id = "$($h.id)"
        $now[$id] = $true
        $old = $seen[$id]
        if ($old -eq $null) {
            $out += "HOSTILE NEW $($h.name) at $($h.where): $($h.text) | $($h.nearest)"
            $seen[$id] = @{ text = "$($h.text)"; x = [double]$h.x; z = [double]$h.z }
        } elseif ("$($h.text)" -ne $old.text) {
            $out += "HOSTILE $($h.name) at $($h.where): $($h.text) | $($h.nearest)"
            $old.text = "$($h.text)"; $old.x = [double]$h.x; $old.z = [double]$h.z
        } elseif ((Dist $h $old.x $old.z) -ge $Cells) {
            $out += "HOSTILE $($h.name) moved to $($h.where) | $($h.nearest)"
            $old.x = [double]$h.x; $old.z = [double]$h.z
        }
    }
    foreach ($id in @($seen.Keys)) { if (-not $now.ContainsKey($id)) { $seen.Remove($id) } }
    if ($j.PSObject.Properties["hostiles_left"]) {
        foreach ($e in @($j.hostiles_left)) {
            if (-not $e -or [int]$e.seq -le $script:lastLeft) { continue }
            $script:lastLeft = [int]$e.seq
            if (Wanted $e.category) { $out += "HOSTILE LEFT $($e.text)" }
        }
    }
    return ,$out
}

if (-not (Get-Process -Name RimWorldWin64 -ErrorAction SilentlyContinue)) { "NOT RUNNING: RimWorld process not found"; exit 2 }
$line = Check-Files
if ($line) { $line; exit 0 }
$hl = Hourly-Lines
if ($hl) { $hl; exit 0 }
$j = Read-Json $file
if ($j -eq $null) { "NOT RUNNING: $file not found or unreadable (the mod build with the pawn watch is not loaded, no colony is loaded, or 'Agent inbox' is off in the mod settings)"; exit 1 }
# A saved memory from another game load (the tick went back) is dropped.
if ($lastTick -gt [long]$j.tick) { $seen = @{}; $lastLeft = -1 }
if ($lastLeft -lt 0 -and $j.PSObject.Properties["last_hostiles_left_seq"]) { $lastLeft = [int]$j.last_hostiles_left_seq }
$listed = @($j.hostiles | Where-Object { $_ -and (Wanted $_.category) })
if ((Standing $j) -eq 0 -and $listed.Count -eq 0) {
    Save-Mem $j
    "NO HOSTILES: nothing hostile is in view at $($j.when). Not watching."
    exit 0
}

if (-not $Name) {
    # Perpetual: the whole list, then every change, until no hostile is standing.
    "WATCHING hostiles at $($j.when): $($listed.Count) on the list, $(Standing $j) standing" + $(if ($Skip.Count) { "; skipping " + ($Skip -join ", ") } else { "" }) + $(if ($Only.Count) { "; only " + ($Only -join ", ") } else { "" })
    foreach ($l in (Diff-Lines $j)) { $l }
    $lastUtc = "$($j.utc)"
    while ($true) {
        Start-Sleep -Milliseconds $IntervalMs
        if (-not (Get-Process -Name RimWorldWin64 -ErrorAction SilentlyContinue)) { "NOT RUNNING: RimWorld process not found"; exit 2 }
        $j = Read-Json $file
        if ($j -eq $null -or "$($j.utc)" -eq $lastUtc) { continue }
        $lastUtc = "$($j.utc)"
        foreach ($l in (Diff-Lines $j)) { $l }
        if ((Standing $j) -eq 0) { Gone-Line $j; exit 0 }
    }
}

# Specialist round: what changed since the last call (everything on the first), else block until something changes.
$lines = Diff-Lines $j
if ($lines.Count -gt 0) {
    "HOSTILES at $($j.when): $($listed.Count) on the list, $(Standing $j) standing"
    $lines
    if ((Standing $j) -eq 0) { Gone-Line $j }
    Save-Mem $j
    exit 0
}
$lastUtc = "$($j.utc)"
$deadline = (Get-Date).AddMinutes($MaxMinutes)
$collected = @()
$gatherUntil = $null
while ($true) {
    Start-Sleep -Milliseconds $IntervalMs
    if (-not (Get-Process -Name RimWorldWin64 -ErrorAction SilentlyContinue)) { Save-Mem $j; "NOT RUNNING: RimWorld process not found"; exit 2 }
    $line = Check-Files
    if ($line) { $collected; Save-Mem $j; $line; exit 0 }
    $hl = Hourly-Lines
    if ($hl) { $collected; Save-Mem $j; $hl; exit 0 }
    $n = Read-Json $file
    if ($n -ne $null -and "$($n.utc)" -ne $lastUtc) {
        $j = $n
        $lastUtc = "$($j.utc)"
        $new = Diff-Lines $j
        if ($new.Count -gt 0) {
            $collected += $new
            if ($gatherUntil -eq $null) { $gatherUntil = (Get-Date).AddSeconds($GatherSec) }
        }
        if ((Standing $j) -eq 0) {
            "HOSTILES at $($j.when)"
            $collected; Gone-Line $j; Save-Mem $j; exit 0
        }
    }
    if ($gatherUntil -ne $null -and (Get-Date) -ge $gatherUntil) {
        "HOSTILES at $($j.when): $(@($j.hostiles).Count) on the list, $(Standing $j) standing"
        $collected; Save-Mem $j; exit 0
    }
    if ((Get-Date) -gt $deadline) {
        Save-Mem $j
        "TIMEOUT: $MaxMinutes real minutes with no change on the hostile list ($(@($j.hostiles).Count) listed, $(Standing $j) standing at $($j.when)); call again."
        exit 0
    }
}
