# Brief 07 — voice auto-start, ~ toggle, mic status icon (supersedes brief 06's Mic button)

Brief 06 added `DictationSession.cs` and a clickable Mic/Stop button. It compiled but was never
deployed. The user redesigned the UX. Keep `DictationSession` (reuse it), remove the Mic button,
and implement the design below. Read `briefs/06_voice_dictation.md` for the verified Unity facts;
they all still apply.

## User-decided design (do not change)

1. **Auto-start.** When the Verbal Commands dialog opens and the voice setting is ON, dictation
   starts automatically. Voice is ON by default for a fresh install (user decision).
2. **Toggle keybinding** `VerbalCommands_VoiceToggle`, default `BackQuote` (the ~ key; Unity has
   no separate ~ keycode for this key — `Verse/GenText.cs:1363` maps `KeyCode.BackQuote` to "`").
   - While the dialog is open: pressing it flips the persisted voice setting and starts/stops
     dictation immediately.
   - While the dialog is closed: only acts if the new mod setting **"Voice toggle works everywhere"**
     is enabled (default **false**). Then pressing it opens the dialog with voice ON (set the
     setting to ON and auto-start), so the player can see the dictated text. If that setting is
     false, do NOT consume the key — vanilla binds `BackQuote` to `Dev_ToggleDebugLog`
     (`E:\STEAM\steamapps\common\RimWorld\Data\Core\Defs\Misc\KeyBindings\KeyBindings.xml:395-399`)
     and it must keep working.
3. **Status icon** drawn immediately right of the "Verbal Commands" title label at the top of the
   dialog (same row, vertically centered with it, ~24px).
   - Green mic = actively listening. Grey mic with a diagonal slash = not listening.
   - Hover tooltip: voice state (on / off / error reason if the last session failed), the current
     toggle key (`VerbalCommands_VoiceToggle.MainKeyLabel`), and "click to change key".
   - Click: opens the vanilla rebind popup for `VerbalCommands_VoiceToggle` (see below).
4. **Remove the Mic/Stop button.** Button row goes back to exactly Send / Apply / Cancel / Close as
   before brief 06. Keep the grey live-hypothesis line under the order box.

## Behaviour details (implement exactly)

- **Keep listening while the dialog is open and voice is ON.** `DictationRecognizer` ends sessions on
  its own (`DictationCompletionCause` includes `TimeoutExceeded`, `PauseLimitExceeded`, `Complete`).
  On those three causes, restart dictation automatically while the dialog is still open and voice is
  still ON. Loop guard: if 3 sessions end within 10 seconds of real time (`Time.realtimeSinceStartup`),
  stop restarting, show a message, and show the icon as not listening with the reason in the tooltip.
- **On any `DictationError`, or completion causes `AudioQualityFailure`, `NetworkFailure`,
  `MicrophoneUnavailable`, `UnknownError`, `Canceled`:** stop, do not restart, keep the voice
  *setting* unchanged, show the icon as not listening, put the reason in the tooltip, and show the
  existing player message (privacy-off message for hresult 0x80045509). Pressing the toggle twice
  (off, on) retries.
- **Mic release:** stop and dispose on dialog close (existing `PostClose` path), on toggle-off, and on
  the error paths above. The mic is never held while the dialog is closed.
- Icon green only when the recognizer is actually running, not merely when the setting is ON.

## Rebinding by clicking the icon

`RimWorld.Dialog_DefineBinding(KeyPrefsData, KeyBindingDef, KeyPrefs.BindingSlot)`
(`sources/RimWorldDecompiled/RimWorld/Dialog_DefineBinding.cs`) writes into whatever `KeyPrefsData`
it is given (`:59-63`) and does NOT save. Create a small subclass in our namespace that passes
`KeyPrefs.KeyPrefsData` and slot `A`, and overrides `PostClose()` to call `base.PostClose()` then
`KeyPrefs.Save()` (`Verse/KeyPrefs.cs:62`).

