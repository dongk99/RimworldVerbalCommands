# Brief 12: stage a GitHub release folder (mod + briefs/notes + transcripts)

Staging dir: `C:\Users\[user]\.claude\projects\RimWorld-LLM-Integration\github_release\`. Build the
repo contents there. Do NOT run `git init`, do NOT create any remote, do NOT push. The user writes
the README.md themselves, so do not create a top-level README.md.

## 1. Copy these (and nothing else)

- `mod\` → `github_release\mod\`, **excluding** `mod\Models\**\*.onnx` (the encoder is 188 MB, and
  GitHub rejects files over 100 MB). Keep `tokens.txt` and the model README.md. Add
  `github_release\mod\Models\sherpa-onnx-streaming-zipformer-en-2023-06-21\DOWNLOAD.md` containing:
  the release URL
  `https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-2023-06-21.tar.bz2`,
  the three int8 file names to copy into this folder, and their byte sizes and SHA256, computed from
  `models\sherpa-onnx-streaming-zipformer-en-2023-06-21\` (read only).
- `briefs\*.md` → `github_release\briefs\`.
- Notes: only `notes\E_draft_groups_mods.md`, `notes\F_hotkey_focus_gating.md`,
  `notes\G_offline_stt_options.md` → `github_release\notes\`. Do NOT copy A, B, C, D: they contain
  verbatim decompiled RimWorld code, other authors' mod code, or wiki text.
- NEVER copy `sources\`, `models\`, `src\`, the RimWorld install, or anything from the RimWorld
  Config folder.

## 2. Transcript converter

Input: `github_release\_work\session_redacted.jsonl`. This is a Claude Code session log that
the lead already redacted. Do not look for or try to recover the original.

Write `github_release\_work\render_transcript.py` (Python 3, stdlib only). First inspect the JSONL
structure yourself: record types, message.content block types (text, thinking, tool_use,
tool_result), isSidechain, the compaction summary entry, and system-reminder text. The script must
produce:

- `github_release\transcripts\annotated.md`: every turn in order.
  - User text.
  - Assistant text.
  - Each tool call as a fenced block with the tool name and input. Trim inputs over 3000 characters.
  - Each tool result, trimmed to 3000 characters with a `[... truncated N chars]` marker.
  - Subagent hand-back messages and task notifications.
  - System reminders, shown as collapsed `<details>` blocks. The user chose to keep them.
  - Exclude thinking blocks entirely.
- `github_release\transcripts\plain.md`: human-readable chat only. Include only the user's typed
  messages (not tool results, not system reminders) and the assistant's text replies, headed
  "User" / "Claude". Mark the compaction point with one line.

Copyright filter (the user's instruction: "no copyright content of ludeon should be in there"). In
annotated.md, replace a tool RESULT with
`[omitted: third-party copyrighted source (RimWorld/Unity/other mods)]` when EITHER:
- (a) the matching tool_use input mentions any of: `RimWorldDecompiled`, `sources\`, `sources/`,
  `RimWorldWin64_Data`, `RimWorld\Data`, `RimWorld/Data`, `ilspycmd`, `wiki_text`,
  `notes/A_`, `notes/B_`, `notes/C_`, `notes/D_`, `notes\A_`, `notes\B_`, `notes\C_`, `notes\D_`;
  OR
- (b) the result text contains `namespace Verse`, `namespace RimWorld`, `namespace UnityEngine`,
  `namespace LudeonTK`, or `using Verse.` together with `Decompiled`.

Keep the tool_use input itself (it is just a command or path). Count the omissions and print the
count.

Run the script and print: turn counts, omission count, and output sizes.

## 3. Audit (report only, don't auto-fix)

Scan everything under `github_release\` except `_work\`. Report file:line for any hit of:
- `namespace Verse`, `namespace RimWorld`, `namespace UnityEngine`, `namespace LudeonTK`;
- the strings `sk-`, `api_key`, `apiKey`, `x-api-key`, `ghp_`, `@proton`, `@gmail`;
- any file over 50 MB.

Print the full file tree with sizes. The lead verifies all of this separately.

## Hard constraints

- No git init, no remote, no push, and no network access except none needed. Do not download
  anything.
- Never kill, stop or signal any process.
- Never read or touch `%USERPROFILE%\AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\Config`
  or the original un-redacted session JSONL under `C:\Users\[user]\.claude\projects\C--Users-[user]--local-bin\`.
- Do not modify anything outside `github_release\`.
- If a key-like string appears in any output, do NOT print it in your report. Report only its
  file:line and pattern name.
