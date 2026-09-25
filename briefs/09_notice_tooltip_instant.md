# Brief 09 — make the dev-mode notice's Close-button tooltip appear instantly

User test result (brief 08 deployed): the notice works, but the README tooltip on the Close button
takes too long to appear, so players close the dialog before they see it. It must appear right away.

## Cause (verified)

`src\VerbalCommands\Dialog_DevModeVoiceKeyNotice.cs:64` calls
`TooltipHandler.TipRegion(closeRect, "VerbalCommands_DevModeNotice_CloseTooltip".Translate())`.
That builds a `TipSignal` with the default `delay = 0.45f` (`Verse/TipSignal.cs:47`).
`TooltipHandler.DrawActiveTips` only draws a tip once
`Time.realtimeSinceStartup > firstTriggerTime + signal.delay` (`Verse/TooltipHandler.cs:121`).

## Change (exactly this, nothing else)

In `Dialog_DevModeVoiceKeyNotice.cs`, pass a zero-delay signal using the existing ctor
`TipSignal(string text, float delay)` (`Verse/TipSignal.cs:50-61`):

```csharp
TooltipHandler.TipRegion(closeRect, new TipSignal("VerbalCommands_DevModeNotice_CloseTooltip".Translate(), 0f));
```

Confirm the `.Translate()` result converts to `string` for that ctor (TaggedString → string implicit
conversion); if it doesn't compile as written, use `.Translate().Resolve()` (`Verse/TipSignal.cs:69`
shows `Resolve()` in use). Add a short comment citing `TipSignal.cs:47` and `TooltipHandler.cs:121`.
Do not change any other tooltip.

## Hard constraints

- Touch only `src\VerbalCommands\Dialog_DevModeVoiceKeyNotice.cs`.
- Compile only: `dotnet build src\VerbalCommands\VerbalCommands.csproj -c Release`. Do NOT run
  `build.ps1`, do NOT copy anything into `E:\STEAM\steamapps\common\RimWorld\Mods\VerbalCommands`.
- Never kill, stop or signal any process, including RimWorld.
- Do NOT read or touch the RimWorld Config folder
  (`%USERPROFILE%\AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\Config`).
- If it doesn't compile, stop and report.
- Report: the diff, build result, compiled DLL path/size/SHA256, explicit statement nothing was deployed.
