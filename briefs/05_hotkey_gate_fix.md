# Brief 05 — fix sticky focus gate that kills group hotkeys until game restart

## Bug (already diagnosed — do not re-diagnose, just implement)

`GameComponent_VerbalCommands.GameComponentOnGUI` gates the group-hotkey branch on
`GUIUtility.keyboardControl != 0`. That is a latch, not a state: once the player clicks into a
`Widgets.TextArea` in `Dialog_VerbalCommand` (`Dialog_VerbalCommand.cs:34` order box, `:101` log
box), Unity leaves `keyboardControl` set to that control id forever. Closing the dialog does not
reset it, and reopening it with Return does not either. Result: group keys silently dead for the
rest of the process; only a game restart fixes it.

Verified facts backing the fix (cite these in comments where useful):

- `KeyBindingData` is a class (`sources/RimWorldDecompiled/Verse/KeyBindingData.cs:5`) and
  `KeyBindingDef.KeyDownEvent` re-reads `KeyPrefs.KeyPrefsData.keyPrefs` on every event
  (`Verse/KeyBindingDef.cs:47`). Binding changes are live; nothing here needs a restart.
- Our handler runs BEFORE the window stack: `GameComponentUtility.GameComponentOnGUI()` is at
  `Verse/UIRoot.cs:66`, inside `base.UIRootOnGUI()` which is the first statement of
  `RimWorld/UIRoot_Play.cs:26`; `windows.WindowStackOnGUI()` is not until `UIRoot_Play.cs:43` and
  main-tab hotkeys at `:32`. So `Event.current.Use()` here means no text field ever sees the key.
- Vanilla only clears `keyboardControl` in `Verse/Widgets.cs:1730`
  (`Widgets.ButtonInvisibleDraggable`) and `UI.UnfocusCurrentControl` (`Verse/UI.cs:56-59`).
- `Find.WindowStack.NonImmediateDialogWindowOpen` (`Verse/WindowStack.cs:110`) is derived state,
  recomputed every call, so it cannot latch.

## Edits (exactly these three, nothing else)

### 1. `src/VerbalCommands/Dialog_VerbalCommand.cs`

Add an override so we stop leaving stale focus behind (other mods gate on `keyboardControl` too):

```csharp
public override void PostClose()
{
    base.PostClose();
    UI.UnfocusCurrentControl();
}
```

`Verse` is already imported; `UI.UnfocusCurrentControl` is `Verse/UI.cs:56`.
`Window.PostClose` is `public virtual` (`Verse/Window.cs:179`).

### 2. `src/VerbalCommands/GameComponent_VerbalCommands.cs`

Replace the gate + loop currently at lines ~120-145. Delete the
`if (GUIUtility.keyboardControl != 0) { return; }` check entirely. New shape:

```csharp
// Group hotkeys (Alt = draft). This runs before the window stack (Verse/UIRoot.cs:66 inside
// base.UIRootOnGUI, RimWorld/UIRoot_Play.cs:26; windows draw at :43), so Use()ing a key here
// means no text field ever receives it. We therefore only need to hold back keys that would
// otherwise have been typed as characters.
if (Find.WindowStack.IsOpen<Dialog_VerbalCommand>())
{
    return;
}
if (Find.WindowStack.AnySearchWidgetFocused)
{
    return;
}

// Derived state, recomputed every call - unlike GUIUtility.keyboardControl it cannot latch on
// and disable group keys for the rest of the session (Verse/WindowStack.cs:110).
bool textEntryPossible = Find.WindowStack.NonImmediateDialogWindowOpen;

KeyBindingDef[] groupKeys = VerbalCommandsDefs.GroupKeys;
for (int slot = 1; slot <= 9; slot++)
{
    KeyBindingDef keyDef = groupKeys[slot];
    if (keyDef == null || !keyDef.KeyDownEvent)
    {
        continue;
    }
    // F-keys and other non-printing binds are safe even with a dialog open; number-row binds
    // (the NumberRow layout, or anything the player picked under Manual) are not.
    if (textEntryPossible && IsTextInputKey(keyDef.MainKey))
    {
        continue;
    }
    ActivateGroup(slot, Event.current.alt);
    Event.current.Use();
    return;
}
```

And add the helper to the same class:

```csharp
// True for keys that produce a character in a text field. UnityEngine.KeyCode is ordered so
// that Space(32)..Z(122) covers printable ASCII (Alpha0-9, A-Z, punctuation), and
// Keypad0(256)..KeypadEquals(272) covers the numeric keypad; KeypadEnter is not a character.
// Everything else - function keys (F1=282+), arrows, Insert/Home/End/PageUp/PageDown,
// modifiers - is safe to consume while a text field has focus.
private static bool IsTextInputKey(KeyCode key)
{
    int v = (int)key;
    if (v >= (int)KeyCode.Space && v <= (int)KeyCode.Z)
    {
        return true;
    }
    if (v >= (int)KeyCode.Keypad0 && v <= (int)KeyCode.KeypadEquals && key != KeyCode.KeypadEnter)
    {
        return true;
    }
    return false;
}
```

Verify the KeyCode ordering assumption against the real `UnityEngine.KeyCode` enum in the
referenced UnityEngine assembly (or Unity's public KeyCode docs) before you commit to it. If any
value does not line up, say so in your report instead of silently changing the approach.

### 3. Build

Run `build.ps1` from the project root. Report: whether the build was clean (warnings included),
the deployed DLL path, byte size and timestamp under
`E:\STEAM\steamapps\common\RimWorld\Mods\VerbalCommands`.

## Hard constraints

- Touch ONLY the two source files above plus whatever `build.ps1` regenerates. No refactors, no
  renames, no "while I was in there" fixes, no changes to `GroupHotkeyLayout.cs`, `Executor.cs`,
  `GroupRule.cs`, settings, XML defs or docs.
- Do NOT read, open, print or modify anything under the RimWorld Config folder
  (`%USERPROFILE%\AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\Config`). It contains
  the user's live API key. Nothing you need is in there.
- Every engine claim you add in a comment must cite a real path:line in
  `sources/RimWorldDecompiled`. Do not invent API members; check they exist first.
- If something in this brief does not compile or contradicts the source, stop and report it. Do
  not improvise a different design.
