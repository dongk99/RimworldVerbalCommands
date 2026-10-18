# pawns_watch.ps1 - hand every change of the colony's pawns to the playing agent as a notification (user, 2026-10-17: "A
# perpetually opened shell that only updates/notifies agent if the values change.").
#
# Arm it ONCE per session with the Monitor tool, next to watch.ps1; re-arm when the monitor expires or prints NOT RUNNING:
#   Monitor({ command: 'powershell -File "<skill folder>\pawns_watch.ps1"', description: 'RimWorld pawns', timeout_ms: 1800000 })
#   Monitor({ command: 'powershell -File "<skill folder>\pawns_watch.ps1" -Skip "wild animal"', ... })   leave out a category
#   -Only "colonist","prisoner"   only these categories. Categories (the word in [ ] after the name): colonist, slave,
#   prisoner, colony mech, colony animal, colony other, guest, visitor, trader, ally, traveller, stranger, mech, entity, other,
#   wild animal, "animal of <faction>". -Skip / -Only take wildcards ("animal of *").
#
# Reads only <SaveData>\VerbalCommands\pawn_watch.json, which the mod rewrites when something in it changes
# (src\VerbalCommands\AgentPawnWatch.cs). Nothing is sent to the game. Lines:
#   TIP: ...                                   the two tips, once, at the start (user, 2026-10-17)
#   PAWN Alice at 120, 85 (in bedroom): [colonist] | ... | combatmode: auto-engage    the whole line: at the start, for a pawn
#                                              new on the list (PAWN NEW), and whenever any value in it changed (1% steps)
#   PAWN Alice moved to 123, 85 (outdoors)    moved 3 cells or more since its last line (user: "3 cells")
#   Alice being attacked by raider 2 (...)    an attack started; "... is no longer being attacked by ..." when it ended
#   Alice being chased by mad snowhare 1 (...), 7 cells away
#   Alice being engaged in melee on 120, 85 from shooting, being attacked by raider 2 (...)   (user's words, 2026-10-17)
#   PAWN LEFT Kowalski [prisoner] left the list: died      / "... changed from prisoner to colonist (recruited)"
#   HOSTILES ON MAP: ...  /  HOSTILES GONE: ...            the hostile list started / ended (hostiles_watch.ps1)
#   NOT RUNNING: ...                           the game closed (then exits)

param(
    [string[]]$Skip = @(),
    [string[]]$Only = @(),
    [double]$Cells = 3,
    [int]$IntervalMs = 1000
)
$root = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands"
$file = Join-Path $root "pawn_watch.json"

