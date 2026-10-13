param(
    [string[]]$Do = @(),      # orders applied at once (one order each; only for plans already seen)
    [string[]]$Plan = @(),    # orders previewed; the last plan stays waiting for -Reply
    [string]$Reply = "",      # apply or cancel, for the plan that waits
    [int]$Run = 0,            # game hours to run; waits until the game pauses again
    [string]$Ask = "",        # questions, asked last
    [string]$Model = ""       # your model id, for the inbox file names (needed on the session's first order only)
)
# One call for a whole step of play: reply, plans, orders, a run that is waited for, then questions.
#   play.ps1 -Do "restrict Stumpy to area base." -Run 4 -Ask "show events. show status."
#   play.ps1 -Plan "hunt snowhare."      then      play.ps1 -Reply apply
$send = Join-Path $PSScriptRoot "send.ps1"
$state = "$env:USERPROFILE\AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\inbox_state.json"

function Send-Order([string[]]$sendArgs) {
    if ($Model -ne "") { $sendArgs = $sendArgs + @("-Model", $Model) }
    powershell -File $send @sendArgs | Out-String | ConvertFrom-Json
}
function Show-Actions($r) {
    $r.actions | ForEach-Object { "  " + $_.result + " | " + $_.description + " | " + $_.reason }
    $r.reasons
}
# Tips the mod adds to a result (TipInjector.cs); printed after each step's own lines.
function Show-Tips($r) {
    $r.tips | ForEach-Object { "TIP: " + $_ }
}

if ($Reply -ne "") {
    $r = Send-Order @("-Reply", $Reply)
    "REPLY $Reply -> " + $r.result
    Show-Actions $r
    Show-Tips $r
}
foreach ($p in $Plan) {
    $r = Send-Order @("-Text", $p)
    "PLAN [$p] -> " + $r.result + $(if ($r.risky) { " (RISKY)" } else { "" })
    $r.plan_lines
    $r.notes
    $r.reasons
    Show-Tips $r
}
foreach ($d in $Do) {
    $r = Send-Order @("-Text", $d, "-Mode", "raw apply")
    "DO [$d] -> " + $r.result
    Show-Actions $r
    Show-Tips $r
}
if ($Run -gt 0) {
    $tick0 = (Get-Content $state -Raw | ConvertFrom-Json).game.tick
    $r = Send-Order @("-Text", "run $Run hours.", "-Mode", "raw apply")
    "RUN $Run -> " + $r.result
    $r.reasons
    Show-Tips $r
    # inbox_state.json is written when the game starts running and when it pauses again (not every 5 s any more):
    # the run has started once it shows the game running, or a later tick (a run short enough to end between looks).
    $moved = $false
    for ($i = 0; $i -lt 280; $i++) {
        Start-Sleep -Seconds 2
        $j = Get-Content $state -Raw | ConvertFrom-Json
        if (-not $j.paused -or $j.game.tick -ne $tick0) { $moved = $true }
        if ($moved -and $j.paused) { break }
        if (-not $moved -and $i -ge 7) { break }
    }
    if (-not $moved) { "STALLED: the game did not move in 16 seconds (a window in the game holds it paused)." }
    "now: day index " + $j.game.day + " hour " + $j.game.hour + " tick " + $j.game.tick
}
if ($Ask -ne "") {
    $r = Send-Order @("-Text", $Ask)
    "ASK -> " + $r.result
    $r.answers
    $r.reasons
    Show-Tips $r
}
