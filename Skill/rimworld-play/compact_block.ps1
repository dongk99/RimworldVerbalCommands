# PreToolUse hook (Bash / PowerShell), the RimWorld play session only. User, 2026-10-19: "whenever the conditions are
# met, write a logic so that no model/specialist can interact with the game" / "From due until done". From the moment a
# compaction is due (compact_common.ps1: the orchestrator's day notes) until the play session has compacted, a call of
# send.ps1, play.ps1 or vote.ps1 is blocked (exit 2) with $CC_Message. No votes since 2026-10-19 ("no fucking votes
# from anyone, not even orchestrator."), so nothing is let through.
. (Join-Path $PSScriptRoot "compact_common.ps1")
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $in = $raw | ConvertFrom-Json
    if (-not (CC-IsPlaySession $in)) { exit 0 }
    $cmd = [string]$in.tool_input.command
    if ($cmd -notmatch '(?i)\b(send|play|vote)\.ps1\b') { exit 0 }
    $ev = CC-Evaluate $in
    if (-not $ev.ok -or -not $ev.due) { exit 0 }
    [Console]::Error.WriteLine($CC_Message)
    exit 2
} catch {
    exit 0
}
exit 0
