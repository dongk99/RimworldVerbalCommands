# Verbal Commands

Type a colony order in plain language (press Return in-game, or ~ for voice); Haiku turns it into short fixed sentences, the mod checks each one, shows what it will do, and on Apply makes the changes through RimWorld's own API. Questions ("who is unarmed", "show health of Bob") are answered from the game's data and change nothing.

Settings: Options > Mod settings > Verbal Commands.

This file is the map for an LLM working on the mod (so it does not have to scan every file). The human README is the GitHub repo root README. Updated 2026-10-03 (builds up to brief 30).

## Effort setting

`Effort` maps to the Anthropic Messages API field `output_config.effort`. Values: `low`, `medium`, `high`, `xhigh`, `max`.

- **Blank or `high`**: the field is not sent at all. Per the official docs, "Setting `effort` to `"high"` produces exactly the same behavior as omitting the `effort` parameter entirely."
- **Models without effort support** (for example `claude-haiku-4-5-20251001`, listed as "Not supported" in the model comparison table): if you set a non-high effort, the API returns HTTP 400 `invalid_request_error`. The mod catches that, resends the same request once without `output_config`, remembers the model for the rest of the session, and prints a line in the order window:

  `effort: this model does not accept the effort setting, so the request was sent again without it. Leave effort blank or 'high' for this model to skip the retry.` (`OrderController.cs:801`; the API's own message is kept but not printed.)

- Effort only applies to the main model (the older path, sentence router off). The router's Haiku call never sends it.
- Supported models (docs, 2026-09-02; this list is not in the code): `claude-fable-5-1`, `claude-mythos-5-1`, `claude-fable-5`, `claude-mythos-5`, `claude-mythos-preview`, `claude-opus-5`, `claude-opus-4-8`, `claude-opus-4-7`, `claude-opus-4-6`, `claude-opus-4-5-20251101`, `claude-sonnet-5`, `claude-sonnet-4-6`.

Currently, Medium/High setting is used on to test on Opus 5, 5.5 and Sonnet 5. Haiku 4.5 does not support this, and even with extended reasoning it does not fully do the task it was told to do (but it can do *some* of it accurately when attention goes to it). This likely means we can potentially make a rule where haiku can be used for certain stuff by only being shown small part of actual data instead of in its entirety.

## Headless mode

`Use Claude Code CLI` runs `claude -p` with your existing Claude Code login instead of an API key. Effort is passed to the CLI as `--effort` unchanged; the fallback above applies to API mode only. Expect claude -p to take longer for setup, a console account (or local llm after user testing) is recommended if user wants speed.

## Order routing (sentence router, on by default)

Setting "Use the sentence router" (`useScriptRouter = true`, `VerbalCommandsMod.cs:46`). The model picked in the Model setting is NOT called on this path; only the router model (Haiku) is.

1. `OrderController.Submit` (`OrderController.cs:161`) -> `SubmitScript` (`:313`) builds `RouterGame` + `RouterBridge` and runs `route(order)` in `Router\router.txt` (RouterScript language, interpreter in `RouterScript.dll`).
2. `route()` (`router.txt:~1074`) gets the VOCABULARY block (`vocabulary()` -> `VocabularyText.cs`: colonists, rooms, benches, groups, ...) and calls Haiku every time (`haiku()`, `router.txt:1090`) with `Router\haiku_prompt.md` as the system prompt.
3. Haiku answers with fixed sentences, one per line (the forms below), or `ASK: question` (the player answers, the order runs again with the answer) or `CANNOT: reason`.
4. `router.txt` reads each line into a form + slots and checks the slots against the vocabulary. An order is all questions or all changes; a mix is refused (`router.txt:364`).
5. Questions: `query(form, slots)` -> `FormPlanner.Query` -> `FormQueries.cs` / `FormWave1Queries.cs` / `FormGearQueries.cs`. The answer is shown; nothing changes.
6. Changes: `plan(form, slots)` -> `FormPlanner.Dispatch` -> one plan per line (`FormStorage`, `FormBills`, `FormControls`, `FormGroups`, `FormWave1`, `FormWave1Care`, `BuildTools`). With "Show parsed intent and ask before applying" on (default) the player sees the plan lines and clicks Apply or Cancel; then `Executor.ApplyAll` makes the changes.
7. Everything is written to the router log (see Logs).

This path has no regex shortcut and no escalation to Sonnet/Opus.

### Older path (sentence router off)

`Router.cs` + `ToolDefinitions.cs`: a regex match first (`Router.cs:227`); if the order is not covered, Haiku rewrites it (structured output); then the main model (Model + Effort settings) plans the whole order with tools. Kept in the code, not used by default. The user's original notes on it:

1 > regex rule looks at keyword matches first. if there are combinations that can be seen in sentences, step 2 is skipped and goes to 4
2 > haiku looks at the ~~garbage~~ prompt and replaces user's words with something that is regexable
3 > output of haiku's prompt goes into the tooling (into user) and makes apporporaite call.
4 > the actual model user selected on api console setting goes in and then does the shabam.
5 > the actual model makes arrangement.

### Router model

If you like to tweak around and see which model can do initial routing do best, you can put your own router model by changing content of `router_model.txt`:

`%USERPROFILE%\AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\router_model.txt`

Default `claude-haiku-4-5` (`Router.cs:194`). Older path: if the model name in that file doesn't work, the mod retries with `claude-haiku-4-5` and says so in the order window (`Router.cs:694-717`). Sentence router: reads the same file (`RouterGame.cs:109`) but has no retry; a bad name fails the order (logged as `haiku_reply` with `ok: false`).

## Order forms (what Haiku may write; `router.txt:198-361`)

Each line is one sentence; `[...]` is optional. Haiku must write these exactly; worked examples are in `Router\haiku_prompt.md`.

- Storage: `put only THINGS in PLACE.`, `put THINGS in PLACE.`, `keep THINGS out of PLACE.`, `set PLACE to PRIORITY priority.` (also with `those` = what an earlier line acted on)
- Build: `build option N.`, `build room like ROOM.`, `build [COUNT] BUILDING [made of STUFF] [near ANCHOR | DIRECTION of ANCHOR] [in ROOM].`
- Pawns: `assign PAWN to bed in ROOM.`, `keep PAWNS in ROOMS.`, `schedule PAWNS to ASSIGNMENT from FROM to TO.`, `set WORKTYPE priority N for PAWNS.`, `stop PAWNS doing WORKTYPE.`, `let only PAWNS do bills on BENCH.`, `draft PAWNS.`, `undraft PAWNS.`, `select PAWNS who have CONDITION.`, `move PAWNS to location NAME.`, `restrict PAWNS to area NAME.`, `set threat response of PAWNS to RESPONSE.`, `turn on/off fire at will for PAWNS.`
- Hotkey groups: `make weapon group NAME holding RULE.`, `clear weapon group SLOT.`
- Bills (`... at BENCH [in ROOM].`): `add bill to make RECIPE until you have COUNT / forever`, `add bill to make COUNT RECIPE`, `remove / pause / resume bill for RECIPE`, `pause / unpause bill for RECIPE when satisfied`, `let WHO / PAWN do bill for RECIPE`, `set skill range MIN to MAX on bill for RECIPE`, `set ingredient radius to N on bill for RECIPE`, `store bill products on WHERE for RECIPE`, `use only / allow / never use THINGS in bill for RECIPE`, `change bill for RECIPE to repeat until you have COUNT / forever / COUNT times`
- Buildings (`TARGETS [in ROOM].`): `switch on / switch off`, `open fire with / hold fire with`, `open / close` (vents), `set temperature of TARGETS to DEGREES.`, `turn on/off auto refuel for`, `set fuel level to N for`, `forbid / unforbid`; `hold door DOOR open.`, `let door DOOR close.`; `set every bed / COUNT bed in ROOM to medical / prisoner / colonist.`
- Groups (the game's policies): `assign PAWNS to clothing / food / drug / reading group NAME.`, `assign PAWNS to medicine group LEVEL.` (medical care), `put only / put THINGS in KIND group NAME.`, `keep THINGS out of KIND group NAME.`, `create / delete KIND group NAME.`, `rename KIND group NAME to NEW_NAME.`, `set FIELD of drug group NAME entry DRUG to VALUE.`
- Other: `set game speed to SPEED.`, `start research PROJECT.`, `set prisoner mode of PAWNS to MODE.`, `set master of ANIMALS to PAWN.`, `train / stop training ANIMALS in TRAINING.`, `queue operation RECIPE for PAWN [on PART].`, `cancel operation RECIPE for PAWN.`, `choose OPTION for letter LETTER.`
- Replies: `ASK: question`, `CANNOT: reason`

Questions (change nothing; `FormQueries.cs`, `FormWave1Queries.cs`, `FormGearQueries.cs`):
- `how much THINGS do i have.`, `is PAWN RELATION.`, `list relations of PAWN.`, `show groups of PAWN.`, `show KIND group NAME.`
- `show alerts.`, `show letters.`, `show research.`, `show weather.`, `show colonists.`, `show prisoners.`, `show animals.`, `show needs of PAWN.`, `show health of PAWN.`
- Gear (brief 30, free colonists only): `show gear of PAWN.`, `who wears / who does not wear THINGS.`, `who holds / who does not hold THINGS.`, `who carries / who does not carry THINGS.` (THINGS matched against every item def of that kind, not the vocabulary)

### Agent player forms (2026-10-03; none of them has been run in a live game yet)

For playing with no room on the map and no screen. The full list with one line each is the mod's own answer to `show questions.` / `show orders.` (table `HELP` in the router's shared rules). How to play through them: `agent_player\PLAYBOOK.md` in the source tree.

- Places (`AgentPlace.cs`): SPOT = `X, Z` | a colonist, prisoner, animal, `landmarks` or `zones` entry, room | `N tiles DIRECTION of NAME`; AREA = `X, Z to X, Z` | `W by H around SPOT`. Coordinates, distances and sizes the player never said are rejected. Nothing under fog is printed or accepted.
- Time and events (`AgentTime.cs`, `AgentEvents.cs`, `AgentFollow.cs`): `run HOURS hours / DAYS days / until event [at SPEED].`, `show speed.`, `show time.`, `show events [since day DAY].`, `show pending.`
- Map (`AgentMap.cs`, `AgentFind.cs`): `show [LAYER] map.`, `show [LAYER] map around SPOT.`, `show [LAYER] map of AREA.` (LAYER terrain, resources, buildings, roof, creatures), `where is NAME.`, `where is nearest THING [to SPOT].`, `where are THINGS.`, `list THINGS on map.`
- Colony reads (`AgentColonyReads*.cs`): `show status.`, `show threats.` (three or more hostiles standing together are told as one group), `show food.`, `show power.`, `show temperature [of ROOM].`, `show mood of PAWN.`
- Read-back (`AgentReadback*.cs`): `show work [of PAWN].`, `show skills of PAWN.`, `show schedule [of PAWN].`, `show area of PAWN.`, `show bed of PAWN.`, `show settings of PAWN.`, `show bills at BENCH [in ROOM | at SPOT].`, `show storage PLACE.`, `show storage of zone ZONE.`, `show building TARGETS [in ROOM | at SPOT].`, `show blueprints.`, `show research path to PROJECT.`
- Zones and areas (`AgentZones.cs`, `AgentAreas.cs`): `zone growing CROP in area AREA.`, `zone stockpile [for THINGS] in area AREA.`, `zone dumping in area AREA.`, `zone ZONE allow / stop WORK.`, `set crop of zone ZONE to CROP.`, `grow / shrink zone ZONE over AREA.`, `delete zone ZONE.`, `rename zone ZONE to NEW_NAME.`, `area NAME add / remove AREA.` (NAME home, roof, no roof, snow clear or an allowed area), `create area NAME over AREA.`, `delete area NAME.`, `show zones.`, `show areas.`; a stockpile zone is a storage PLACE: `put only THINGS in zone ZONE.`, `set zone ZONE to PRIORITY priority.`
- Designations (`AgentDesignations.cs`, `AgentDesignationQueries.cs`): `VERB THINGS.`, `VERB THINGS in area AREA.`, `VERB nearest [COUNT] THINGS near SPOT.`, `VERB THINGS near SPOT.` (VERB chop, cut, harvest, mine, deconstruct, uninstall, haul, hunt, tame, slaughter, strip, claim, smooth; at most 500 targets in an area order; a vein only as far as it is in view), `forbid / unforbid items [of THINGS] [in area AREA | near SPOT].`, `cancel all KIND.`, `cancel KIND in area AREA.`, `show designations.`, `show wildlife.`
- Building with no room (`AgentBuild.cs`, `AgentBuildShapes.cs`, `AgentRoomLayouts.cs`): `build BUILDING [made of STUFF] at SPOT [facing SIDE].`, `build [COUNT] BUILDING [made of STUFF] near SPOT [facing SIDE].`, `build BUILDING [made of STUFF] from AREA.` (a line), `build BUILDING anywhere.` (only a building tied to one kind of spot: a geothermal generator on the nearest free steam geyser), `build floor FLOOR in area AREA.`, `build room AREA [made of STUFF] [door SIDE].`, `dig room AREA ...` (into rock), `build bedroom / barracks / kitchen / dining room / research room AREA ... [with COUNT beds].` (furniture laid out by the game's placement rules), `cancel blueprint [BUILDING] at SPOT / in area AREA.` The player names every place; the mod picks none. Colonists roof a closed box themselves; the plan notes say when they will not.
- Colonists right now (`AgentTargets.cs`, `AgentPawnActions*.cs`): `move PAWNS to SPOT.`, `attack TARGET with PAWNS.` (TARGET from `hostiles` or `nearest enemy`), `rescue / tend / arrest PAWN [with DOER].`, `capture TARGET [with DOER].`, `extinguish fire [at SPOT] [with PAWNS].`, `prioritize WORK at SPOT [with DOER].`, `equip PAWN with WEAPON [at SPOT].`, `have PAWN wear APPAREL / pick up [COUNT] ITEM [at SPOT].`, `have PAWN drop ITEM.`, `have PAWN rest.`, `turn on / off self tend for PAWNS.`
- People who are not colonists, and trading (`AgentInteract.cs`): `show interactable pawns [for PAWN].` (traders, visitors, quest givers, prisoners, enemies in view, each with the game's right-click options), `use option OPTION on TARGET with PAWN.` (gives that right-click order; TARGET a name from the list or a cell), then, once the game's trade window is open (the colonist reached the trader): `show trade [for WORD].`, `trade buy / sell COUNT THING.`, `accept trade.`, `cancel trade.` The deal is the game's own `TradeDeal`; a run ends when the window opens.
- Power: `show power.` per net; an event line when a net's batteries fall below 90, 75, 50, 35, 20, 10% (`AgentEvents.cs`, each net by itself, no pause); `switch on / off TARGETS at SPOT.` names one building of a kind by its cell (one power switch), in `FormControls.cs`.
- `show gear of PAWN.` prints each worn piece's armor (sharp, blunt, heat), insulation (cold, heat), quality, hit points and whether a corpse wore it, and the pawn's comfortable temperature range.
- New VOCABULARY lines (`VocabularyText.cs`): `landmarks`, `hostiles` (always sent; `hostiles: none`), `zones`, `crops`, `floors`; `buildings` now lists what the build menu shows.
- Agent inbox (`AgentInbox.cs`; mod setting, off by default): text files in `<save data>\VerbalCommands\inbox\` are run as orders, results go to `outbox\<name>.json`, state to `inbox_state.json`. First line may be `mode: raw | dry | apply | wait`; `raw` = router sentences with no Haiku call (`route_raw` in `router.txt`). A file with only `apply` or `cancel` answers a waiting plan. The inbox pauses the game when it takes a file and never unpauses it. No network listener.
- Synonym rows (router shared rules, section 2): `retreat / pull back / fall back` = move, `put out / douse` = extinguish, `patch up / treat / heal` = tend, `shoot` = attack, `closest` = nearest, `map center` = map centre.

Adding a form: `router_lab\parse_results.txt` + `router_lab\haiku_prompt.md`, assembled into `mod\Router\` by `briefs\23_run\assemble_router.ps1`; check with `router_lab\check_router_sync.ps1` and the script tests (`RouterScript.Cli.exe test router_lab\script_tests`); the C# side goes in the matching `Form*.cs`.

## Settings (`VerbalCommandsMod.cs:9-46`, labels in `Languages\English\Keyed\VerbalCommands.xml`)

API key (paste from clipboard) or Claude Code CLI (+ path to claude.exe); Model (default `claude-sonnet-5`, older path only); Effort; Max output tokens (2048); Request timeout (60 s); Use the sentence router (on); Show parsed intent and ask before applying (on); Ask the LLM to explain faults (on); Log the player's answer / Haiku's raw reply / the planned changes in the game log (all on); Save router log (on); Extra system prompt text; group hotkey buttons; voice settings (see Voice input); Collect voice debug data (off).

## Logs

- Router log (on by default): `%USERPROFILE%\AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands\logs\router_<yyyy-MM-dd_HHmmss>.jsonl`, one file per game launch (`RouterLog.cs`). One JSON record per line (`session`, `order`, `haiku_sent`, `haiku_reply`, `route`, `answer`, ...), each with `order_id` and `turn`.
- Game log (Player.log): lines starting `[VerbalCommands]`.
- Transcripts (opt-in): see Voice input.

## Files

- `Router\router.txt` (the sentence router script), `Router\haiku_prompt.md` (Haiku's system prompt), `1.6\Assemblies\RouterScript.dll` (the interpreter; source `src\RouterScript`, rationale `src\RouterScript\notes\WHY.md`)
- Source `src\VerbalCommands\`: `OrderController` (one order: submit, route, confirm, apply), `RouterBridge` / `RouterGame` (script <-> game, Haiku call), `VocabularyText` (VOCABULARY block), `FormPlanner` (form -> plan or answer), `Form*.cs` (one file per form family), `Executor` (applies plans), `RouterLog`, `Router` / `ToolDefinitions` / `Snapshot` / `StorageIndex` (older path), `AnthropicClient` / `HeadlessClient` (API / `claude -p`), `BuildTools` / `Placement` / `PlanOptions` / `LayoutMemory` / `ExampleRooms` (building), `GroupRule` / `GroupHotkeyLayout` / `GameComponent_VerbalCommands` (hotkey groups), `Dialog_VerbalCommand` (order box), `SttEngine` / `VoiceDebugRecorder` / `TranscriptLogger` (voice).

## Pawn groups

Say something like "make weapon group 3 for everyone holding a rifle with range 25 or more; call it long guns" (router form `make weapon group {NAME} holding {RULE}.`, `router.txt:234`; only "weapon group" makes a hotkey group, a plain "group" means select, `router.txt:72, 233`) and the mod stores a RULE (weapon class, range, an explicit allow-list of weapon defNames, always-include/exclude pawns, and whether unarmed colonists count) in one of 9 hotkey slots. It does **not** store a fixed list of pawns.

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
