# clear.ps1 - deletes a stop file or a message file in agent_player\delegates. The play session's hooks allow no
# Remove-Item (rimworld_play_scripts.py: only the skill folder's scripts), so the restart step "delete
# delegates\stop\ALL" and the specialists' "read delegates\msg\<name>.md, delete it" go through this script
# (user, 2026-10-16, screenshot of the orchestrator stuck on stop\ALL).
#
#   powershell -File "<skill folder>\clear.ps1" -Stop ALL         delegates\stop\ALL
#   powershell -File "<skill folder>\clear.ps1" -Stop schedule    delegates\stop\schedule
#   powershell -File "<skill folder>\clear.ps1" -Msg schedule     delegates\msg\schedule.md
#
# Nothing else can be deleted with it. Prints one line per file: "deleted PATH" or "not there: PATH".

param(
    [string]$Stop = "",
    [string]$Msg = ""
)
$ErrorActionPreference = "Continue"
$delegates = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\delegates"

if (-not $Stop -and -not $Msg) { "Give -Stop NAME (or ALL) or -Msg NAME."; exit 1 }
$targets = @()
if ($Stop) {
    if ($Stop.Trim() -notmatch '^[A-Za-z0-9_\-]+$') { "-Stop: letters, digits, _ and - only."; exit 1 }
    $targets += (Join-Path $delegates ("stop\" + $Stop.Trim()))
}
if ($Msg) {
    if ($Msg.Trim() -notmatch '^[A-Za-z0-9_\-]+$') { "-Msg: letters, digits, _ and - only."; exit 1 }
    $targets += (Join-Path $delegates ("msg\" + $Msg.Trim() + ".md"))
}
foreach ($t in $targets) {
    if (Test-Path -LiteralPath $t -PathType Leaf) {
        Remove-Item -LiteralPath $t -Force -Confirm:$false
        if (Test-Path -LiteralPath $t) { "could not delete: $t" } else { "deleted $t" }
    } else {
        "not there: $t"
    }
}
exit 0
