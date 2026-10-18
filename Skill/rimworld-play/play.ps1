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
# Every step prints send.ps1's whole output (tips, reminders, the outbox JSON), nothing picked out (user, 2026-10-16:
# "fix existing powershell so everything prints"; it used to print a few fields and dropped the reminders, and its
# ConvertFrom-Json failed whenever send.ps1's Write-Host tip or reminder lines came before the JSON).
$send = Join-Path $PSScriptRoot "send.ps1"
$state = "$env:USERPROFILE\AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\inbox_state.json"

function Send-Order([string[]]$sendArgs) {
    if ($Model -ne "") { $sendArgs = $sendArgs + @("-Model", $Model) }
    powershell -File $send @sendArgs
}

if ($Reply -ne "") {
    "REPLY $Reply ->"
    Send-Order @("-Reply", $Reply)
}
foreach ($p in $Plan) {
    "PLAN [$p] ->"
    Send-Order @("-Text", $p)
}
foreach ($d in $Do) {
    "DO [$d] ->"
    Send-Order @("-Text", $d, "-Mode", "raw apply")
}
if ($Run -gt 0) {
    $tick0 = (Get-Content $state -Raw | ConvertFrom-Json).game.tick
    "RUN $Run ->"
    Send-Order @("-Text", "run $Run hours.", "-Mode", "raw apply")
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
    "ASK ->"
    Send-Order @("-Text", $Ask)
}
