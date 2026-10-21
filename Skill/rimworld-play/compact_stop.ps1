# Stop hook, the RimWorld play session only. User, 2026-10-20: "sounds like the easiest fix is that you just devise a way so
# that a /compact gets injected if theres a 2 day note, regardless of it being thresshhold for not."
# Why: on 2026-10-19 12:36 (session 4d09ceab) compact_block.ps1 refused the orders, the agent ended its turn "for the
# compaction to run", and nothing compacted until the user typed /compact: no hook can start a compaction, auto-compact is
# only checked when a request goes out, and idle compaction waits about 54 minutes (code.claude.com/docs/en/settings-reference,
# idleCompaction). So when a turn ends and the 2-day note rule is met (CC-Evaluate path "cycle"; the context size is not
# looked at), this pauses the game (a manual /compact passes compact_gate.ps1 without its pause; user, 2026-10-19: "you
# pause the game before compaction actually happens") and starts compact_inject.ps1, which types /compact + Enter into
# this session's console. After the compaction resume_hook.ps1 (CC-Compacted) sets lastCycle, so the rule is no longer met.
# User, 2026-10-21: "that valve needs to fucking work irregardless of day notes." So the context path (CC-Evaluate path
# "context": context at or past valve, no day note looked at) injects /compact the same way.
# The play session: RIMWORLD_PLAY=1 or its id in play_sessions\active_session.txt. Any other session: untouched.
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "compact_common.ps1")
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $in = $raw | ConvertFrom-Json
    if (-not (CC-IsPlaySession $in)) { exit 0 }

    $ev = CC-Evaluate $in
    if (-not $ev.ok -or -not $ev.due) { exit 0 }

    if ($ev.speed -ne "Paused") {
        & (Join-Path $PSScriptRoot "send.ps1") -Text "set game speed to paused." -Mode "raw apply" | Out-Null
    }

    # The claude.exe this hook runs under (the hook may sit below a shell).
    $claudePid = 0
    $p = $PID
    for ($i = 0; $i -lt 10 -and $p; $i++) {
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$p"
        if ($null -eq $proc) { break }
        if ($proc.Name -ieq "claude.exe") { $claudePid = [int]$p; break }
        $p = $proc.ParentProcessId
    }
    if (-not $claudePid) { exit 0 }

    # resume_hook.ps1 types the read line only after a compaction this hook started.
    [IO.File]::WriteAllText((Join-Path $CC_Log "compact_injected.txt"), [string]$in.session_id)
    Start-Process powershell -WindowStyle Hidden -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
        ('"' + (Join-Path $PSScriptRoot "compact_inject.ps1") + '"'), "-ClaudePid", $claudePid)
    exit 0
} catch {
    # A broken hook must not stop the turn from ending.
    exit 0
}
