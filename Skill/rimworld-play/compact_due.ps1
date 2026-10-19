# PostToolUse hook (Bash / PowerShell), the RimWorld play session only. It rides on every tool result of the
# orchestrator and of every specialist as additionalContext (code.claude.com/docs/en/hooks), with no time limit (user,
# 2026-10-18: "remove the "every x minutes" requirement"; "That warning now fires on every call output to
# specialist/orchestrator"). Rules in compact_common.ps1.
#   - The orchestrator's compact vote is in: a specialist is told to pause, write its status note (full path) and return
#     (user, 2026-10-19: "the hook says to specialists to pause all activity and write a note (like they normally do)
#     that the orchestrator reads aftrer compact"); the orchestrator to end its turn.
#   - A compaction is due: the user's text, verbatim, to every agent.
#   - The context reached warn: the orchestrator is told to append to the current day's note (full path).
# A specialist is known by the agent_id of its tool calls and the -Name it gives wait_round.ps1 / hostiles_watch.ps1 /
# vote.ps1; play_sessions\specialists_running.json keeps them until subagent_stop_hook.ps1 takes them off.
. (Join-Path $PSScriptRoot "compact_common.ps1")
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $in = $raw | ConvertFrom-Json
    if (-not (CC-IsPlaySession $in)) { exit 0 }
    $sid = [string]$in.session_id
    $aid = [string]$in.agent_id
    $cmd = [string]$in.tool_input.command

    $name = $null
    if ($aid) {
        $map = CC-Running $sid
        $m = [regex]::Match($cmd, '(?:wait_round|hostiles_watch|vote)\.ps1\S*\s+(?:-\w+\s+\S+\s+)*?-Name\s+["'']?([A-Za-z0-9_\-]+)')
        if ($m.Success -and $m.Groups[1].Value -ne "orchestrator" -and $map[$aid] -ne $m.Groups[1].Value) {
            $map[$aid] = $m.Groups[1].Value
            CC-SaveRunning $sid $map
        }
        $name = $map[$aid]
    }

    $text = $null
    $vote = CC-Vote $sid
    if ($null -ne $vote) {
        if ($aid) {
            $where = if ($name) { CC-StatusPath $name } else { Join-Path $CC_Status "<your name>.md" }
            $text = "The orchestrator voted for compaction. Pause all activity: write your status note to $where, then return to the orchestrator with your report."
        } else {
            $text = "Your compaction vote is in. End your turn."
        }
    } else {
        $ev = CC-Evaluate $in
        if (-not $ev.ok) { exit 0 }
        if ($ev.due) { $text = $CC_Message }
        elseif ($ev.warned -and -not $aid) {
            $lim = CC-Limits
            $text = "The context is at $($ev.ctx) tokens. A compaction becomes due at $($lim.valve) once $($ev.note) has grown. Append to it now."
        }
    }
    if ($null -eq $text) { exit 0 }
    $out = @{ hookSpecificOutput = @{ hookEventName = "PostToolUse"; additionalContext = $text } } | ConvertTo-Json -Depth 4 -Compress
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::Out.Write($out)
} catch {
    exit 0
}
exit 0
