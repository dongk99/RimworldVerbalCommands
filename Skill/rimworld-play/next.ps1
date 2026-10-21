# next.ps1 - the game's new lines (watch.ps1 and pawns_watch.ps1 with -Feed) as this call's own result.
#
# User, 2026-10-19: "do find a way to get rid of system notification - not user input." A Monitor or background-task
# notification comes wrapped in about 170 tokens of Claude Code's "[SYSTEM NOTIFICATION - NOT USER INPUT] ..." text (one
# play session: 268 of them, about 57k tokens to day 0 hour 13); a tool result carries none. So the two watchers run in the
# background with -Feed and write their lines to <SaveData>\VerbalCommands\feed\<session>_events.log / _pawns.log, and
# the agent calls this script in the foreground whenever it waits for the game:
#   powershell -File "<skill folder>\next.ps1"        (PowerShell tool, timeout 600000)
# It prints every complete line written since its last call (events first, then pawns) and returns. With nothing new it
# waits, on the files' change notification, until a line comes. Its place in each file is saved only after the lines are
# printed, so a call that is cut off loses nothing.
#
# -MaxWaitMinutesUnderToolTimeout (9 minutes, proposed by the agent with this item; user, 2026-10-19: "wortk on all 4, except 3, because you just
# said 3 isnt a problem. and 4 fixes itself, so, 1 and 2."): the PowerShell tool moves a call
# that runs past its timeout (at most 10 minutes) into the background, where the lines would come back as a notification
# with the wrapper. So with nothing new for 9 minutes it prints "NOTHING NEW ..." and returns; call it again.
# Lines: whatever watch.ps1 and pawns_watch.ps1 print (see their headers), and
#   NO FEED: ...          neither watcher runs with -Feed in this session
#   Either somehow ...    nothing in -MaxWaitMinutesUnderToolTimeout minutes (3 since 2026-10-20; user: "set it to 3
#                         minutes.")
#   GAME IS PAUSED, ...   nothing new and inbox_state.json says paused (a paused game writes no new lines)
param([double]$MaxWaitMinutesUnderToolTimeout = 3)
$root = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands"
$dir = Join-Path $root "feed"
$state = Join-Path $root "inbox_state.json"
$sid = ([string]$env:CLAUDE_CODE_SESSION_ID).ToLowerInvariant() -replace '[^0-9a-f]', ''
$sid = $(if ($sid.Length -ge 8) { $sid.Substring(0, 8) } else { "nosessio" })
$names = @("${sid}_events.log", "${sid}_pawns.log")
$cursorFile = Join-Path $dir "${sid}.cursor"

if (-not (Test-Path (Join-Path $dir $names[0])) -and -not (Test-Path (Join-Path $dir $names[1]))) {
    "NO FEED: start watch.ps1 -Feed and pawns_watch.ps1 -Feed in the background first (PowerShell tool, run_in_background: true)."
    exit 1
}

$cursor = @{}
try {
    $c = [IO.File]::ReadAllText($cursorFile) | ConvertFrom-Json
    foreach ($p in $c.PSObject.Properties) { $cursor[$p.Name] = [long]$p.Value }
} catch { }

$enc = New-Object Text.UTF8Encoding $false
# The complete lines after the saved place in one file; $cursor gets the new place (saved by the caller).
function Take([string]$name) {
    $path = Join-Path $dir $name
    if (-not (Test-Path $path)) { return @() }
    $at = 0L
    if ($cursor.ContainsKey($name)) { $at = $cursor[$name] }
    $fs = $null
    try {
        $fs = New-Object IO.FileStream($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        if ($fs.Length -lt $at) { $at = 0L }
        $len = [int]($fs.Length - $at)
        if ($len -le 0) { return @() }
        $buf = New-Object byte[] $len
        [void]$fs.Seek($at, [IO.SeekOrigin]::Begin)
        $got = 0
        while ($got -lt $len) { $n = $fs.Read($buf, $got, $len - $got); if ($n -le 0) { break }; $got += $n }
    } catch { return @() } finally { if ($fs) { $fs.Dispose() } }
    if ($got -le 0) { return @() }
    $last = [Array]::LastIndexOf($buf, [byte]10, $got - 1)
    if ($last -lt 0) { return @() }
    $cursor[$name] = $at + $last + 1
    return @(($enc.GetString($buf, 0, $last + 1) -split "`r?`n") | Where-Object { $_ -ne "" })
}
function Save {
    $o = New-Object PSObject
    foreach ($k in $cursor.Keys) { $o | Add-Member -NotePropertyName $k -NotePropertyValue $cursor[$k] }
    [IO.File]::WriteAllText($cursorFile, ($o | ConvertTo-Json -Compress), $enc)
}

# The watcher is set up before the first look, so a line written between the look and the wait still wakes the wait.
$fsw = New-Object IO.FileSystemWatcher $dir, "${sid}_*.log"
$fsw.NotifyFilter = [IO.NotifyFilters]::LastWrite -bor [IO.NotifyFilters]::Size -bor [IO.NotifyFilters]::FileName
$evId = "next_feed_" + [guid]::NewGuid().ToString("N")
Register-ObjectEvent -InputObject $fsw -EventName Changed -SourceIdentifier $evId | Out-Null
$fsw.EnableRaisingEvents = $true
$deadline = (Get-Date).AddMinutes($MaxWaitMinutesUnderToolTimeout)
try {
    while ($true) {
        $lines = @()
        foreach ($n in $names) { $lines += @(Take $n) }
        if ($lines.Count -gt 0) {
            $lines
            Save
            break
        }
        $paused = $false
        try { $paused = [bool](([IO.File]::ReadAllText($state) | ConvertFrom-Json).paused) } catch { }
        if ($paused) { 'GAME IS PAUSED, SAY "set game speed to normal." TO UNPAUSE TO GET UPDATES'; break }
        $left = ($deadline - (Get-Date)).TotalSeconds
        if ($left -le 0) { "Either somehow nothing happened in 3 minutes in rimworld, or you forgot to unpause for 3 minutes."; break }
        Wait-Event -SourceIdentifier $evId -Timeout ([int][math]::Ceiling($left)) | Out-Null
        Remove-Event -SourceIdentifier $evId -ErrorAction SilentlyContinue
    }
} finally {
    $fsw.EnableRaisingEvents = $false
    Unregister-Event -SourceIdentifier $evId -ErrorAction SilentlyContinue
    $fsw.Dispose()
}
