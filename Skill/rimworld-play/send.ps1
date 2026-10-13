# Sends one order (or one reply) to the VerbalCommands agent inbox and prints the mod's result.
#   send.ps1 -Text "show status."                     router sentences, raw mode (no Haiku call)
#   send.ps1 -Text "run 3 hours." -Mode "raw apply"   apply at once
#   send.ps1 -Text "build a campfire near bob" -Mode ""   plain language through Haiku (costs a model call)
#   send.ps1 -Reply apply | cancel                    answers a plan that waits
#   send.ps1 -Text "show status." -Model claude-opus-5-5   first order of a session: your model id
# The file is written as .tmp and renamed to .txt (the inbox takes only complete .txt files); the result is
# outbox\<same name>.json. Touches nothing but the mod's own VerbalCommands folder: never Config, never saves.
# File name (mod author's rule): <model>-<harness>-<mm-hh-dd-mm-yyyy>-<session id, 8>_<number>.txt, e.g.
# claude-opus-5-5-claudecode-48-22-05-10-2026-90dc0f13_00013.txt. The time is minute-hour-day-month-year of the
# session's first order; later orders of the same session reuse that name start (found from its earlier files), so
# -Model is only needed on the first one. The mod's token counter opens that session's transcript from the id.
param(
    [string]$Text = "",
    [string]$Model = "",
    [string]$Harness = "",
    [string]$Session = "",
    [string]$Mode = "raw",
    [ValidateSet("", "apply", "cancel")][string]$Reply = "",
    [int]$TimeoutSec = 180
)
$ErrorActionPreference = "Stop"
$root = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands"
$inbox = Join-Path $root "inbox"
$outbox = Join-Path $root "outbox"
# Sends only while RimWorld is running (mod author: "get rid of that useless "every 5s" detect" / "doesnt write
# if rimworld isnt running"): nothing is written when the game is closed. A loaded colony with "Agent inbox" ticked is
# taken as given while an agent plays.
if (-not (Get-Process -Name "RimWorldWin64" -ErrorAction SilentlyContinue)) {
    Write-Output "NOT RUNNING: RimWorld is not running, so nothing was sent. Start it, load the colony and tick 'Agent inbox' in the VerbalCommands mod settings."
    exit 2
}

if ($Reply -ne "") {
    $body = $Reply
} else {
    if ([string]::IsNullOrWhiteSpace($Text)) { Write-Output "Nothing to send: give -Text or -Reply."; exit 1 }
    $body = if ([string]::IsNullOrWhiteSpace($Mode)) { $Text } else { "mode: $Mode`n$Text" }
}
if ([Text.Encoding]::UTF8.GetByteCount($body) -gt 16000) { Write-Output "Too long: an inbox file is at most 16 KB."; exit 1 }

