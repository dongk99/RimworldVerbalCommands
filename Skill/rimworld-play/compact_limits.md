# Compaction limits

File: `<skill folder>\compact_limits.json`

- `warn`: context (tokens) from which the orchestrator is told to append to the current day's note.
- `valve`: context (tokens) from which a compaction is due, once that note has grown since the warning.

Both are read by `compact_common.ps1`.

Desktop: `<home>\Desktop\compact_limits.ps1` shows both (300 = 300k) and sets them.
