# Compaction limits

File: `<skill folder>\compact_limits.json`

- `warn`: context (tokens) from which the orchestrator is told, once, to append to the current day's note.
- `valve`: context (tokens) from which a compaction is due.

Both are read by `compact_common.ps1`.

Desktop: `<home>\Desktop\compact_limits.ps1` shows both (300 = 300k) and sets them.
