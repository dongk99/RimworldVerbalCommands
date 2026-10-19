# wait_for.ps1 - one background event for one condition the watcher (watch.ps1) does not report.
#
# Rule (user, 2026-10-15): whenever the agent says it will act "once X" / "when X" / "after X", it arms this script for
# X in the same turn, with the PowerShell tool and run_in_background: true. The script exits (= one notification)
# the moment X holds, or on NOT RUNNING / TIMEOUT. Never say "once X" without arming one.
#
# Modes (pick one):
#   -Tick N                          until the game tick reaches N (day turns: day k starts at 60000*(k-1) - 15000 for
#                                    a game started at 6h). Reads inbox_state.json only; nothing is sent to the game.
#   -Question "S." -Match "REGEX"    asks the question S through send.ps1 (raw, a question never pauses the game) every
#                                    -EverySec real seconds while the game runs, until one answer line matches REGEX.
#                                    -NoMatch inverts it: until NO line matches (e.g. a blueprint gone).
#   -Near NAME -X x -Z z -Within d   until the line of NAME in -Question (default "show interactable pawns.") reads
#                                    "at X, Z" within d tiles of x, z (e.g. a trader close to the base).
# Examples:
#   powershell -File "<skill>\wait_for.ps1" -Tick 165000
#   powershell -File "<skill>\wait_for.ps1" -Near Mlie -X 123 -Z 128 -Within 30
#   powershell -File "<skill>\wait_for.ps1" -Question "show research." -Match "hydroponics: (finished|done)|700 of 700"
#   powershell -File "<skill>\wait_for.ps1" -Question "show blueprints." -Match "wall \(steel\)" -NoMatch
# Output, one line then exit:  MET <what> / NOT RUNNING ... / TIMEOUT after N min (<last answer line>), followed by the
# tip / reminder lines the questions brought back while waiting, if any.

param(
    [long]$Tick = -1,
    [string]$Question = "",
    [string]$Match = "",
    [switch]$NoMatch,
    [string]$Near = "",
    [int]$X = 0, [int]$Z = 0, [double]$Within = 0,
    [int]$EverySec = 30,
    [int]$TimeoutMin = 180
)
$state = "$env:USERPROFILE\AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\inbox_state.json"
$send = Join-Path $PSScriptRoot "send.ps1"
$deadline = (Get-Date).AddMinutes($TimeoutMin)

function Read-State {
    try { $raw = Get-Content $state -Raw -ErrorAction Stop; if ($raw) { return ($raw | ConvertFrom-Json) } } catch {}
    return $null
}
function Game-Running { return [bool](Get-Process -Name RimWorldWin64 -ErrorAction SilentlyContinue) }
# Everything else the questions brought back (the results' tips, reminders and PICTURE notes) is kept and printed
# after the closing line, each once (user, 2026-10-16: "fix existing powershell so everything prints"); it used to be
# dropped with the rest of each answer. Taken from the JSON fields since send.ps1 stopped printing them above it
# (user, 2026-10-19: "no duplicates.").
$extra = New-Object System.Collections.Generic.List[string]
function Done([string]$line, [int]$code) {
    $line
    if ($extra.Count -gt 0) {
        "-- also in the answers while waiting:"
        $extra
    }
    exit $code
}
function Ask([string]$text) {
    $out = (powershell -NoProfile -File $send -Text $text) -join "`n"
    $i = $out.IndexOf("{")
    $head = if ($i -lt 0) { $out } else { $out.Substring(0, $i) }
    foreach ($l in ($head -split "`n")) { $t = $l.TrimEnd(); if ($t -ne "" -and -not $extra.Contains($t)) { $extra.Add($t) } }
    if ($i -lt 0) { return @() }
    try { $r = $out.Substring($i) | ConvertFrom-Json } catch { return @() }
    $more = @(@($r.tips) | Where-Object { $_ } | ForEach-Object { "TIP: $_" }) + @(@($r.reminders) | Where-Object { $_ }) +
        @(@($r.notes) | Where-Object { "$_" -like 'PICTURE:*' })
    foreach ($t in $more) { if (-not $extra.Contains("$t")) { $extra.Add("$t") } }
    if ($r.result -ne "answer") { return @() }
    return @($r.answers)
}

if ($Near -ne "" -and $Question -eq "") { $Question = "show interactable pawns." }
if ($Tick -lt 0 -and $Question -eq "") { "USAGE: give -Tick N, -Question with -Match, or -Near NAME -X -Z -Within"; exit 1 }

$lastTick = -1
$last = ""
while ((Get-Date) -lt $deadline) {
    if (-not (Game-Running)) { Done "NOT RUNNING: RimWorld process not found" 2 }
    $j = Read-State
    $now = if ($j) { [long]$j.game.tick } else { -1 }

    if ($Tick -ge 0) {
        # inbox_state.json is rewritten only on events, so its tick goes stale: ask the game (show speed. reads
        # "... tick N."), and only when the file is not already past the target. Fixed 2026-10-15 (day note 6 h late).
        if ($now -lt $Tick) {
            $sp = Ask "show speed."
            $tl = $sp | Where-Object { $_ -match "tick (\d+)" } | Select-Object -First 1
            if ($tl -and $tl -match "tick (\d+)") { $now = [long]$Matches[1] }
        }
        if ($now -ge $Tick) { Done "MET tick $now >= $Tick" 0 }
        Start-Sleep -Seconds ([math]::Min($EverySec, 10))
        continue
    }

    # Ask only when game time moved since the last ask (a paused game gives the same answer).
    if ($now -ne $lastTick) {
        $lastTick = $now
        $lines = Ask $Question
        if ($lines.Count -gt 0) {
            if ($Near -ne "") {
                $line = $lines | Where-Object { $_ -match [regex]::Escape($Near) -and $_ -match "at (\d+), (\d+)" } | Select-Object -First 1
                if ($line -and $line -match "at (\d+), (\d+)") {
                    $d = [math]::Sqrt([math]::Pow([int]$Matches[1] - $X, 2) + [math]::Pow([int]$Matches[2] - $Z, 2))
                    $last = $line
                    if ($d -le $Within) { Done "MET $Near within $([math]::Round($d,1)) tiles of $X, $Z : $line" 0 }
                } else {
                    $last = "$Near not in the answer"
                }
            } else {
                $hit = $lines | Where-Object { $_ -match $Match } | Select-Object -First 1
                if ($NoMatch) {
                    if (-not $hit) { Done "MET no line matches '$Match' in '$Question'" 0 }
                    $last = $hit
                } elseif ($hit) { Done "MET '$Match' in '$Question': $hit" 0 }
                else { $last = $lines[0] }
            }
        }
    }
    Start-Sleep -Seconds $EverySec
}
Done "TIMEOUT after $TimeoutMin min (last: $last)" 3
