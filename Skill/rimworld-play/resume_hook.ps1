# SessionStart hook (matcher: compact). Prints the newest play-log handoff, only in the session that is playing RimWorld.
# The marker active_session.txt holds the session id of that session; any other session prints nothing.
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $sid = ($raw | ConvertFrom-Json).session_id
    if ([string]::IsNullOrWhiteSpace($sid)) { exit 0 }

    $dir = Join-Path $PSScriptRoot "play_log"
    $marker = Join-Path $dir "active_session.txt"
    if (-not (Test-Path -LiteralPath $marker)) { exit 0 }
    $id = (Get-Content -LiteralPath $marker -Encoding UTF8 -TotalCount 1)
    if ($null -eq $id -or $id.Trim() -ne ([string]$sid).Trim()) { exit 0 }

    $file = Get-ChildItem -LiteralPath $dir -Filter "day_*.md" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

    $where = "none found"
    if ($file) { $where = $file.FullName }
    $head = "[rimworld-play resume] This session is playing RimWorld through the rimworld-play skill. If the user allowed it, it goes on playing by itself after a compaction, for RimWorld play only. Handoff: $where. Before any run: send ``show speed.`` and ``show status.`` and trust the game over this file."

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
