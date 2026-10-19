# PreToolUse hook (Bash / PowerShell), the RimWorld play session only. User, 2026-10-19: "whenever the conditions are
# met, write a logic so that no model/specialist can interact with the game, and have the logic output "conditions are
# met for compaction. if you are an orchestrator, vote for compaction."" / "Every order except the compact vote itself".
# While a compaction is due (compact_common.ps1) or the orchestrator's compact vote is in: a call of send.ps1 or play.ps1,
# or of vote.ps1 without -Compact, is blocked (exit 2) with that text. Every evaluation is also written to
# play_sessions\compact_now.json, which vote.ps1 -Compact reads (it runs right after this hook, for its own call).
. (Join-Path $PSScriptRoot "compact_common.ps1")
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $in = $raw | ConvertFrom-Json
    if (-not (CC-IsPlaySession $in)) { exit 0 }
    $sid = [string]$in.session_id
    $ev = CC-Evaluate $in
    if (-not $ev.ok) { exit 0 }
    CC-WriteJson $CC_NowFile @{ session = $sid; due = $ev.due; path = $ev.path; day = $ev.day; cycle = $ev.cycle; ctx = $ev.ctx
                               utc = (Get-Date).ToUniversalTime().ToString("o") }
    $vote = CC-Vote $sid
    if (-not $ev.due -and $null -eq $vote) { exit 0 }
    $cmd = [string]$in.tool_input.command
    $order = $cmd -match '(?i)\b(send|play)\.ps1\b'
    $plainVote = ($cmd -match '(?i)\bvote\.ps1\b') -and ($cmd -notmatch '(?i)-Compact\b')
    if ($order -or $plainVote) {
        [Console]::Error.WriteLine($CC_Message)
        exit 2
    }
} catch {
    exit 0
}
exit 0
