# Brief 11: replace Windows dictation with sherpa-onnx; pause, Send and open-key behaviour; transcript log

Read first: `briefs/07`, `08`, `09`, `notes/G_offline_stt_options.md`, and the current source.
Windows speech recognition (Unity `DictationRecognizer`) produces nothing on the user's machine, and
Win+H does not work either, so this brief **replaces** it with a bundled offline engine: sherpa-onnx
streaming zipformer. Remove `DictationSession.cs` and every use of `UnityEngine.Windows.Speech`.

## A. User-decided behaviour (do not change)

The loop the user specified: press ` → the game pauses → the Verbal Commands box opens → speech is
typed live into the box → the user clicks Send → voice stops for that box → the user closes the box
→ pressing ` again repeats the loop.

1. **Open key.** Setting `voiceToggleEverywhere` now defaults to **true**. Existing installs have
   `false` saved, so add an int `settingsVersion` (Scribe default 0). On load, if it is < 1, set
   `voiceToggleEverywhere = true` and `settingsVersion = 1`. When the box is closed, the active toggle
   key (` normally, \ in dev mode; brief 08, unchanged) opens the box with voice on.
2. **Pause.** `Dialog_VerbalCommand` sets `forcePause = true` (see `Verse/Window.cs`; the dev-mode
   notice already uses it).
3. **Inside the box, `** still toggles voice on/off and persists `voiceEnabled` (unchanged).
4. **Send stops voice for this box only.** On a Send click: stop recognition and release the mic.
   `voiceEnabled` is NOT changed, so the next opening starts listening again. The toggle key inside
   the box can turn voice back on in the same box.
5. **Close** (any path, via `PostClose`): stop recognition, release the mic, and dispose the
   recognizer and model.
6. **Engine runs only while the box is open.** Nothing loads, captures or decodes while the box is
   closed. The model loads when the box opens with voice on, on a background thread, and is
   disposed on close.
7. **Live text.** The partial result shows in the existing grey hypothesis line under the order box.
   When the recognizer reports an endpoint, the finalized segment is appended to `orderText` (same
   append rule as the existing `AppendDictatedText`), then the stream is reset.
8. **Icon.** Green = mic capturing AND recognizer ready. Grey with slash = otherwise. The tooltip
   gives the state, one of: loading model / listening / off / error + reason. It also shows the
   active key and "click to change key" (brief 07/08 behaviour otherwise unchanged).

## B. Engine: sherpa-onnx (verify every API before use)

- NuGet: `org.k2fsa.sherpa.onnx` 1.13.8, plus the Windows x64 native runtime package
  (`org.k2fsa.sherpa.onnx.runtime.win-x64`; verify the exact id). Read the managed assembly's
  public API with `ilspycmd`: `OnlineRecognizerConfig`, `OnlineRecognizer`, `OnlineStream`,
  `AcceptWaveform`, `IsReady`, `Decode`, `GetResult`, `IsEndpoint`, `Reset`, and the `DllImport`
  library names. Cite what you find in comments. If the API differs from these names, adapt to the
  real API and report it.
- **Model** (already downloaded, extracted by the user's request):
  `models\sherpa-onnx-streaming-zipformer-en-2023-06-21\`. Copy ONLY these files into
  `mod\Models\sherpa-onnx-streaming-zipformer-en-2023-06-21\`: `encoder-epoch-99-avg-1.int8.onnx`,
  `decoder-epoch-99-avg-1.int8.onnx`, `joiner-epoch-99-avg-1.int8.onnx`, `tokens.txt`, plus any
  LICENSE/README in that folder. Do not copy the fp32 files or test_wavs. Resolve the path at
  runtime from the mod's root dir (`ModContentPack.RootDir`; verify).
- Config: transducer model, `num_threads = 2`, provider cpu, `decoding_method = greedy_search`,
  endpoint detection enabled with sherpa's default rules (verify the default values from the
  wrapper and cite them).
- **Native DLL placement.** Check `Verse/ModAssemblyHandler.cs` (or wherever RimWorld loads
  `Assemblies\*.dll`) to learn whether it tries to load every `.dll` there as managed. If it does,
  native DLLs must NOT go in `1.6\Assemblies`. Put them in `mod\1.6\Native\` and preload them by
  full path with `kernel32!LoadLibraryW` (in dependency order, onnxruntime first) before the first
  P/Invoke. Log each load result. The managed `sherpa-onnx.dll` goes in `1.6\Assemblies` and must
  load cleanly under RimWorld's Mono (netstandard2.0 or net4x build; pick whichever the package
  offers that RimWorld's `Managed\netstandard.dll` supports, and report the choice).
- **Mic capture.** Use `UnityEngine.Microphone` from `UnityEngine.AudioModule.dll`. First verify
  with `ilspycmd` that `Start`, `End`, `GetPosition`, `IsRecording`, `devices` and
  `GetDeviceCaps` exist, and add the csproj reference if needed. Use the default device, looping
  clip, 16000 Hz mono if the caps allow it; otherwise the nearest supported rate, passing the real
  rate to `AcceptWaveform` (verify that sherpa resamples). On the main thread, each frame while
  capturing, read new samples since the last `GetPosition` (handle wraparound). Hand them to ONE
  background worker thread that runs AcceptWaveform/Decode/GetResult/IsEndpoint. The worker posts
  partial and final text through `MainThread.Post` and never touches game or dialog state
  directly. Confirm that `GameComponentUpdate` runs while the game is paused (`Verse/Game.cs`
  `UpdatePlay`, around line 657) and cite it. If it does not, drive the poll from somewhere that
  does.
- **Resource rule** (user hard rule, no silent resource seizure): the mic is acquired only when the
  box opens with voice on, or on toggle-on. It is released on toggle-off, Send, close and error.
  `Microphone.End` must run on every one of those paths.
- **Errors.** No mic device, a native load failure or a model load failure means: log with
  `[VerbalCommands] stt:`, show one player message, grey icon with the reason, and keep the typed
  path working. Never throw out of OnGUI or Update.
- **Diagnostic logging** (prefix `[VerbalCommands] stt:`): native preload results, model load time
  in ms, mic device name and actual sample rate, recognizer ready, start/stop with reason
  (toggle/Send/close/error), and worker exceptions. Do NOT log recognized text to Player.log.

## C. Transcript log (opt-in)

The user confirmed the mod never persists what the player sends, so add it:
- New setting `saveTranscripts`, default **false**, with a checkbox in mod settings: "Save sent
  orders to transcripts.jsonl (for checking voice accuracy)".
- When it is on, every Send appends one JSON line (Newtonsoft, already shipped) to
  `Path.Combine(GenFilePaths.SaveDataFolderPath, "VerbalCommands", "transcripts.jsonl")`. Create the
  directory. Verify in `Verse/GenFilePaths.cs` that this path is NOT inside the `Config` folder, and
  cite it. **Never write to or read the Config folder.**
- Fields: `utc` (ISO 8601); `voice` (bool: any recognizer final was appended to this order);
  `voice_raw` (the recognizer finals appended since the last Send or open, joined with single
  spaces; "" if none); `sent_text` (exact text sent); `edited` (bool:
  `voice && sent_text.Trim() != voice_raw.Trim()`); `stt_model` (model folder name, or null when
  `voice` is false).
- File I/O goes off the main thread or is wrapped in try/catch. A failure logs once and never
  blocks Send.

## D. Other files

- KeyBinding XML and Keyed XML: new or updated strings for all new tooltips, messages and settings.
- `mod\README.md`: rewrite the voice section. Voice uses a bundled offline English model
  (sherpa-onnx, Apache-2.0); no Windows speech settings and no internet needed; the box pauses the
  game; voice stops after Send; ` opens the box (setting); the transcript option and where the file
  lives. Add a third-party notice for sherpa-onnx, onnxruntime and the model, with their licenses as
  found in the packages or model folder.

## Hard constraints

- Compile only: `dotnet build src\VerbalCommands\VerbalCommands.csproj -c Release`. Do NOT run
  `build.ps1`. Do NOT copy anything into `E:\STEAM\steamapps\common\RimWorld\Mods`. Do NOT launch
  RimWorld.
- **Never kill, stop or signal any process**, including RimWorld.
- Do NOT read or touch `%USERPROFILE%\AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon
  Studios\Config`.
- Do not modify or delete anything under `models\` (read and copy only).
- Every RimWorld/Unity/sherpa API fact in comments cites the decompiled source path:line or the
  ilspycmd output.
- If something contradicts this brief, or it can't compile, stop and report. Do not redesign.
- Report: files added/changed/removed with a summary diff; API verification findings (sherpa
  names, DllImport names, Microphone members, ModAssemblyHandler behaviour, GenFilePaths paths,
  whether GameComponentUpdate runs while paused); build result; the full `mod\` tree with sizes of
  new files; DLL SHA256; explicit statement that nothing was deployed.
