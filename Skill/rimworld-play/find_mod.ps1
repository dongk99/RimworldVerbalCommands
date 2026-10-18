# find_mod.ps1 - dot-sourced by the other scripts:  . (Join-Path $PSScriptRoot "find_mod.ps1")
# Sets $ModDir (the VerbalCommands mod folder, the one whose About\About.xml has packageId kopaz.verbalcommands) and
# $RimWorldDir (the RimWorld install), or $null when not found. Where it looks:
#   1. two folders up from this script, when the scripts sit in <mod folder>\Skill\rimworld-play;
#   2. every Steam library in <Steam>\steamapps\libraryfolders.vdf (Steam's folder from HKCU\Software\Valve\Steam):
#      steamapps\common\RimWorld\Mods\* and the Workshop copy steamapps\workshop\content\294100\*.
# The scripts' own files (delegates\, play_sessions\) live in $ModDir\Skill.

function Test-VcMod([string]$dir) {
    $about = Join-Path $dir "About\About.xml"
    if (-not (Test-Path -LiteralPath $about)) { return $false }
    return ([IO.File]::ReadAllText($about) -match '<packageId>\s*kopaz\.verbalcommands\s*</packageId>')
}

function Get-SteamLibraries {
    $libs = @()
    $steam = $null
    try { $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath } catch { }
    if (-not $steam) { return $libs }
    $steam = $steam -replace '/', '\'
    $libs += $steam
    $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
    if (Test-Path -LiteralPath $vdf) {
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"')) {
            $p = $m.Groups[1].Value -replace '\\\\', '\'
            if (-not ($libs -contains $p)) { $libs += $p }
        }
    }
    return $libs
}

$ModDir = $null
$RimWorldDir = $null
$up = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (Test-VcMod $up) {
    $ModDir = $up
    $rw = Split-Path (Split-Path $up -Parent) -Parent
    if (Test-Path -LiteralPath (Join-Path $rw "RimWorldWin64.exe")) { $RimWorldDir = $rw }
}
if (-not $ModDir -or -not $RimWorldDir) {
    foreach ($lib in (Get-SteamLibraries)) {
        $rw = Join-Path $lib "steamapps\common\RimWorld"
        if (-not $RimWorldDir -and (Test-Path -LiteralPath (Join-Path $rw "RimWorldWin64.exe"))) { $RimWorldDir = $rw }
        if (-not $ModDir) {
            # The usual folder name first, then every mod folder and the Workshop copies.
            $cands = @(Join-Path $rw "Mods\VerbalCommands")
            $cands += @(Get-ChildItem -LiteralPath (Join-Path $rw "Mods") -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
            $cands += @(Get-ChildItem -LiteralPath (Join-Path $lib "steamapps\workshop\content\294100") -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
            foreach ($c in $cands) { if (Test-VcMod $c) { $ModDir = $c; break } }
        }
        if ($ModDir -and $RimWorldDir) { break }
    }
}
$ModDirError = "NO MOD FOLDER: the VerbalCommands mod (packageId kopaz.verbalcommands) was not found two folders above $PSScriptRoot or in any Steam library."
