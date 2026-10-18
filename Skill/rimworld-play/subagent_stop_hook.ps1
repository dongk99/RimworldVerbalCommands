# SubagentStop hook (2026-10-17): a specialist subagent's call ended (its report, the 8-round limit, a proposal, STOP,
# NO HOSTILES, HOSTILES GONE, ...), so its heartbeat <SaveData>\VerbalCommands\agents\<name>.txt is deleted and the mod
# drops it from the open hourly check (AgentHourlyCheck.cs). A heartbeat left behind kept the ended specialist on every
# check opened in the next 30 minutes, and the game stayed paused on a vote that never came (equipment_config on check
# 311, storage_zones from 404, hostile_watch on 466-473). A resumed specialist writes it again on its next wait.
# The name is the last -Name the subagent gave wait_round.ps1, hostiles_watch.ps1 or vote.ps1 in its own tool calls
# (agent_transcript_path). A subagent with no such call is not a specialist: nothing happens. Prints nothing, never
# blocks the stop.
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $in = $raw | ConvertFrom-Json
    $path = [string]$in.agent_transcript_path
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { exit 0 }

    $rx = [regex]'(?:wait_round|hostiles_watch|vote)\.ps1\S*\s+(?:-\w+\s+\S+\s+)*?-Name\s+["'']?([A-Za-z0-9_\-]+)'
    $name = $null
    foreach ($line in [IO.File]::ReadLines($path)) {
        if (-not $line.Contains('"tool_use"') -or -not $line.Contains('-Name')) { continue }
        try { $o = $line | ConvertFrom-Json } catch { continue }
        if ($o.type -ne 'assistant') { continue }
        foreach ($b in @($o.message.content)) {
            if ($b.type -ne 'tool_use' -or $b.input -eq $null -or -not $b.input.command) { continue }
            foreach ($m in $rx.Matches([string]$b.input.command)) { if ($m.Groups[1].Value -ne 'orchestrator') { $name = $m.Groups[1].Value } }
        }
    }
    if (-not $name) { exit 0 }

    $beat = Join-Path $env:USERPROFILE ("AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\agents\" + $name + ".txt")
    if (Test-Path -LiteralPath $beat) { Remove-Item -LiteralPath $beat -Force -Confirm:$false }
} catch {
    exit 0
}
exit 0
