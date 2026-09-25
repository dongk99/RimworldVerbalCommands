# Brief 06 — push-to-talk dictation into the order box (Unity DictationRecognizer)

## Goal

Add a microphone button to `Dialog_VerbalCommand` that dictates speech into the order text box using
Unity's built-in `UnityEngine.Windows.Speech.DictationRecognizer`. The player clicks Mic, speaks,
the recognized text is appended to `orderText`, the player reviews/edits and presses Send as usual.
Dictation only fills the text box. It never sends anything on its own.

Primary purpose of this first build is also diagnostic: the user will test English and Korean and we
need to learn what language the recognizer uses and how it fails. Log generously (see Logging).

## Verified facts (cite in comments)

- The type ships with RimWorld: the string `DictationRecognizer` is present in
  `E:\STEAM\steamapps\common\RimWorld\RimWorldWin64_Data\Managed\UnityEngine.CoreModule.dll` and
  `UnityEngine.dll`. Before writing code, decompile with `ilspycmd` (you used it in brief 05) and
  report: which assembly actually defines `UnityEngine.Windows.Speech.DictationRecognizer`, its
  public members, and whether the csproj already references that assembly. If the type is missing
  or its members differ from the list below, STOP and report.
- Unity docs (https://docs.unity3d.com/2022.3/Documentation/ScriptReference/Windows.Speech.DictationRecognizer.html):
  Windows 10 only; dictation must be enabled in Windows Settings (Privacy > Speech, inking &
  typing); if not, `Start()` fails and `DictationError` reports
  `SPERR_SPEECH_PRIVACY_POLICY_NOT_ACCEPTED` (0x80045509); it "can only be started if
  PhraseRecognitionSystem is not running"; must be released with `Dispose()`.
  Members: properties `AutoSilenceTimeoutSeconds`, `InitialSilenceTimeoutSeconds`, `Status`; events
  `DictationResult`, `DictationHypothesis`, `DictationComplete`, `DictationError`; methods
  `Start()`, `Stop()`, `Dispose()`.
- Constructors (https://docs.unity3d.com/2022.3/Documentation/ScriptReference/Windows.Speech.DictationRecognizer-ctor.html):
  `()`, `(ConfidenceLevel)`, `(DictationTopicConstraint)`, `(ConfidenceLevel, DictationTopicConstraint)`.
  Defaults Medium / Dictation. There is NO language parameter. Do not try to add one.
- Existing project facts: `Dialog_VerbalCommand` has `orderText` and a 4-button row
  (Send/Apply/Cancel/Close) and already overrides `PostClose()` (brief 05). `MainThread.Post` exists
  for marshaling work to the main thread (drained in `GameComponent_VerbalCommands.GameComponentUpdate`).

## Design (implement exactly this)

New file `src\VerbalCommands\DictationSession.cs`, a small wrapper class owned by the dialog:

- Holds one `DictationRecognizer` or null. `IsListening` bool. `Hypothesis` string (latest partial).
- `Start()`: if `Application.platform != RuntimePlatform.WindowsPlayer` → do nothing (the button is
  hidden anyway). If `PhraseRecognitionSystem.Status == SpeechSystemStatus.Running`, report an error
  instead of starting (only if those types exist; verify). Create the recognizer, subscribe all four
  events, call `Start()`. Wrap in try/catch; on exception log it and Dispose.
- `Stop()`: call `Stop()` if running, then `Dispose()`, null it out, unsubscribe. Idempotent.
- Event handlers must NOT touch the dialog or any game object directly. Marshal every handler body
  through `MainThread.Post(...)`, whether or not Unity already raises them on the main thread (not
  verified either way).
  - `DictationHypothesis(text)` → set `Hypothesis`.
  - `DictationResult(text, confidence)` → append `text` to the dialog's `orderText` (one space
    separator if `orderText` is non-empty and doesn't end in whitespace); clear `Hypothesis`.
    Use a callback `Action<string>` passed in by the dialog; don't reach into the dialog.
  - `DictationComplete(cause)` → log the cause; if cause is not Complete-normal, show a message;
    then `Stop()` (release the mic).
  - `DictationError(error, hresult)` → log both; if hresult is 0x80045509 (compare as int,
    unchecked cast), show a player message saying speech recognition is disabled in Windows
    Settings > Privacy > Speech; otherwise show a generic message with the hex code. Then `Stop()`.

`Dialog_VerbalCommand` changes:

- Add a Mic button. Keep the existing four buttons; make the row five buttons wide (same pattern as
  the current width math). Label "Mic" when idle, "Stop" while listening (keyed strings).
  Hide/disable it when not on `RuntimePlatform.WindowsPlayer`.
- While listening, draw the current `Hypothesis` in a single grey label line directly under the
  order box (only while non-empty). No other layout changes.
- Existing `PostClose()` override: call `dictation.Stop()` before the existing unfocus call.

Resource rule (user hard rule, no silent resource seizure): the microphone is only acquired on the
player's explicit Mic click and must be released on Stop click, on DictationComplete, on
DictationError, and on dialog close. No auto-start, no auto-restart, no keeping it open between
dialogs. There is no hotkey for dictation in this build.

## Logging (diagnostic, required)

Prefix `[VerbalCommands] dictation:`. Log: start requested; recognizer Status after Start();
every DictationComplete cause; every DictationError message + hresult as hex; each final result
text with its confidence. This is how we learn language behavior from the user's English/Korean test.

## Strings

Add to `mod\Languages\English\Keyed\VerbalCommands.xml`: `VerbalCommands_Mic`, `VerbalCommands_MicStop`,
`VerbalCommands_DictationPrivacyOff`, `VerbalCommands_DictationError` (takes the hex code),
`VerbalCommands_DictationEnded` (takes the cause). One line each, short.

## README

Add a short "Voice input (Windows only)" section to `mod\README.md`: click Mic, speak, review, Send;
requires Windows speech recognition enabled in Privacy settings; uses Windows' own online speech
recognition, so audio is processed by Microsoft; language cannot be chosen in the mod and follows
Windows' speech settings (state this as "appears to", it is not officially documented); some
languages may not be supported.

## Hard constraints

- Touch only: new `DictationSession.cs`, `Dialog_VerbalCommand.cs`, the Keyed XML, `mod\README.md`,
  and the csproj only if a reference must be added (report it if so). Nothing else.
- Do NOT read or touch the RimWorld Config folder
  (`%USERPROFILE%\AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\Config`) — it holds the
  user's API key.
- Every engine/Unity claim in comments must be backed by the decompiled assembly or the two Unity
  doc URLs above.
- If anything contradicts this brief or does not compile, stop and report; do not redesign.
- Build with `build.ps1`. Report: decompile findings, full diff, build warnings/errors, deployed DLL
  path/size/timestamp/SHA256.
