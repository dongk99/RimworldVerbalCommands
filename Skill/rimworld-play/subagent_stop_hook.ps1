# SubagentStop hook: a subagent's call ended (its report, the 8-round limit, a proposal, STOP, NO HOSTILES, HOSTILES
# GONE, ...), so it is taken off play_sessions\specialists_running.json (compact_due.ps1 puts a specialist there from the
# -Name of its tool calls). vote.ps1 -Compact waits for the status notes of the specialists on that list.
# (2026-10-19) It used to delete the specialist's hourly-check heartbeat; only the orchestrator votes now (user: "the
# 1-hour reminder does not need specialist voting"), and the heartbeats are gone. Prints nothing, never blocks the stop.
. (Join-Path $PSScriptRoot "compact_common.ps1")
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $in = $raw | ConvertFrom-Json
    $sid = [string]$in.session_id
    $aid = [string]$in.agent_id
    if (-not $aid) { exit 0 }
    $map = CC-Running $sid
    if ($map.ContainsKey($aid)) {
        $map.Remove($aid)
        CC-SaveRunning $sid $map
    }
} catch {
    exit 0
}
exit 0
