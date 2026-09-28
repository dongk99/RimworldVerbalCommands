# LabMap.cs, line by line

File: `src\RouterScript.Cli\LabMap.cs` (396 lines). Source tags: see `..\..\RouterScript\README.md`.

**What this file is:** a pretend colony for the router lab. It reads an ASCII map (`router_lab\map.txt`)
and gives scripts three read functions — `rooms()`, `things_in(room)`, `doors_of(room)` — shaped like
the ones the mod will later provide from the real game (B18:21-25: "Names and results are what the mod
will later provide for real, so keep them few and plain"). It exists so the location rule
(`router_lab\locations.txt`) can be written and tested in the language without the game (B18:26-36).
It is lab-only: it lives in the CLI, not in `src\RouterScript`, and never ships.

**Who wrote what:** the brief 18 Opus agent wrote it (2026-09-28; its report:
`..\..\RouterScript\notes\brief18_agent_report.md`). Later the same day I (the coordinating Opus
session) changed it for handoff §3b (room names from furniture; the user's message 2026-09-28T05:48:08Z,
quoted whole in WHY.md D10): rooms lost their names, things gained a `role`, `names:` became `owners:`,
and a door's `to` became the other room's **id**. Lines changed then (per `git diff --no-index` against
`briefs\18b_before\LabMap.cs`): 11-17, 19-29, 38, 47, 83-84, 106, 113, 122, 125-130, 137, 140, 154,
165, 185, 187, 252, 254-262, 270-271, 318-326, 344, 363, 368-371, 378. So the brief 18 report's
description of `rooms()` returning `{"id","name"}` is out of date.

## L1-6: usings, namespace.

## L8-32: the header comment (the contract)
- L8-9: a colony drawn in ASCII, and the read functions the mod will later provide.
- L11-12 `rooms()` → `[{"id": 1, "owners": []}, ...]`: every room (not outdoors), with the owners of its
  beds.
- L13-15 `things_in(room)` → `[{"id", "kind", "role", "x", "z"}]`: `room` is a room id; `role` is the
  room role the thing counts for (major furniture), none for minor things (lamps, chairs, desks).
- L16-17 `doors_of(room)` → `[{"x", "z", "to"}]`: `to` is the id of the room on the door's other side,
  none for outdoors.
- L19-22: **rooms have no names here: the script names every room from its furniture** (brief 16 Step
  I). In the mod, `role` will be the label of the room role whose worker scores that building
  (`RoomRoleWorker.GetScoreDeltaIfBuildingPlaced > 0`, e.g. `RimWorld/RoomRoleWorker_Tomb.cs:22-28`), and
  owners come from the room's beds (`Verse/Room.cs:885-895`). Why no names from the host: the user
  decided every room is force-named from what is in it, eat tables are major ("dining room"), and
  desks/chairs are not (D10: messages 2026-09-28T05:38:46Z and 05:48:08Z, quoted whole in
  `..\..\RouterScript\notes\WHY.md`).
- L24-27: the map file format: `legend:` lines (`S shelf: storeroom` = major furniture with its role;
  `L lamp` = minor), `owners:` lines (`2 Alice` / `3 Bob, Dana`: owners of the beds in the room marked
  with that digit), then `map:` and the grid. In the grid: `#` wall, `+` door, `.` floor, ` ` outdoors, a
  digit = floor that marks its room for `owners:`, a legend letter = one thing on floor.
- L27-29: x is the column (east is +x), z counts rows **up from the bottom** (north is +z), "as in the
  game (`Verse/Rot4.cs:155-158` FacingCell: North (0,0,1), East (1,0,0))". Why: directions in sentences
  must match the game's (user's direction words, D10; B18:27-28).
- L31-32: rooms are found by flood fill "the way the game does it": walls and doors split rooms, and a
  door belongs to neither side; a space touching the map's edge or containing ` ` is outdoors. Why:
  B18:19-20; a door is its own doorway region in the game (`Verse/Region.cs:26,254`, R18).

## L33-62: the model
- L35-41 `Room`: id, owners (null when no digit marks it), whether it is outdoors, its cells.
- L43-51 `Thing`: id, kind (legend word), role (null = minor, comment L47), x, z, its room (null when
  outdoors).
