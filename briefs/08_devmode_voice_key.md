# Brief 08 — separate voice-toggle key in dev mode + one-time warning dialog

Builds on brief 07 (already implemented, compiled, NOT deployed). Read `briefs/07_voice_autostart_icon.md`
and the current source first.

## Why (verified)

In dev mode vanilla consumes the ~ (`BackQuote`) keypress before our handler:
`Verse/DebugWindowsOpener.cs:22-33` checks `KeyBindingDefOf.Dev_ToggleDebugLog.KeyDownEvent` inside
`if (Prefs.DevMode)` and calls `Event.current.Use()`; that runs from `Verse/UIRoot.cs:50`, before
`GameComponentUtility.GameComponentOnGUI()` at `:66`. So with dev mode on, ~ never reaches us.

## User-decided design (do not change)

1. **Second keybinding** `VerbalCommands_VoiceToggleDev`, default `Backslash`, same category as
   `VerbalCommands_VoiceToggle`. (Checked: no `defaultKeyCodeA/B` or `defaultHotKey` in
   `E:\STEAM\steamapps\common\RimWorld\Data` uses Backslash.)
2. **Active key:** evaluate `Prefs.DevMode` live on every event (`Verse/Prefs.cs:368`). Dev mode on →
   only `VerbalCommands_VoiceToggleDev` toggles voice; dev mode off → only `VerbalCommands_VoiceToggle`.
   Same toggle behaviour as brief 07 in both cases (inside-dialog toggle; outside-dialog only with
   `voiceToggleEverywhere`). Don't consume the inactive key.
3. **Icon:** tooltip shows the currently active key; clicking rebinds the currently active def.
   Generalize the existing `Dialog_DefineVoiceToggleBinding` to take the `KeyBindingDef` as a ctor
   parameter (still saves via `KeyPrefs.Save()` in `PostClose`).
4. **Mod settings:** add two one-line rows, each a label with the current key and a button that opens
   the rebind popup: "Voice toggle key" and "Voice toggle key (dev mode)". Plus one checkbox
   "Remind me about the dev-mode voice key" bound to the inverse of the suppression setting below,
   so the player can turn the reminder back on.
5. **One-time warning dialog** on entering a game:
   - Trigger: both new game and loaded game. Use `GameComponent.StartedNewGame()` and
     `LoadedGame()` (`Verse/GameComponent.cs:27,31`); verify they fire once per entry and that the
     WindowStack is usable then. If a dialog added directly there would appear during the loading
     screen or get closed, defer it with `LongEventHandler.ExecuteWhenFinished` (verify it exists in
     the decompiled source) and report what you chose and why.
   - Gate (all must be true): `Prefs.DevMode`; the suppression setting is false; and
     `VerbalCommands_VoiceToggle`'s bound key equals `Dev_ToggleDebugLog`'s bound key (if the player
     already rebound one of them, there is no conflict and no reason to warn). Show at most once per
     game entry.
   - Content (Keyed strings, plain wording): dev mode is on, so ~ opens the debug log and does not
     toggle voice; in dev mode the voice toggle is Backslash \ by default (show the actual currently
     bound dev key via `MainKeyLabel`); both keys can be changed in Mod Settings > Verbal Commands.
   - A "Don't remind me" checkbox, **ticked by default**. The value is committed only when the
     dialog closes (by the Close button, the X, or Escape): on close, write it to the suppression
     setting and call `Settings.Write()`. Unticking then closing means it will show again next entry.
   - A Close button. Hovering the Close button shows a tooltip: the mod folder's README.md has tips
     for things like this. Use `TooltipHandler.TipRegion` on the button rect.
   - Use a custom `Window` subclass (e.g. `Dialog_DevModeVoiceKeyNotice`), sized for the text,
     `doCloseX = true`, `closeOnCancel = true`, `forcePause = true`, `absorbInputAroundWindow = true`.
     Commit the checkbox in `PostClose()` so every close path saves it.

## Settings

Add `devModeVoiceNoticeSuppressed` (default `false`) to `VerbalCommandsSettings` with
`Scribe_Values`. Keyed strings for all new labels, dialog text and tooltips.

## README

Add a short "Dev mode" note to the voice section: ~ is the vanilla dev-mode debug-log key, so in dev
mode the voice toggle is Backslash by default; both keys are in Mod Settings; the one-time notice and
how to turn it back on.

## Hard constraints

- Touch only files involved in this feature: the voice/keybinding/settings/dialog sources, the new
  notice dialog file, the KeyBinding XML, Keyed XML, `mod\README.md`. Nothing unrelated.
- **Compile only.** Run `dotnet build src\VerbalCommands\VerbalCommands.csproj -c Release`. Do NOT run
  `build.ps1`, do NOT copy anything into `E:\STEAM\steamapps\common\RimWorld\Mods\VerbalCommands`.
  The user deploys only when they say so.
- **Never kill, stop or signal any process**, including RimWorld.
- Do NOT read or touch the RimWorld Config folder
  (`%USERPROFILE%\AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\Config`).
- Verify every engine API against `sources/RimWorldDecompiled` before use; cite path:line in comments.
- If anything contradicts this brief or does not compile, stop and report.
- Report: files changed with diffs, verification notes (especially the dialog timing choice), build
  result, compiled DLL path/size/SHA256, explicit statement that nothing was deployed.
