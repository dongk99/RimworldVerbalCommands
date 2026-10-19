# pawns_watch.ps1 - hand every change of the colony's pawns to the playing agent as a notification (user, 2026-10-17: "A
# perpetually opened shell that only updates/notifies agent if the values change.").
#
# Start it ONCE per session in the background with -Feed, next to watch.ps1 -Feed (PowerShell tool, run_in_background:
# true); the agent reads its lines with next.ps1. Start it again after NOT RUNNING:
#   powershell -File "<skill folder>\pawns_watch.ps1" -Feed
#   powershell -File "<skill folder>\pawns_watch.ps1" -Feed -Skip "wild animal"     leave out a category
#   -Only "colonist","prisoner"   only these categories. Categories (the word in [ ] after the name): colonist, slave,
#   prisoner, colony mech, colony animal, colony other, guest, visitor, trader, ally, traveller, stranger, mech, entity, other,
#   wild animal, "animal of <faction>". -Skip / -Only take wildcards ("animal of *").
#
# Reads only <SaveData>\VerbalCommands\pawn_watch.json, which the mod rewrites when something in it changes
# (src\VerbalCommands\AgentPawnWatch.cs). Nothing is sent to the game. Lines:
#   TIP: ...                                   the two tips, once, at the start (user, 2026-10-17)
#   PAWN Alice at 120, 85 (in bedroom): [colonist] | ... | combatmode: auto-engage    the whole line: at the start, and for a
#                                              pawn new on the list (PAWN NEW)
#   PAWN Alice: consciousness 74%, hauling Steel x20; no longer: hauling Wood x29    only what changed in its line (1% steps)
#                                              (user, 2026-10-19: "only have it change whatever it is changed, so it doesnt
#                                              fucking eat into context"; it printed the whole line on every change before)
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
    [int]$IntervalMs = 1000,
    [switch]$Feed
)
$root = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands"

# -Feed: as watch.ps1 -Feed (user, 2026-10-19: "do find a way to get rid of system notification - not user input."). Started
# in the background, not as a Monitor; every line is appended to <SaveData>\VerbalCommands\feed\<session>_pawns.log and
# next.ps1 hands the new lines to the agent as its own tool result.
if ($Feed) {
    $sid = ([string]$env:CLAUDE_CODE_SESSION_ID).ToLowerInvariant() -replace '[^0-9a-f]', ''
    $sid = $(if ($sid.Length -ge 8) { $sid.Substring(0, 8) } else { "nosessio" })
    $dir = Join-Path $root "feed"
    New-Item -ItemType Directory -Force $dir | Out-Null
    $out = Join-Path $dir "${sid}_pawns.log"
    $enc = New-Object Text.UTF8Encoding $false
    & $PSCommandPath -Skip $Skip -Only $Only -Cells $Cells -IntervalMs $IntervalMs | ForEach-Object {
        $line = "$_`r`n"
        for ($i = 0; $i -lt 3; $i++) { try { [IO.File]::AppendAllText($out, $line, $enc); break } catch { } }
    }
    exit
}
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
# The parts of a pawn's line: its " | " sections split at ", " and "; ". A section's label ("conditions: A; B") goes on
# each of its parts ("conditions: A", "conditions: B"), so a part keeps its name when the one before it goes.
function Parts([string]$text) {
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($seg in ($text -split ' \| ')) {
        $label = ""
        if ($seg -match '^([a-z][a-z ]*): (.*)$') { $label = $Matches[1] + ": "; $seg = $Matches[2] }
        foreach ($it in ($seg -split ', |; ')) { $t = $it.Trim(); if ($t) { $out.Add($label + $t) } }
    }
    return ,$out
}
# "PAWN Alice: <new or changed parts>; no longer: <parts gone>", or nothing when only the order changed. A part whose
# words stay and whose numbers change ("consciousness 76%" -> "74%") counts as changed, not as gone.
function Change-Line([string]$name, [string]$old, [string]$new) {
    $o = Parts $old
    $n = Parts $new
    $added = @($n | Where-Object { -not $o.Contains($_) })
    $keys = @($added | ForEach-Object { $_ -replace '\d+(\.\d+)?', '#' })
    $gone = @($o | Where-Object { -not $n.Contains($_) -and ($keys -notcontains ($_ -replace '\d+(\.\d+)?', '#')) })
    $text = @()
    if ($added.Count) { $text += ($added -join ", ") }
    if ($gone.Count) { $text += ("no longer: " + ($gone -join ", ")) }
    if ($text.Count) { "PAWN ${name}: " + ($text -join "; ") }
}
# "120, 126 (16 tiles north of Bob) (outdoors)" -> the room part "(outdoors)" and the rest. The move line names the room
# only when it differs from the pawn's last line (user, 2026-10-19: "Feels spammy. especially "OUTDOORS". I dont think
# it needs to say every fucking call.").
function Room-Of([string]$where) { if ($where -match '\s*(\([^()]*\))\s*$') { return $Matches[1] } else { return "" } }
function Place-Of([string]$where) { return ($where -replace '\s*\([^()]*\)\s*$', '') }
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
    $pawns["$($p.id)"] = @{ text = "$($p.text)"; x = [double]$p.x; z = [double]$p.z; room = (Room-Of "$($p.where)") }
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
            $pawns[$id] = @{ text = "$($p.text)"; x = [double]$p.x; z = [double]$p.z; room = (Room-Of "$($p.where)") }
        } elseif ("$($p.text)" -ne $old.text) {
            Change-Line "$($p.name)" $old.text "$($p.text)"
            $old.text = "$($p.text)"
        } elseif ((Dist $p $old.x $old.z) -ge $Cells) {
            $room = Room-Of "$($p.where)"
            if ($room -ne $old.room) { "PAWN $($p.name) moved to $($p.where)" } else { "PAWN $($p.name) moved to $(Place-Of "$($p.where)")" }
            $old.x = [double]$p.x; $old.z = [double]$p.z; $old.room = $room
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
