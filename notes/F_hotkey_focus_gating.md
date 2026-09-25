# F — Why a RimWorld mod hotkey "needs a game restart" (focus gating)

Written 2026-09-05, from the Verbal Commands group-hotkey bug. Everything below is cited to
`sources/RimWorldDecompiled` (RimWorld 1.6). Where something is inference rather than a line of
source, it says so.

## The symptom class

A mod binds a key at runtime. The player is told the binding was applied. The key does nothing.
Restart the game and the same key works. The natural conclusion — "RimWorld needs a restart for
keybindings, like some settings do" — is wrong, and chasing it wastes the debugging session.

## Fact 1: RimWorld keybindings are live. There is no restart requirement.

- `KeyBindingData` is a **class**, not a struct (`Verse/KeyBindingData.cs:5`). So
  `KeyPrefs.KeyPrefsData.keyPrefs.TryGetValue(def, out data); data.keyBindingA = code;` mutates the
  object the dictionary holds. No write-back needed.
- Every input accessor re-reads the dictionary on each call —
  `KeyBindingDef.KeyDownEvent` (`Verse/KeyBindingDef.cs:47`), `IsDownEvent` (`:75`),
  `JustPressed` (`:111`), `IsDown` (`:131`), `MainKey` (`:26`). Nothing is cached at load.
- `KeyPrefs.Save()` (`Verse/KeyPrefs.cs:62-91`) only serialises to `Config/KeyPrefs.xml`; it does
  not participate in reading.

So if a mod's rebinding "only works after a restart", the restart is not applying the binding —
the binding was already applied. The restart is clearing some other piece of session state.

### Corollary: the one way a rebind really is lost

`Dialog_KeyBindings` (Options → Keyboard configuration) clones the whole prefs object on
construction (`RimWorld/Dialog_KeyBindings.cs:33`) and, on OK, assigns the clone back over the
live one (`:100`): `KeyPrefs.KeyPrefsData = keyPrefsData;`. Any binding a mod made **while that
dialog was open** is discarded when the player clicks OK — but `KeyPrefs.Save()` may already have
written it to disk, so it reappears on next launch. That produces the same "works only after
restart" story with a completely different cause. Rule out both.

## Fact 2: `GUIUtility.keyboardControl` is a latch, not a state

This is the trap. A common gate in mod `OnGUI` code:

```csharp
if (GUIUtility.keyboardControl != 0) return;   // "don't fire while the player is typing"
```

Unity sets `keyboardControl` to the control id of the focused control. **Nothing resets it when
that control stops being drawn.** Closing the window that owned the text field leaves the id in
place; reopening the window does not clear it either. In the whole decompiled codebase it is
assigned back to 0 in exactly one place — `Widgets.ButtonInvisibleDraggable` on mouse-down
(`Verse/Widgets.cs:1730`) — and cleared indirectly via `UI.UnfocusCurrentControl()`
(`Verse/UI.cs:56-59`, which is `GUI.FocusControl(null)`).

Callers of `UI.UnfocusCurrentControl()` in vanilla (grep, 1.6):

| Call site | When it fires |
|---|---|
| `RimWorld/MainTabWindow_Architect.cs:184` | first draw after each Architect tab open (`PreOpen` resets `didInitialUnfocus`, `:56-60`) |
| `RimWorld/QuickSearchWidget.cs:91` | `Unfocus()`, and only if *that widget* is the focused control |
| `LudeonTK/Dialog_OptionLister.cs:113`, `EditWindow_DefEditor.cs:52`, `EditWindow_Log.cs:81` | dev-mode windows |

And `Widgets.ButtonInvisibleDraggable` is used in only two vanilla spots
(`RimWorld/MedicalCareUtility.cs:42`, `RimWorld/Dialog_EditIdeoStyleItems.cs:457`).

Net effect: once a mod's own text field takes focus, a `keyboardControl != 0` gate stays closed for
the rest of the process, unless the player happens to open the Architect tab. That is why a game
restart "fixes" it — process exit is what resets the flag. (The persistence itself is inference
from the absence of any reset path plus the observed restart-only recovery; the reset paths above
are direct source reads.)

**Two mods can also poison each other.** The flag is global. Mod A leaves focus set; Mod B's
unrelated `keyboardControl` gate goes dead. Neither author can reproduce it alone.

### Fixes

1. **Never gate on `keyboardControl`.** Use derived state that is recomputed per call:
   - `Find.WindowStack.NonImmediateDialogWindowOpen` (`Verse/WindowStack.cs:110`) — is any
     non-immediate `WindowLayer.Dialog` window open right now.
   - `Find.WindowStack.AnySearchWidgetFocused` (`:155`) — asks each window's `CommonSearchWidget`
     whether it is focused, so it self-clears.
   - `Find.WindowStack.WindowsForcePause` (`:45`), `AnyWindowAbsorbingAllInput` (`:140`),
     `IsOpen<T>()` (`:295`) are all recomputed the same way.