function Read-Watch {
    # The mod rewrites the file by delete-then-move: a read can land in the gap, so try a few times.
    for ($i = 0; $i -lt 10; $i++) {
        try { $raw = [IO.File]::ReadAllText($file); if ($raw) { return ($raw | ConvertFrom-Json) } } catch { }
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
function Hostile-Line($j, [string]$word) {
    $n = Standing $j
    $all = @($j.hostiles).Count
    $names = (@($j.hostiles) | ForEach-Object { $_.name }) -join ", "
    if ($word -eq "ON") {
        "HOSTILES ON MAP: $n standing, $all on the hostile list ($names). Spawn the hostile_watch specialist (delegates\briefs\hostile_watch.md) if it is not running."
    } else {
        "HOSTILES GONE: no hostile is standing" + $(if ($all -gt 0) { "; still on the hostile list (downed): $names" } else { "" }) + "."
    }
}

$j = $null
for ($i = 0; $i -lt 10 -and $j -eq $null; $i++) { $j = Read-Watch; if ($j -eq $null) { Start-Sleep -Milliseconds 500 } }
if (-not (Get-Process -Name RimWorldWin64 -ErrorAction SilentlyContinue)) { "NOT RUNNING: RimWorld process not found"; exit 2 }
if ($j -eq $null) { "NOT RUNNING: $file not found or unreadable (the mod build with the pawn watch is not loaded, no colony is loaded, or 'Agent inbox' is off in the mod settings)"; exit 1 }

# The two tips, once (user, 2026-10-17: "Once at start of pawns shell output.").
"TIP: you can make pawns drop items or gear by saying drop {itemname} for {pawn}. Dropepd items from inventory are forbidden so you will have to enable them in order to interact with it again."
"TIP: you can treat visitors, allies, traders for faction relations bonus if they leave the map safely."

$pawns = @{}      # id -> @{ text; x; z }
$attacks = @{}    # key "id|attackkey" -> off line
$lastLeft = 0
if ($j.PSObject.Properties["last_left_seq"]) { $lastLeft = [int]$j.last_left_seq }
$lastUtc = "$($j.utc)"
$listed = @($j.pawns | Where-Object { Wanted $_.category })
"WATCHING pawns at $($j.when): $($listed.Count) listed" + $(if ($Skip.Count) { "; skipping " + ($Skip -join ", ") } else { "" }) + $(if ($Only.Count) { "; only " + ($Only -join ", ") } else { "" })
foreach ($p in $listed) {
    "PAWN $($p.name) at $($p.where): $($p.text)"
    $pawns["$($p.id)"] = @{ text = "$($p.text)"; x = [double]$p.x; z = [double]$p.z }
    foreach ($a in @($p.attacks)) { if ($a) { "$($a.on)"; $attacks["$($p.id)|$($a.key)"] = "$($a.off)" } }
}
$hostileOn = (Standing $j) -gt 0
if ($hostileOn) { Hostile-Line $j "ON" }

while ($true) {
    Start-Sleep -Milliseconds $IntervalMs
    if (-not (Get-Process -Name RimWorldWin64 -ErrorAction SilentlyContinue)) { "NOT RUNNING: RimWorld process not found"; exit 2 }
    $j = Read-Watch
    if ($j -eq $null -or "$($j.utc)" -eq $lastUtc) { continue }
    $lastUtc = "$($j.utc)"

    $now = @{}
    $nowAttacks = @{}
    foreach ($p in @($j.pawns)) {
        if (-not $p -or -not (Wanted $p.category)) { continue }
        $id = "$($p.id)"
        $now[$id] = $true
        $old = $pawns[$id]
        if ($old -eq $null) {
            "PAWN NEW $($p.name) at $($p.where): $($p.text)"
            $pawns[$id] = @{ text = "$($p.text)"; x = [double]$p.x; z = [double]$p.z }
        } elseif ("$($p.text)" -ne $old.text) {
            "PAWN $($p.name) at $($p.where): $($p.text)"
            $old.text = "$($p.text)"; $old.x = [double]$p.x; $old.z = [double]$p.z
        } elseif ((Dist $p $old.x $old.z) -ge $Cells) {
            "PAWN $($p.name) moved to $($p.where)"
            $old.x = [double]$p.x; $old.z = [double]$p.z
        }
        foreach ($a in @($p.attacks)) {
            if (-not $a) { continue }
            $k = "$id|$($a.key)"
            $nowAttacks[$k] = "$($a.off)"
            if (-not $attacks.ContainsKey($k)) { "$($a.on)" }
        }
    }
    foreach ($k in @($attacks.Keys)) { if (-not $nowAttacks.ContainsKey($k)) { $attacks[$k] } }
    $attacks = $nowAttacks
    foreach ($id in @($pawns.Keys)) { if (-not $now.ContainsKey($id)) { $pawns.Remove($id) } }

    if ($j.PSObject.Properties["left"]) {
        foreach ($e in @($j.left)) {
            if (-not $e -or [int]$e.seq -le $lastLeft) { continue }
            $lastLeft = [int]$e.seq
            if (Wanted $e.category) { "PAWN LEFT $($e.text)" }
        }
    }
    $on = (Standing $j) -gt 0
    if ($on -ne $hostileOn) {
        $hostileOn = $on
        if ($on) { Hostile-Line $j "ON" } else { Hostile-Line $j "GONE" }
    }
}
