# Brief 01 — scaffold: About.xml, Defs, Languages, csproj, build.ps1

Project root: `C:\Users\[user]\.claude\projects\RimWorld-LLM-Integration`
Read `PLAN.md` sections 1, 2, 5 first. Do not write any C# source files; brief 02 owns `src\VerbalCommands\*.cs`.

## Files to create

### 1. `mod\About\About.xml`
```xml
<?xml version="1.0" encoding="utf-8"?>
<ModMetaData>
  <name>Verbal Commands</name>
  <author>kopaz</author>
  <packageId>kopaz.verbalcommands</packageId>
  <supportedVersions>
    <li>1.6</li>
  </supportedVersions>
  <description>Type a colony order in plain language; an LLM (Anthropic Messages API) turns it into schedule, allowed-area and work-priority changes, which the mod applies through the game's own API. Requires your own Anthropic API key (Options > Mod settings).</description>
</ModMetaData>
```
No `modDependencies` (no Harmony). Compare the element names against `sources\RimTalk\About\About.xml` and `sources\Rimworld_AI_Framework\RimAI.Framework\About\About.xml` and keep only elements that appear there.

### 2. `mod\Defs\KeyBindingDefs\VerbalCommands_KeyBindings.xml`
```xml
<?xml version="1.0" encoding="utf-8"?>
<Defs>
  <KeyBindingDef>
    <defName>VerbalCommands_Open</defName>
    <label>open verbal commands</label>
    <category>Game</category>
    <defaultKeyCodeA>Return</defaultKeyCodeA>
  </KeyBindingDef>
</Defs>
```
Facts: `KeyBindingDef` fields `category`, `defaultKeyCodeA` (`sources\RimWorldDecompiled\Verse\KeyBindingDef.cs:9-11`); category `Game` exists (`E:\STEAM\steamapps\common\RimWorld\Data\Core\Defs\Misc\KeyBindings\KeyBindings.xml:53-55`, vanilla `Accept` uses it and `Return`).

### 3. `mod\Languages\English\Keyed\VerbalCommands.xml`
`<LanguageData>` with these keys (values are English UI strings):
`VerbalCommands_WindowTitle` = "Verbal Commands", `VerbalCommands_Send` = "Send", `VerbalCommands_Apply` = "Apply", `VerbalCommands_Cancel` = "Cancel", `VerbalCommands_Close` = "Close", `VerbalCommands_Placeholder` = "Type an order for the colony…", `VerbalCommands_NoApiKey` = "No API key set. Options > Mod settings > Verbal Commands.", `VerbalCommands_Settings_ApiKey` = "Anthropic API key", `VerbalCommands_Settings_Model` = "Model", `VerbalCommands_Settings_Effort` = "Effort (low/medium/high/xhigh/max)", `VerbalCommands_Settings_MaxTokens` = "Max output tokens", `VerbalCommands_Settings_Timeout` = "Request timeout (seconds)", `VerbalCommands_Settings_Confirm` = "Show parsed intent and ask before applying", `VerbalCommands_Settings_ExplainErrors` = "Ask the LLM to explain faults (one extra request)", `VerbalCommands_Settings_Extra` = "Extra system prompt text".

### 4. `src\VerbalCommands\VerbalCommands.csproj`
SDK-style, `net472`, `LangVersion` latest usable by the installed SDK, `Nullable` disabled, `AssemblyName` `VerbalCommands`, `RootNamespace` `VerbalCommands`, `AppendTargetFrameworkToOutputPath` false, `OutputPath` `..\..\mod\1.6\Assemblies\`, `CopyLocalLockFileAssemblies` true, `DebugType` none (or portable; no `.pdb` shipped). `PackageReference` `Newtonsoft.Json` `13.0.3`.
References with `HintPath` into `E:\STEAM\steamapps\common\RimWorld\RimWorldWin64_Data\Managed\` and `<Private>false</Private>` (never copy game DLLs into the mod): `Assembly-CSharp.dll`, `UnityEngine.dll`, `UnityEngine.CoreModule.dll`, `UnityEngine.IMGUIModule.dll`, `UnityEngine.TextRenderingModule.dll`, `UnityEngine.InputLegacyModule.dll`, `System.Net.Http.dll` (the game ships it; verify each file exists with `ls`).
Post-build target: after build, if `mod\1.6\Assemblies\Newtonsoft.Json.dll` exists, move it to `mod\1.6\Assemblies\000_Newtonsoft.Json.dll`. Reason: the game loads `Assemblies/*.dll` in file order (`sources\RimWorldDecompiled\Verse\ModAssemblyHandler.cs:31`); RimAI Framework does the same rename (`sources\Rimworld_AI_Framework\RimAI.Framework\RimAI.Framework.csproj:84-87`, read it). Also delete any other copied dependency DLLs that are not `VerbalCommands.dll` or `000_Newtonsoft.Json.dll` (e.g. `System.*.dll` pulled by the package) so only those two ship.

### 5. `build.ps1` (Windows PowerShell 5.1 compatible — no `&&`, no ternaries)
Steps, each printing what it does and stopping on failure:
1. `dotnet build "$PSScriptRoot\src\VerbalCommands\VerbalCommands.csproj" -c Release` and fail if exit code non-zero.
2. Verify `mod\1.6\Assemblies\VerbalCommands.dll` and `mod\1.6\Assemblies\000_Newtonsoft.Json.dll` exist.
3. Mirror `mod\` to `E:\STEAM\steamapps\common\RimWorld\Mods\VerbalCommands` using `robocopy /MIR` (robocopy exit codes 0–7 are success). Only that folder is ever touched.
4. Print the final tree of the Mods folder.

## Rules
- Do NOT run `dotnet build` yourself if it would take longer than 3 minutes; you may run `dotnet restore` to confirm the package resolves.
- Quote nothing you did not read. Where this brief says "verify", run the check and state the result.
- Finish by listing every file you created with its path and line count.