2. **Unfocus when your window closes.** `Window.PostClose()` is `public virtual`
   (`Verse/Window.cs:179`); override it and call `UI.UnfocusCurrentControl()`. Cheap, and it stops
   you poisoning everyone else's gate.

## Fact 3: `GameComponentOnGUI` sees input before the window stack — use that instead of gating

Ordering inside one OnGUI pass, for a mod's `GameComponent.GameComponentOnGUI`:

```
UIRoot_Play.UIRootOnGUI()                        RimWorld/UIRoot_Play.cs:24
  base.UIRootOnGUI()                             :26   -> Verse/UIRoot.cs:38
    windows.HandleEventsHighPriority()           Verse/UIRoot.cs:52
    GameComponentUtility.GameComponentOnGUI()    Verse/UIRoot.cs:66   <-- your mod
  mainButtonsRoot.MainButtonsOnGUI()             UIRoot_Play.cs:32    <-- main tab hotkeys (F1-F9)
  windows.WindowStackOnGUI()                     UIRoot_Play.cs:43    <-- text fields
  mainButtonsRoot.HandleLowPriorityShortcuts()   UIRoot_Play.cs:53
```

So a `GameComponent` handler that calls `Event.current.Use()` consumes the key **before** any
`Widgets.TextArea`/`TextField` and **before** the main-tab hotkeys. Consequences worth knowing:

- You do not need a focus gate at all for keys that can never be typed as characters — F1–F15,
  arrows, Insert/Home/End/PageUp/PageDown. The text field never receives the event.
- You only need a gate for **printing** keys (letters, digits, punctuation, keypad digits), and
  only to avoid eating a character the player meant to type.
- Gating on the *bound keycode* is therefore more precise than gating on focus, and it stays
  correct when the player rebinds to something you did not anticipate.

`UnityEngine.KeyCode` is ordered so `Space`(32)..`Tilde`(126) is printable ASCII and
`Keypad0`(256)..`KeypadEquals`(272) is the keypad; function keys start at `F1`(282).

Two easy off-by-a-few mistakes when you write that range test, both verified against the shipped
`RimWorldWin64_Data/Managed/UnityEngine.CoreModule.dll` (the RimWorld decompile does **not**
contain `KeyCode` — it is Unity's enum, so check the assembly, not `sources/`):

- Stopping at `Z`(122) looks natural and is wrong: `LeftCurlyBracket`(123), `Pipe`(124),
  `RightCurlyBracket`(125) and `Tilde`(126) are character keys too. Stop at `Tilde`.
- `Delete`(127) is *outside* the printable range and belongs outside it — it edits text but
  inserts no character, so consuming it as a hotkey is fine.
- Inside the keypad range, `KeypadEnter`(271) is the one non-character member; exclude it
  explicitly.

## Fact 4: key listeners do not arbitrate, so ordering is the only arbitration

`KeyBindingDef.KeyDownEvent` (`Verse/KeyBindingDef.cs:43-66`) is just a comparison against
`Event.current.keyCode`. Two defs bound to the same key both return true; whoever is polled first
and calls `Event.current.Use()` wins. The conflict machinery is separate and only advisory:
`KeyPrefsData.ConflictingBindings` is category-based (`Verse/KeyPrefsData.cs:65-74`) and
`ErrorCheckOn` auto-fixes **only** bindings that differ from their XML default (`:122-146`) — a
mod def whose `defaultKeyCodeA` is the conflicting key is left alone and merely logged.

Practical consequence: a mod def that ships with `defaultKeyCodeA` set to a key vanilla already
uses creates a permanent silent conflict. Ship `None` and bind at runtime with consent.

## Fact 5: F1–F9 are not free, and an XML scan will tell you they are

The main tab shortcuts are **generated**, not authored: `KeyBindingDefGenerator` builds
`MainTab_<defName>` KeyBindingDefs from each `MainButtonDef.defaultHotKey`
(`Verse/KeyBindingDefGenerator.cs:35-42`). Grepping `Defs/KeyBindingDefs/*.xml` finds nothing and
you will conclude F1–F9 are unused. They are Work/Schedule/Assign/Animals/Wildlife/Research/
Quests/World/History. Number row 1–4 is game speed; 5–9 and 0 are free in vanilla.

## Checklist for "my mod's hotkey needs a restart"

1. Confirm the binding actually landed: `Config/KeyPrefs.xml` and your own `Log.Message` in the
   apply path. If it landed, stop blaming the binding.
2. Was `Dialog_KeyBindings` open when you bound it? (`Dialog_KeyBindings.cs:33`/`:100`.)
3. Grep your own code for `keyboardControl`. If it gates anything, that is almost certainly it.
4. Check whether your handler even needs a gate given it runs at `Verse/UIRoot.cs:66`.
5. Check whether the key is silently owned by a generated `MainTab_*` def.