- L53-58 `Door`: x, z, and the rooms touching it (comment L57: a null entry = off the map = outdoors).
- L60-62: every room, thing and door.

## L64-66: private constructor (only `Load` makes maps).

## L68-163: `Load(path, out problem)`
- Comment L68: returns null and a plain problem when the file can't be used.
- L71-80: reads the file (UTF-8); can't → `cannot read the map file ...`.
- L82-88: legend (letter → kind), roles (letter → role), owners (digit → names), the grid lines, the
  current section, the file name for messages, and the file line where the grid starts.
- L89-100: once in the `map:` section, every remaining line (even blank ones) is a grid row.
- L101-105: before the grid, blank lines and `#` comments are skipped.
- L106-110: `legend:`, `owners:`, `map:` switch sections.
- L111-115: any other line must look like `S shelf: storeroom` (a key character, a space, a word) →
  otherwise `map.txt line 3: expected "legend:", "owners:", "map:" or a line like "S shelf: storeroom".`
- L116-132 legend line: the key must be a letter (L120-124); `word: role` splits into kind and role
  (L125-130); a word with no colon is a minor thing (no role).
- L133-141 owners line: the key must be a digit (`an owners line starts with its room's digit, like "2
  Alice".`); the rest is the owner list text.
- L143-146: empty rows at the end of the grid are dropped.
- L147-151: no grid → `map.txt: the map has no "map:" section.`
- L153-162: builds the map; a build problem starts with the grid row number, which is turned into the
  file's line number (comment L157-158), e.g. `map_bad_letter.map line 9: 'X' is not in the legend.`
  (test `err_map_file`).

## L165-300: `Build(grid, legend, roles, owners)`
- L167-172: height = rows, width = the longest row.
- L173-191: the grid into `cells[x, z]` with z counted from the bottom (L177: `z = height - 1 - r`).
  Short rows are padded with outdoors (L180). Unknown characters → `'X' is not in the legend.`; a digit
  with no `owners:` line → `the digit N has no line under "owners:".` (L185-188).
- L193-236 **flood fill** (comment L193): every open cell (not wall, not door) is grouped with its open
  neighbours north/south/east/west (L195) into one area. L214-217: an area touching the map's edge, or
  containing a ` ` cell, is outdoors. L230-234: only indoor areas become rooms, numbered 1, 2, ... in
  reading order of their first cell (top row first).
- L238-298 **owners, things and doors**, in reading order (comment L238):
  - L246-264 a digit: must be in a room (`the digit N is outdoors, not in a room.`), and one digit per
    room (`one room is marked twice; use one digit per room.`); the room's owners are the names after
    the digit, split on commas.
  - L265-276 a legend letter: a new thing with the next id, its kind, its role (or none), position, and
    its room (none when outdoors).
  - L277-296 a door: its sides are the areas north/south/east/west of it (L282-294); off the map counts
    as a null (outdoors) side (L286-289); each area counted once (L290).
- L299: no problem.

## L302-305: `Open(c)`: anything but a wall or a door is open (floor, digits, things, outdoors).

## L307-383: the host functions (`Register(host)`)
- L311-330 **`rooms()`**: for each room, `{"id": n, "owners": [...]}` (owners empty when unmarked).
- L331-350 **`things_in(room_id)`**: every thing in that room: `{"id", "kind", "role", "x", "z"}`; role
  is none for minor things (`Value.FromText(null)` → none).
- L351-382 **`doors_of(room_id)`**: every door touching that room: `{"x", "z", "to"}`. L361-374: `to` is
  the first side that isn't this room: its id if it is an indoor room, none if it is outdoors (comment
  L361-362: a door between a room and itself has no other side → none).
- Why these three and no `position()`: positions come with each thing (R18: "Positions come with each
  thing, so I left out `position()`").

## L385-393: `FindRoom(v, function)`
- The value must be a whole number from 1 to the room count; otherwise → `'things_in' needs a room's id
  from rooms(); there is no room 99.` (tests `err_map_room`, `err_map_room_text`).