**Required input guard:** our `GameComponentOnGUI` runs before the window stack
(`Verse/UIRoot.cs:66` vs `RimWorld/UIRoot_Play.cs:43`), so while the rebind popup is open our
handlers would steal the key the player is trying to bind. At the very top of
`GameComponent_VerbalCommands.GameComponentOnGUI` (after the ProgramState check), return
immediately if `Find.WindowStack.IsOpen<Dialog_DefineBinding>()` (any subclass counts: check
`IsOpen(typeof(...))` semantics in `Verse/WindowStack.cs:295-318` and use whatever matches
subclasses; if none do, check our subclass type explicitly). Also apply it for vanilla's own
`Dialog_KeyBindings` rebinding flow, which uses the same popup.

## Key handling placement in `GameComponentOnGUI`

Order: (1) ProgramState check, (2) rebind-popup guard, (3) voice toggle key, (4) existing Return/open
handling, (5) existing group hotkeys. The toggle only calls `Event.current.Use()` when it actually
acted. When the dialog is open, the toggle acts even though the text box has focus (it's the point);
this means a literal backquote can't be typed into orders, which is acceptable.

## Settings

Add to `VerbalCommandsSettings` (persist with `Scribe_Values`): `voiceEnabled` (default `true`),
`voiceToggleEverywhere` (default `false`). Add one checkbox for each in the settings window
(one-line labels; details go in README). Keyed strings for both labels.

## Icon textures

Make two original 32x32 PNGs with transparent background at
`mod\Textures\VerbalCommands\MicOn.png` (green mic) and `MicOff.png` (grey mic with a diagonal
slash). Generate them with a script (e.g. Python writing PNG via zlib/struct, no external
downloads, no copied artwork). Load them in a `[StaticConstructorOnStartup]` static class with
`ContentFinder<Texture2D>.Get("VerbalCommands/MicOn")` — verify the path convention against the
decompiled `ContentFinder` before relying on it. Draw with `Widgets.ButtonImage` (verify signature)
and `TooltipHandler.TipRegion`.

## KeyBindingDef

Add `VerbalCommands_VoiceToggle` to `mod\Defs\KeyBindingDefs\VerbalCommands_KeyBindings.xml`, same
category as `VerbalCommands_Open`, `defaultKeyCodeA` `BackQuote`. Report any conflict warning the
game would log for it given the category rules in `Verse/KeyPrefsData.cs:65-74`.

## README

Rewrite the "Voice input (Windows only)" section: voice starts automatically when the box opens;
~ toggles it (rebind by clicking the mic icon; hover shows the key); green = listening, grey slash =
not listening; the "toggle everywhere" setting (off by default because ~ is vanilla's dev-mode debug
log key); keep the existing privacy/Microsoft/language notes.

## Hard constraints

- Touch only: `DictationSession.cs`, `Dialog_VerbalCommand.cs`, `GameComponent_VerbalCommands.cs`,
  `VerbalCommandsMod.cs` (settings), `VerbalCommandsDefs.cs` (if adding the def accessor), new icon
  class/file, new rebind subclass file, the KeyBinding XML, Keyed XML, `mod\Textures\...`,
  `mod\README.md`. Nothing else.
- Do NOT read or touch the RimWorld Config folder
  (`%USERPROFILE%\AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\Config`).
- **Never kill, stop or signal any process, including RimWorld.** If `build.ps1`'s deploy step is
  blocked because the game is running, stop the script, make sure no robocopy is left retrying,
  and report. Do not attempt workarounds.
- Every engine/Unity claim in comments must cite `sources/RimWorldDecompiled` path:line or the
  decompiled Unity assembly.
- If anything contradicts this brief or does not compile, stop and report.
- Report: files changed with diffs, verification notes, build result, compiled DLL path/size/SHA256,
  and whether deploy succeeded.