New-Item -ItemType Directory -Force $inbox | Out-Null
# Who sends: Claude Code gives its shell CLAUDE_CODE_SESSION_ID; another harness passes -Harness and -Session.
if ($Session -eq "") { $Session = [string]$env:CLAUDE_CODE_SESSION_ID }
if ($Harness -eq "") { $Harness = $(if ($env:CLAUDE_CODE_SESSION_ID) { "claudecode" } else { "unknown" }) }
$sid = ($Session.ToLowerInvariant() -replace '[^0-9a-f]', '')
if ($sid.Length -ge 8) { $sid = $sid.Substring(0, 8) } else { $sid = "nosessio" }
function Clean([string]$s, [string]$empty) {
    $c = ($s.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
    if ($c -eq "") { return $empty } else { return $c }
}
# A number above every file sent before (old names 00012_cc, new names ..._00013), so names keep sorting.
$n = 0
$prefix = $null
foreach ($dir in @($inbox, (Join-Path $inbox "taken"), $outbox)) {
    if (Test-Path $dir) {
        Get-ChildItem $dir -File | Sort-Object LastWriteTime | ForEach-Object {
            if ($_.BaseName -match '^(\d+)_') { $v = [int]$Matches[1]; if ($v -gt $n) { $n = $v } }
            if ($_.BaseName -match '^(.+)_(\d{5})(_\d+)?$') {   # taken\ may add _<ticks> to a repeated name
                $v = [int]$Matches[2]; if ($v -gt $n) { $n = $v }
                if ($sid -ne "nosessio" -and $Matches[1].EndsWith("-" + $sid)) { $prefix = $Matches[1] }
            }
        }
    }
}
if ($null -eq $prefix) {
    $prefix = (Clean $Model "unknown-model") + "-" + (Clean $Harness "unknown") + "-" + (Get-Date -Format "mm-HH-dd-MM-yyyy") + "-" + $sid
}
$base = ("{0}_{1:D5}" -f $prefix, ($n + 1))
# Tip-filter detection (mod author: "write a detection into ps1 but dont also inject into agent itself, just
# have it write silently into transcripts (the mod log transcript, not in-game transcript)"). The caller's whole
# command is read from the call stack; when it drops TIP lines (`-notmatch '^TIP'`, `-notlike 'TIP*'`, ...) or the
# Write-Host tips below (`6>$null`, `*>$null`, -InformationAction Ignore), one "agent_tip_filter" record goes into
# the mod's router log of this game launch (logs\router_*.jsonl, made after RimWorld started). Prints nothing,
# fails silently. The mod appends a line at a time (RouterLog.cs AppendRaw), so this does the same, before the
# order is in the inbox.
try {
    $caller = (Get-PSCallStack)[1].Position.StartScriptPosition.GetFullScript()
    $hits = @([regex]::Matches($caller, "(?i)(-notmatch|-notlike|-NotMatch)\s*['`"][^'`"]*TIP[^'`"]*['`"]|[6*]>\s*\`$null|-InformationAction\s+(Ignore|SilentlyContinue)") | ForEach-Object { $_.Value })
    if ($hits.Count -gt 0) {
        $started = (Get-Process -Name "RimWorldWin64" | Sort-Object StartTime | Select-Object -First 1).StartTime
        $log = Get-ChildItem (Join-Path $root "logs") -Filter "router_*.jsonl" -File |
            Where-Object { $_.CreationTime -ge $started } | Sort-Object Name | Select-Object -Last 1
        if ($log) {
            $rec = [ordered]@{ utc = (Get-Date).ToUniversalTime().ToString("o"); kind = "agent_tip_filter"; order_id = "";
                turn = 0; file = "$base.txt"; session = $Session; matched = $hits;
                command = $(if ($caller.Length -gt 4000) { $caller.Substring(0, 4000) } else { $caller }) }
            $line = (New-Object PSObject -Property $rec | ConvertTo-Json -Compress) + "`n"
            for ($i = 0; $i -lt 5; $i++) {
                try { [IO.File]::AppendAllText($log.FullName, $line, (New-Object Text.UTF8Encoding $false)); break }
                catch { Start-Sleep -Milliseconds 50 }
            }
        }
    }
} catch { }
$tmp = Join-Path $inbox "$base.tmp"
$txt = Join-Path $inbox "$base.txt"
[IO.File]::WriteAllText($tmp, $body, (New-Object Text.UTF8Encoding $false))
Rename-Item $tmp $txt

$result = Join-Path $outbox "$base.json"
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while (-not (Test-Path $result)) {
    if ((Get-Date) -gt $deadline) {
        Write-Output "NO ANSWER after $TimeoutSec s for $base.txt. The file is still in the inbox or being worked."
        exit 3
    }
    Start-Sleep -Milliseconds 300
}
Start-Sleep -Milliseconds 100
$json = Get-Content $result -Raw
# The tips go to the console with Write-Host, outside the output stream: `$r = (& send.ps1 ...) | ConvertFrom-Json`
# and a `Where-Object { $_ -notmatch '^TIP' }` on answers/reasons do not reach them (an earlier agent session filtered every
# TIP line from its third order on; mod author: "edit that .ps1"). The JSON below still carries them.
try {
    foreach ($t in @((ConvertFrom-Json $json).tips)) { if ($t) { Write-Host "TIP: $t" } }
} catch { }
$json
