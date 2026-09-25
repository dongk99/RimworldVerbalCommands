# Verbal Commands

Type a colony order in plain language (press Return in-game); the mod sends it to Claude and applies the resulting schedule, allowed-area and work-priority changes through RimWorld's own API.

Settings: Options > Mod settings > Verbal Commands.

## Effort setting

`Effort` maps to the Anthropic Messages API field `output_config.effort`. Values: `low`, `medium`, `high`, `xhigh`, `max`.

- **Blank or `high`**: the field is not sent at all. Per the official docs, "Setting `effort` to `"high"` produces exactly the same behavior as omitting the `effort` parameter entirely."
- **Models without effort support** (for example `claude-haiku-4-5-20251001`, listed as "Not supported" in the model comparison table): if you set a non-high effort, the API returns HTTP 400 `invalid_request_error`. The mod catches that, resends the same request once without `output_config`, remembers the model for the rest of the session, and prints a line in the order window:

  `effort: model rejected output_config.effort (<API message>); request resent without it. Leave effort blank or 'high' for this model to skip the retry.`

- Supported models (docs, 2026-09-02): `claude-fable-5-1`, `claude-mythos-5-1`, `claude-fable-5`, `claude-mythos-5`, `claude-mythos-preview`, `claude-opus-5`, `claude-opus-4-8`, `claude-opus-4-7`, `claude-opus-4-6`, `claude-opus-4-5-20251101`, `claude-sonnet-5`, `claude-sonnet-4-6`.

Currently, Medium/High setting is used on to test on Opus 5, 5.5 and Sonnet 5. Haiku 4.5 does not support this, and even with extended reasoning it does not fully do the task it was told to do (but it can do *some* of it accurately when attention goes to it). This likely means we can potentially make a rule where haiku can be used for certain stuff by only being shown small part of actual data instead of in its entirety.

## Headless mode

`Use Claude Code CLI` runs `claude -p` with your existing Claude Code login instead of an API key. Effort is passed to the CLI as `--effort` unchanged; the fallback above applies to API mode only. Expect claude -p to take longer for setup, a console account (or local llm after user testing) is recommended if user wants speed.

## Pawn groups

Say something like "group 3 = everyone holding a rifle with range 25 or more; call it long guns" and the mod stores a RULE (weapon class, range, an explicit allow-list of weapon defNames, always-include/exclude pawns, and whether unarmed colonists count) in one of 9 hotkey slots. It does **not** store a fixed list of pawns.

example prompt: "Pawns who hold sniper rifle or charge lance or other long range weapons will have group 1, medium range weapons such as assault rifles and charge rifles will have group 2, shorter range weapons such as pistols group 3, short range weapons as shotguns as group 4, melee as group 5, special weapons (staffs, insanity lance, etc) as group 6, barehanded as group 7.

Pressing that slot's key evaluates the rule against colonists' **current** equipment and selects the matches, live, with no LLM call at keypress. Holding **Alt** while pressing the key also drafts every matched pawn that can be drafted (has a draft controller, is not downed, and is not already drafted); downed pawns are still selected but never drafted.

The first time a group is defined, a dialog asks whether to bind the group keys:
- **F1-F9**: unbinds only the shortcut for the Work/Schedule/Assign/Animals/Wildlife/Research/Quests/World/History tabs (the tabs stay clickable via the on-screen buttons) and binds F1-F9 to groups 1-9.
- **Number row**: binds 5, 6, 7, 8, 9, 0 to groups 1-6 (unbound in vanilla); groups 7-9 stay unbound in this layout.
- **Manual**: nothing is bound automatically; bind `VerbalCommands_Group1`..`_Group9` yourself in Options > Keyboard.

Options > Mod settings > Verbal Commands has a "Choose group hotkeys…" button to re-run that prompt, and a "Restore vanilla tab keys (F1-F9)" button that undoes an F-key binding and clears every group key.

## Voice input (still being tested, to be updated)

Voice uses a bundled **offline** English speech model (sherpa-onnx streaming zipformer) - no internet
connection needed, and no audio ever leaves your machine. This replaced Windows' own speech
recognition, which produced no output at all on testing.

Pressing **~** (BackQuote) opens the order box with voice already listening (the "voice toggle
everywhere" setting, **on by default**). The order box **pauses the game** while it's open. Speak,
watch the live (grey) hypothesis line under the order box fill in, then review/edit the text and press
**Send**. Sending:
- Sends the typed/edited text as your order (voice only ever fills the text box, it never sends
  anything by itself).
- Stops voice **for that box only** - the mic is released. It does not change the voice-on-by-default
  setting, so opening the box again (or toggling ~ back on inside it) starts listening again.

Closing the box always stops recognition and releases the mic; nothing is loaded, captured or decoded
while the box is closed - the model is loaded fresh each time the box opens (in the background, so
the box is responsive immediately) and disposed when it closes.

Rebind the toggle key by clicking the mic status icon next to the "Verbal Commands" title (it opens
the same rebind popup as Options > Keyboard); hovering the icon shows the current voice state (loading
model / listening / off / error and why) and the active toggle key. Green mic = actively listening
(model ready and mic capturing); grey mic with a slash = anything else.

Options > Mod settings > Verbal Commands has a "Voice toggle key (~) works everywhere, not just in the
dialog" checkbox (on by default) - turn it off if you only want ~ to work while the order box is
already open.

### Dev mode

**~** is also vanilla's dev-mode "toggle debug log" key (`Dev_ToggleDebugLog`), and vanilla's own
handler for it runs before this mod ever sees the keypress. So while dev mode is on, ~ opens/closes
the debug log as usual and does **not** toggle voice - in dev mode, the voice toggle is **Backslash
\\** by default instead. Both keys (the normal one and the dev-mode one) are separate bindings, each
changeable in Options > Mod settings > Verbal Commands, or by clicking the mic icon (which rebinds
whichever of the two is currently active).

### Saved transcripts (opt-in, off by default)

Options > Mod settings > Verbal Commands has a "Save sent orders to transcripts.jsonl (for checking
voice accuracy)" checkbox. When it's on, every Send appends one line of JSON to:

`%USERPROFILE%\AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\transcripts.jsonl`

Each line has: `utc` (when it was sent), `voice` (whether any recognized speech was appended to that
order), `voice_raw` (what the recognizer actually heard, before any edits), `sent_text` (exactly what
was sent), `edited` (whether `sent_text` differs from `voice_raw`), and `stt_model` (the model folder
name, or `null` if `voice` is false). This is entirely separate from RimWorld's own `Config` folder and
this mod never reads or writes anything there.

### Third-party notices

- **sherpa-onnx** (`org.k2fsa.sherpa.onnx` and `org.k2fsa.sherpa.onnx.runtime.win-x64`, both version
  1.13.8, © Xiaomi Corporation) - Apache License 2.0, per both packages' `.nuspec` 
  *(Currently not included in github files, since it is being tested)
  (`<license type="expression">Apache-2.0</license>`). Source: https://github.com/k2-fsa/sherpa-onnx
- **onnxruntime.dll** - bundled as a native binary inside the sherpa-onnx runtime package with no
  separate license file included in it; upstream project (Microsoft) is
  https://github.com/microsoft/onnxruntime, published under the MIT License.
- **Model**: `sherpa-onnx-streaming-zipformer-en-2023-06-21` (English, LibriSpeech + GigaSpeech) -
  Apache License 2.0, per the model folder's own `README.md` front matter
  (`license: apache-2.0`). Trained from
  https://huggingface.co/marcoyang/icefall-libri-giga-pruned-transducer-stateless7-streaming-2023-04-04.
