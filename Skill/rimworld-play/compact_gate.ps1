# PreCompact hook: lets the RimWorld play session's automatic compaction run only after the orchestrator's compact vote
# (vote.ps1 -Compact; rules in compact_common.ps1). Claude Code: "Exit with code 2 to block compaction"; a proactive
# auto-compact that is blocked is skipped and the conversation goes on (code.claude.com/docs/en/hooks, PreCompact). A
# compaction forced by the context limit can't be held back, and a manual /compact (the user's) is never blocked here.
# The play session: RIMWORLD_PLAY=1 in its environment (play_here.ps1, the desktop shortcut "RimWorld Play"), or its id in
# play_sessions\active_session.txt. Any other session: allowed, untouched.
# Allowed when this session's compact vote is in, the game is paused, and every specialist's status note named in the
# vote has grown since the vote, or 30 s have passed since the vote (user, 2026-10-19: "90 second after orchestrator
# vote no matter what. if the note has been updated for all the specialist, then dont wait 90s." / "no 90s, 30s").
# Then: lastCycle = the vote's cycle (cycle path), the context path's saved note size is cleared, and the vote becomes
# play_sessions\compact_restart.json for resume_hook.ps1.
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "compact_common.ps1")
try {
    $raw = [Console]::In.ReadToEnd()
    $in = $null
    if (-not [string]::IsNullOrWhiteSpace($raw)) { $in = $raw | ConvertFrom-Json }
    if ($null -eq $in) { exit 0 }
    if (-not (CC-IsPlaySession $in)) { exit 0 }
    if ([string]$in.trigger -eq "manual") { exit 0 }
    $sid = [string]$in.session_id

    $vote = CC-Vote $sid
    if ($null -eq $vote) { [Console]::Error.WriteLine("Compaction held: the orchestrator has not voted for compaction."); exit 2 }
    $st = CC-ReadGame
    if ($null -eq $st) { [Console]::Error.WriteLine("Compaction held: the game state (inbox_state.json) can't be read."); exit 2 }
    if ([string]$st.speed -ne "Paused") { [Console]::Error.WriteLine("Compaction held: the game is not paused."); exit 2 }

    $waiting = @()
    if ($vote.notes -ne $null) {
        foreach ($p in $vote.notes.PSObject.Properties) {
            if ((CC-Size (CC-StatusPath $p.Name)) -le [long]$p.Value) { $waiting += $p.Name }
        }
    }
    $since = ((Get-Date).ToUniversalTime() - [datetime]::Parse([string]$vote.utc).ToUniversalTime()).TotalSeconds
    if ($waiting.Count -gt 0 -and $since -lt $CC_WaitSec) {
        [Console]::Error.WriteLine("Compaction held: waiting for the status notes of " + ($waiting -join ", ") + " (at most $CC_WaitSec s after the vote).")
        exit 2
    }

    $cs = CC-ReadJson $CC_CycleFile
    $state = @{}
    if ($cs -ne $null) { foreach ($p in $cs.PSObject.Properties) { $state[$p.Name] = $p.Value } }
    if ([string]$vote.path -eq "cycle") { $state.lastCycle = [int]$vote.cycle; $state.day = [int]$vote.day }
    $state.noteFile = $null; $state.noteSize = $null
    $state.utc = (Get-Date).ToUniversalTime().ToString("o")
    CC-WriteJson $CC_CycleFile $state
    Move-Item -LiteralPath $CC_VoteFile -Destination $CC_RestartFile -Force
    exit 0
} catch {
    # A broken gate must not block compaction for good.
    exit 0
}
