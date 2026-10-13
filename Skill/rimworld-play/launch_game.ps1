# Launches RimWorld and auto-loads a colony save, then confirms the colony is up through the VerbalCommands inbox.
#   launch_game.ps1                              newest .rws in Saves\ (Autosave-N included), via Steam
#   launch_game.ps1 -Save "My colony"            that save (name without .rws)
#   launch_game.ps1 -Exe [-ExePath <path>]      start RimWorldWin64.exe directly (found through Steam's registry key, or given) instead of steam://rungameid/294100
#   launch_game.ps1 -NoProbe                     do not send "show status." after launch
#
# How the load works (verified in the decompiled game sources, RimWorld 1.6):
#   Verse\Root_Entry.cs:18-23   at the main menu the game calls SaveGameFilesUtility.GetAutostartSaveFile() once and,
#                                if it returns a file, GameDataSaveLoader.LoadGame(file).
#   Verse\SaveGameFilesUtility.cs:42-49   returns the save named "autostart" (case-insensitive), and ONLY if Prefs.DevMode.
#   Verse\GameDataSaveLoader.cs:48        AutostartSaveName = "autostart".
# There is no command-line argument that loads a named save (-quicktest makes a new test map, -savedatafolder moves the
# data folder). So this script: copies the chosen save to Saves\autostart.rws, sets <devMode>True</devMode> in
# Config\Prefs.xml when it is False (the game reads Prefs.xml at start; it must not be running at that moment), starts
# the game, waits for the colony by sending "show status." through send.ps1 (the mod answers only once a colony with
# "Agent inbox" is loaded), then deletes autostart.rws so the next plain start of the game is not hijacked.
# Dev mode stays on afterwards (the game rewrites Prefs.xml from memory on every option change and on exit, so an
# on-disk edit while it runs would be lost); turn it off in Options if unwanted.
param(
    [string]$Save = "",
    [switch]$Exe,
    [string]$ExePath = "",
    [switch]$NoProbe,
    [string]$Model = "claude-fable-5-1",
    [int]$StartTimeoutSec = 120,
    [int]$LoadTimeoutSec = 600
)
$ErrorActionPreference = "Stop"
$dataRoot = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios"
$savesDir = Join-Path $dataRoot "Saves"
$prefsXml = Join-Path $dataRoot "Config\Prefs.xml"
$autostart = Join-Path $savesDir "autostart.rws"
$exePath = $ExePath
if ($exePath -eq "") {
    # Steam install folder from the registry, then the default library.
    $steamRoot = $null
    try { $steamRoot = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath } catch { }
    if ($steamRoot) { $exePath = Join-Path $steamRoot "steamapps\common\RimWorld\RimWorldWin64.exe" }
}
$steamAppId = 294100

if (Get-Process -Name "RimWorldWin64" -ErrorAction SilentlyContinue) {
    Write-Output "ALREADY RUNNING: RimWorld is running. Close it first (a running game ignores autostart.rws and would overwrite Prefs.xml)."
    exit 2
}

# 1. Pick the save.
if ($Save -ne "") {
    $src = Join-Path $savesDir ($Save -replace '\.rws$', '')
    $src = "$src.rws"
    if (-not (Test-Path $src)) { Write-Output "NO SUCH SAVE: $src"; exit 1 }
} else {
    $cand = Get-ChildItem $savesDir -Filter *.rws -File | Where-Object { $_.BaseName -ne "autostart" } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $cand) { Write-Output "NO SAVES in $savesDir"; exit 1 }
    $src = $cand.FullName
}
Copy-Item -LiteralPath $src -Destination $autostart -Force
Write-Output "SAVE: $src -> autostart.rws"

# 2. Dev mode on (needed by GetAutostartSaveFile).
if (Test-Path $prefsXml) {
    $txt = Get-Content -LiteralPath $prefsXml -Raw
    if ($txt -match '<devMode>False</devMode>') {
        Set-Content -LiteralPath $prefsXml -Value ($txt -replace '<devMode>False</devMode>', '<devMode>True</devMode>') -Encoding utf8 -NoNewline
        Write-Output "PREFS: devMode False -> True in Config\Prefs.xml (autostart loads only in dev mode)"
    } elseif ($txt -notmatch '<devMode>True</devMode>') {
        Write-Output "PREFS: no <devMode> element found in Prefs.xml; autostart may not load"
    }
} else {
    Write-Output "PREFS: $prefsXml not found; autostart may not load"
}

# 3. Launch.
if ($Exe) {
    if ($exePath -eq "" -or -not (Test-Path $exePath)) { Write-Output "NO EXE: $exePath (give -ExePath <...\RimWorldWin64.exe>)"; exit 1 }
    Start-Process -FilePath $exePath -WorkingDirectory (Split-Path $exePath)
    Write-Output "LAUNCH: $exePath"
} else {
    Start-Process "steam://rungameid/$steamAppId"
    Write-Output "LAUNCH: steam://rungameid/$steamAppId"
}
$deadline = (Get-Date).AddSeconds($StartTimeoutSec)
while (-not (Get-Process -Name "RimWorldWin64" -ErrorAction SilentlyContinue)) {
    if ((Get-Date) -gt $deadline) { Write-Output "NOT STARTED: no RimWorldWin64 process after $StartTimeoutSec s"; exit 3 }
    Start-Sleep -Seconds 2
}
Write-Output "PROCESS: RimWorldWin64 up"

# 4. Wait for the colony: the mod answers the inbox only once a colony with "Agent inbox" is loaded.
if ($NoProbe) {
    Write-Output "DONE (no probe). Delete Saves\autostart.rws yourself after the colony has loaded."
    exit 0
}
$snd = Join-Path $PSScriptRoot "send.ps1"
$r = & $snd -Text "show status." -Model $Model -TimeoutSec $LoadTimeoutSec
Write-Output $r
if ($r -is [string] -and $r -match '^(NOT RUNNING|NO ANSWER|Too long|Nothing to send)') {
    Write-Output "LOAD NOT CONFIRMED: autostart.rws left in place."
    exit 4
}
Remove-Item -LiteralPath $autostart -Force -ErrorAction SilentlyContinue
Write-Output "LOADED: colony answered; autostart.rws removed."
