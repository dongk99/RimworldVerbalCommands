# PostToolUse hook (Bash / PowerShell), the RimWorld play session only. User, 2026-10-21: "that valve needs to fucking work
# irregardless of day notes. same goes for warning." compact_limits.md: warn is the context "from which the orchestrator is
# told to append to the current day's note", but nothing told it. So once the context is at or past warn (no day note looked
# at), this tells the agent once; again only after the context dropped below warn or a compaction ran (CC-Evaluate /
# CC-Compacted clear warnShown).
# The play session: RIMWORLD_PLAY=1 or its id in play_sessions\active_session.txt. Any other session: untouched.
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "compact_common.ps1")
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $in = $raw | ConvertFrom-Json
    if (-not (CC-IsPlaySession $in)) { exit 0 }

    $ev = CC-Evaluate $in
    if (-not $ev.ok -or -not $ev.warned -or (CC-WarnShown)) { exit 0 }

    $msg = "Context is at {0} tokens, past {1}: append to today's note, {2}." -f $ev.ctx, $ev.warn, (Split-Path -Leaf $ev.note)
    @{ hookSpecificOutput = @{ hookEventName = "PostToolUse"; additionalContext = $msg } } | ConvertTo-Json -Compress
    CC-SetWarnShown
    exit 0
} catch {
    # A broken hook must not break the tool call.
    exit 0
}
