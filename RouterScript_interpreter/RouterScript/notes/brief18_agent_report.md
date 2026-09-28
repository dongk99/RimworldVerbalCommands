# Brief 18 agent's own report (verbatim)

Copied unedited from the agent transcript `agent-a961d4157ae2c320f.jsonl` (session 83ddf995, 2026-09-28T05:19:02.502Z). This is what the Opus agent that built the code reported, including the choices it made where the brief was silent. These choices are the AGENT'S, not the user's.

---

## Brief 18 report: locations and directions in the router language

**One step is not done: the Haiku test of the prompt.** You asked me to run `powershell -ExecutionPolicy Bypass -File router_lab\run.ps1`. The auto-mode classifier refused it ("Safety Bypass Flag"). Your request came from an agent, not from the user, so I did not try to get around the refusal. Five direction orders in plain player wording are now at the end of `router_lab\examples.txt`, and the prompt is ready. Nothing has tested `haiku_prompt.md` yet. For the user to run:
1. `powershell -ExecutionPolicy Bypass -File router_lab\run.ps1`
2. `RouterScript.Cli run router_lab\parse_results.txt router_lab\results\<new>.md`

The run includes the 7 old orders too.

**Build and tests:** `dotnet build -c Release` of `src\RouterScript` and `src\RouterScript.Cli` both give 0 errors and 0 warnings. Tests went from 94 to 102, all passing (102 passed, 0 failed). I did not run build.ps1, copy anything to Mods, launch the game, stop any process, open the Config folder, touch `src\VerbalCommands` or write `router.txt`. Copies of the files from before my edits are in `briefs\18_before\`.

### What was added
1. **Lists, dicts and calls over several lines** (`src\RouterScript\Lexer.cs:52,108-240`)
   - A `[`, `{` or `(` left open carries on to the next lines until it closes. Indentation inside is ignored, and blank and comment lines inside are skipped.
   - The joined lines count as one line: errors give its first line number.
   - Continuation stops at a line that starts with a statement word (if, for, return, …) or contains a single `=`. Without that stop, a missing `]` would swallow the rest of the file. It also keeps the old one-line error messages, so `err_syntax` is unchanged.
   - A line that ends in `[`, `{`, `(` or `,` and never closes gets a new message: `line N: the '[' on this line is never closed; add its ']' after the last item.`
   - A comma after the last item of a list or dict is now allowed (`Parser.cs:584`).
   - `NUMBER_WORDS` in `parse_results.txt:124` is now one dict written over several lines.
   - Tests: `multiline_literals`, `err_multiline_unclosed`.
2. **Lab map** (`router_lab\map.txt`)
   - The map has walls, doors, floor and things (a legend of shelf, bed, bench, table, lamp), and a digit in the grid names the room it sits in. Rooms are found by flood fill; doors belong to neither room; open ground touching the map's edge is outdoors.
   - The file's header comments explain each hard case:
     - a U-shaped storeroom of shelves wrapped around Alice's and Bob's bedrooms;
     - a 1-wide cross corridor with no name, with doors to the dining room, workshop, rec room and outdoors;
     - a freezer nested inside an unnamed airlock ring, so neither of its doors leads to a named room;
     - a vault with no doors.
3. **Host read functions** (`src\RouterScript.Cli\LabMap.cs`, and `--map <file>` in `Program.cs:23-27,213`). Three functions:
   - `rooms()` gives `[{"id", "name"}]`; name is none for a room with no name.
   - `things_in(room_id)` gives `[{"id", "kind", "x", "z"}]`. Positions come with each thing, so I left out `position()`.
   - `doors_of(room_id)` gives `[{"x", "z", "to"}]`; `to` is the named room on the other side, or none when that side is outdoors or has no name.
   - A bad room id gives `line N: 'things_in' needs a room's id from rooms(); there is no room 99.`
   - Map file mistakes name the file and its line: `map_bad_letter.map line 9: 'X' is not in the legend.`
   - I also added `--script <file>` for test mode, so a test can run a lab script against a `.input` file.
   - Tests: `map_host`, `err_map_room`, `err_map_room_text`, `err_map_file`.
4. **The location rule, written in the language** (`router_lab\locations.txt`; template at line 26, reference at 109, fill at 143, parse at 178)
   - The sentence form is `{KIND} is {DISTANCE} {UNIT} {DIRECTION} of {REFERENCE}[ in {ROOM}].` A room with no name is left out of the sentence.
   - Reference order:
     - the nearest door to a named room;
     - if there is none, the center of all the room's doors ("center of doors");
     - if there are no doors, the kind with the fewest copies, not counting the thing itself (ties go alphabetical, then the nearest copy).
   - Distance counts a diagonal step as one tile (the larger of the two offsets). There are 8 directions: a corner is used when the sideways offset is at least half the main one.
   - Parsing back finds every thing of that kind in that room at that direction and distance. Result: **81 things, 41 read back exactly, 40 as part of a group, 0 wrong.**
   - Test: `locations_map`, which runs `locations.txt` on `map.txt`.
5. **Parser forms**
   - `parse_results.txt` has a `PLACES` list at line 13, and each storage form is tried with each PLACE:
     - `storage {DISTANCE} {UNIT} {DIRECTION} of door to {DOOR}[ in {ROOM}]`
     - `storage {DIRECTION} of door to {DOOR}[ in {ROOM}]`
     - the old near/in form.
   - The direction words table is at line 54, and the made-up number check now covers DISTANCE (line 161).
   - `haiku_prompt.md` gained the PLACE direction form, a DIRECTION slot line, "or distance" in the NUMBERS rule, one GOOD example and one BAD example (a made-up "3 tiles").
   - I also added a `doors:` line to `vocabulary.txt`, which the brief did not ask for.
   - Test: `parse_directions`. Its lines are hand-written, so it tests the parser only, not the prompt.
     - "3 tiles left of the door to kitchen" becomes west with DISTANCE 3.
     - "top right" and "north-east" become northeast.
     - An unsaid "2 tiles" or "1 tile" is rejected as made up.
     - "sideways" is refused.
     - The old results file gives exactly the same output as before.

**Tie rule:** at equal distance, the door whose room name comes first in the alphabet wins. The lamp at the corridor crossing is 6 tiles from three named doors, so it becomes "south of door to dining room".

### Hard-case sentences (unedited output)
```
storeroom
  shelf at 1,29: shelf is 11 tiles north of door to dining room in storeroom.  (group of 7)   [same for 2..7,29]
  shelf at 8,29: shelf is 11 tiles northeast of door to dining room in storeroom.  (group of 4)
  lamp at 11,29: lamp is 9 tiles northwest of door to kitchen in storeroom.
  shelf at 15,29: shelf is 5 tiles northwest of door to kitchen in storeroom.  (group of 3)
  shelf at 18,29: shelf is 5 tiles north of door to kitchen in storeroom.  (group of 2)
  shelf at 7,27: shelf is 9 tiles northeast of door to dining room in storeroom.  (group of 5)
  shelf at 12,27: shelf is 8 tiles west of door to kitchen in storeroom.
  shelf at 1,25: shelf is 7 tiles north of door to dining room in storeroom.
  shelf at 16,25: shelf is 4 tiles west of door to kitchen in storeroom.  (group of 3)
  shelf at 16,22: shelf is 4 tiles southwest of door to kitchen in storeroom.  (group of 3)
  shelf at 1,19: shelf is 1 tile northwest of door to dining room in storeroom.
(room with no name)   [cross corridor]
  lamp at 15,10: lamp is 2 tiles south of door to dining room.
  lamp at 12,6: lamp is 3 tiles east of door to workshop.
  lamp at 15,6: lamp is 6 tiles south of door to dining room.        [the crossing, tie]
(room with no name)   [airlock ring]
  lamp at 42,21: lamp is 5 tiles east of door to freezer.
freezer
  shelf at 35,27: shelf is 2 tiles northwest of center of doors in freezer.  (group of 2)
  shelf at 35,25: shelf is 2 tiles west of center of doors in freezer.
  shelf at 39,23: shelf is 2 tiles southeast of center of doors in freezer.  (group of 2)
vault
  shelf at 17,11: shelf is 3 tiles northwest of lamp in vault.
  shelf at 19,11: shelf is 3 tiles north of lamp in vault.  (group of 2)
  table at 17,8: table is 3 tiles west of lamp in vault.
  lamp at 20,8: lamp is 3 tiles east of table in vault.
```

### Game API for "the room on the other side of a door" (not built)
- A door is its own doorway region: `Region.door` / `IsDoorway` (`Verse/Region.cs:26,254`).
- Get it with `door.GetRegion(RegionType.Set_All)` (`Verse/RegionAndRoomQuery.cs:19`).
- Then each `region.links[i].GetOtherRegion(region)` (`Verse/RegionLink.cs:75`), or `region.Neighbors` (`Verse/Region.cs:123`), and `.Room` on the result.
- The game walks from a doorway to the rooms beside it the same way in `Verse/Room.cs:651-659`. `Room.IsDoorway` / `Room.Door` are at `Verse/Room.cs:457-477`.
- In the mod, "named" should use the same `IsGenericRoomRole` test as 15c.

### What came out badly, and what I would change in the decisions
- **Straight-line distance through walls.** Nearest door and distance ignore walls. In the U storeroom, the shelves on the top-left band are measured from the dining-room door straight through the bedroom walls, which gives "11 tiles north", a group of 7. It reads acceptably as "the top-left run of shelves", but it is not walking distance. If the user wants "nearest" to mean along the floor, the fix is a walking-distance measure inside the room; that is still not shape detection.
- **Groups are common.** 40 of 81 things read back as a group rather than exactly. If exact references matter (for instance to change a single shelf), the choice is a second offset ("3 tiles west and 1 tile north") or letting the group stand for the target. I would ask the user which.
- **Rooms with no name are left out of the sentence.** When two unnamed rooms both have a "door to X", a sentence can be ambiguous between them. It didn't happen on this map. The fallback would be the user's "hallway between A and B" wording.
- **The prompt needs doors in the vocabulary.** The prompt now refers to a `doors:` line in the vocabulary. The mod would need to supply that line for real.