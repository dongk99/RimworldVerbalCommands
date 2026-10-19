# PreCompact hook: lets an automatic compaction of the RimWorld play session run only when the orchestrator's day notes
# are there (both notes of the 2-day cycle that ended, or the context path; compact_common.ps1), and pauses the game first (user, 2026-10-19: "you pause the game before
# compaction actually happens"). No votes (user, 2026-10-19: "no fucking votes from anyone, not even orchestrator."). Any
# compaction of the session passes while the notes are there, a specialist's too ("you just compact based on day notes.").
# Nothing here unpauses the game ("It doesnt unpause
# unless an orchestrator does it.").
# Claude Code (code.claude.com/docs/en/hooks, PreCompact): "Exit with code 2 to block compaction"; a proactive
# auto-compact that is blocked is skipped and the conversation goes on, but one triggered to recover from a context-limit
# error makes the current request fail. A manual /compact (the user's) is never blocked here.
# The play session: RIMWORLD_PLAY=1 in its environment (play_here.ps1, the desktop shortcut "RimWorld Play"), or its id in
# play_sessions\active_session.txt. Any other session: allowed, untouched.
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "compact_common.ps1")
try {
    $raw = [Console]::In.ReadToEnd()
    $in = $null
    if (-not [string]::IsNullOrWhiteSpace($raw)) { $in = $raw | ConvertFrom-Json }
    if ($null -eq $in) { exit 0 }
    if (-not (CC-IsPlaySession $in)) { exit 0 }
    if ([string]$in.trigger -eq "manual") { exit 0 }

    $ev = CC-Evaluate $in
    if (-not $ev.ok) { [Console]::Error.WriteLine("Compaction held: the game state (inbox_state.json) can't be read."); exit 2 }
    if (-not ($ev.notesThere -or $ev.contextDue)) { [Console]::Error.WriteLine("Compaction held: the day notes are not there yet."); exit 2 }

    if ($ev.speed -ne "Paused") {
        & (Join-Path $PSScriptRoot "send.ps1") -Text "set game speed to paused." -Mode "raw apply" | Out-Null
    }
    exit 0
} catch {
    # A broken gate must not block compaction for good.
    exit 0
}
