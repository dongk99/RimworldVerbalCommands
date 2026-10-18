# clear.ps1 - deletes a stop file or a message file in agent_player\delegates, or a specialist's heartbeat. The play session's hooks allow no
# Remove-Item (rimworld_play_scripts.py: only the skill folder's scripts), so the restart step "delete
# delegates\stop\ALL" and the specialists' "read delegates\msg\<name>.md, delete it" go through this script
# (user, 2026-10-16, screenshot of the orchestrator stuck on stop\ALL).
#
#   powershell -File "<skill folder>\clear.ps1" -Stop ALL         delegates\stop\ALL
#   powershell -File "<skill folder>\clear.ps1" -Stop schedule    delegates\stop\schedule
#   powershell -File "<skill folder>\clear.ps1" -Msg schedule     delegates\msg\schedule.md
#   powershell -File "<skill folder>\clear.ps1" -Beat schedule    <SaveData>\VerbalCommands\agents\schedule.txt
#
# -Beat (2026-10-17): a specialist's heartbeat, which keeps it on the hourly check's vote (AgentHourlyCheck.cs). For a
# specialist that ended with no script left to delete it (TaskStop, stopped by the user): the mod drops it from the open
# check at once.
#
# Nothing else can be deleted with it. Prints one line per file: "deleted PATH" or "not there: PATH".

param(
    [string]$Stop = "",
    [string]$Msg = "",
    [string]$Beat = ""
)
$ErrorActionPreference = "Continue"
$delegates = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\delegates"
$agents = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\agents"

if (-not $Stop -and -not $Msg -and -not $Beat) { "Give -Stop NAME (or ALL), -Msg NAME or -Beat NAME."; exit 1 }
$targets = @()
if ($Stop) {
    if ($Stop.Trim() -notmatch '^[A-Za-z0-9_\-]+$') { "-Stop: letters, digits, _ and - only."; exit 1 }
    $targets += (Join-Path $delegates ("stop\" + $Stop.Trim()))
}
if ($Msg) {
    if ($Msg.Trim() -notmatch '^[A-Za-z0-9_\-]+$') { "-Msg: letters, digits, _ and - only."; exit 1 }
    $targets += (Join-Path $delegates ("msg\" + $Msg.Trim() + ".md"))
}
if ($Beat) {
    if ($Beat.Trim() -notmatch '^[A-Za-z0-9_\-]+$') { "-Beat: letters, digits, _ and - only."; exit 1 }
    $targets += (Join-Path $agents ($Beat.Trim() + ".txt"))
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
