# SessionStart hook (matcher: compact). Prints the newest play-log handoff, only in the session that is playing RimWorld.
# The marker active_session.txt holds the session id of that session; any other session prints nothing.
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $sid = ($raw | ConvertFrom-Json).session_id
    if ([string]::IsNullOrWhiteSpace($sid)) { exit 0 }

    $dir = Join-Path $env:USERPROFILE "AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\play_sessions"
    $marker = Join-Path $dir "active_session.txt"
    # The play session: its id in active_session.txt, or RIMWORLD_PLAY=1 from play_here.ps1 (the "RimWorld Play" desktop
    # shortcut, 2026-10-15), so a session that has not written its id yet still gets the handoff.
    $id = $null
    if (Test-Path -LiteralPath $marker) { $id = (Get-Content -LiteralPath $marker -Encoding UTF8 -TotalCount 1) }
    $byId = $null -ne $id -and $id.Trim() -eq ([string]$sid).Trim()
    if (-not ($byId -or $env:RIMWORLD_PLAY -eq "1")) { exit 0 }
    # bills.md is shown again after the compaction (bills_hook.ps1, user 2026-10-17).
    Remove-Item -LiteralPath (Join-Path $dir "bills_shown.txt") -ErrorAction SilentlyContinue

    $file = Get-ChildItem -LiteralPath $dir -Filter "day_*.md" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

    $where = "none found"
    if ($file) { $where = $file.FullName }
    $head = "[rimworld-play resume] This session is playing RimWorld through the rimworld-play skill. The user allowed it (2026-10-04, `"Yes. But only for Rimworld related stuff.`") to go on playing by itself after a compaction, for RimWorld play only. Handoff: $where. Before any run: send ``show speed.`` and ``show status.`` and trust the game over this file. Pointers every handoff carries: src\RouterScript\notes\WHY.md, src\RouterScript\README.md, src\RouterScript\notes\, src\RouterScript.Cli\notes\, interpreter_versions\ (reasons in WHY.md count as unverified until their source is found)."

    # After a 2-day compaction (user, 2026-10-15: "after compact telling it to read required .md (session notes,
    # orchestrator.md, and other files you think it should read), launch subagents, BEFORE releasing pause."). The game
    # stays paused (vote.ps1 -Compact paused it, and compact_gate.ps1 only lets the compaction run paused).
    $proj = Split-Path $dir -Parent
    # The shipped docs (ORCHESTRATOR.md, COMMON.md, briefs) are in the mod; what the agents write is under $proj.
    . (Join-Path $PSScriptRoot "find_mod.ps1")
    $docs = if ($ModDir) { Join-Path $ModDir "Skill\delegates" } else { "<mod folder>\Skill\delegates" }
    $prev = Get-ChildItem -LiteralPath $dir -Filter "day_*.md" -File -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -Skip 1 -First 1
    # Only after a gated compaction (specialists stopped). A compaction forced by the context limit can come mid-game with
    # specialists still running; relaunching them then would start doubles.
    $restart = Join-Path $dir "compact_restart.json"   # compact_gate.ps1 turned the compact vote into it (2026-10-19)
    if (Test-Path -LiteralPath $restart) { Remove-Item -LiteralPath $restart -Force -ErrorAction SilentlyContinue; $head += "`n[2-day compaction restart] The game is paused on purpose. Before you unpause, in this order: " +
        "1. Read: <home>\.claude\skills\rimworld-play\SKILL.md; $docs\ORCHESTRATOR.md (section 0 roles, section 3 the round, section 4 your loop, section 6 spawning); " +
        "$docs\COMMON.md; the day note below" + $(if ($prev) { " and the one before it ($($prev.FullName))" } else { "" }) + "; every $proj\delegates\status\*.md; " +
        "and the router pointers above (WHY.md, README.md). " +
        "2. Send ``show speed.``, ``show status.``, ``show alerts.`` and ``show letters.``; trust the game over the notes. " +
        "3. Delete $proj\delegates\stop\ALL (powershell -File `"<home>\.claude\skills\rimworld-play\clear.ps1`" -Stop ALL; the hooks allow no Remove-Item), then relaunch the specialists as ORCHESTRATOR.md section 4 orders them (schedule, work_priority, equipment_config, storage_zones, bills, expediter, drafter_mover last), each with a current direction line (section 6). " +
        "4. Only then unpause (``set game speed to normal.`` or a ``run``)." }
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    if ($file) {
        $text = Get-Content -LiteralPath $file.FullName -Encoding UTF8 -Raw
        [Console]::Out.Write($head + "`n----`n" + $text)
    } else {
        [Console]::Out.Write($head + "`n")
    }
} catch {
    exit 0
}
exit 0
