using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace VerbalCommands.RouterScript.Cli
{
	// Brief 18: a colony drawn in ASCII for the router lab (`--map router_lab\map.txt`), and the read
	// functions the mod will later provide from the real game:
	//
	//   rooms()          -> [{"id": 1, "owners": []}, {"id": 2, "owners": ["Alice"]}, ...]
	//                       every room on the map (not outdoors), with the owners of its beds
	//   things_in(room)  -> [{"id": 7, "kind": "shelf", "role": "storeroom", "x": 3, "z": 28}, ...]
	//                       room = a room's id; role = the room role this thing counts for (major
	//                       furniture), none for minor things (lamps, chairs, desks)
	//   doors_of(room)   -> [{"x": 2, "z": 19, "to": 5}, ...]
	//                       "to" is the id of the room on the door's other side, none for outdoors
	//
	// Rooms have no names here: the script names every room from its furniture (brief 16 Step I). In
	// the mod, "role" will be the label of the room role whose worker scores that building
	// (RoomRoleWorker.GetScoreDeltaIfBuildingPlaced > 0, e.g. RimWorld/RoomRoleWorker_Tomb.cs:22-28),
	// and owners come from the room's beds (Verse/Room.cs:885-895).
	//
	// Map file: "legend:" lines ("S shelf: storeroom" for major furniture, "L lamp" for minor),
	// "owners:" lines ("2 Alice" or "3 Bob, Dana": the owners of the beds in the room marked 2), then
	// "map:" and the grid to the end of the file. In the grid: '#' wall, '+' door, '.' floor, ' '
	// outdoors, a digit is floor that marks its room for "owners:", and a legend letter is one thing
	// on floor. x is the column (east is +x), z counts rows up from the bottom line (north is +z), as
	// in the game (Verse/Rot4.cs:155-158 FacingCell: North (0,0,1), East (1,0,0)).
	//
	// Rooms are found by flood fill, the way the game does it: walls and doors split rooms, and a door
	// belongs to neither side. A space touching the map's edge or containing ' ' is outdoors.
	internal sealed class LabMap
	{
		private sealed class Room
		{
			public int id;
			public List<string> owners;
			public bool outdoors;
			public readonly List<int[]> cells = new List<int[]>();
		}

		private sealed class Thing
		{
			public int id;
			public string kind;
			public string role;     // null for minor things
			public int x;
			public int z;
			public Room room;
		}

		private sealed class Door
		{
			public int x;
			public int z;
			public readonly List<Room> sides = new List<Room>();     // null entry = off the map (outdoors)
		}

		private readonly List<Room> rooms = new List<Room>();
		private readonly List<Thing> things = new List<Thing>();
		private readonly List<Door> doors = new List<Door>();

		private LabMap()
		{
		}

		// Returns null and a plain problem when the file can't be used.
		public static LabMap Load(string path, out string problem)
		{
			string[] lines;
			try
			{
				lines = File.ReadAllText(path, Encoding.UTF8).Replace("\r\n", "\n").Split('\n');
			}
			catch (Exception)
			{
				problem = "cannot read the map file " + path;
				return null;
			}

			Dictionary<char, string> legend = new Dictionary<char, string>();
			Dictionary<char, string> roles = new Dictionary<char, string>();
			Dictionary<char, string> owners = new Dictionary<char, string>();
			List<string> grid = new List<string>();
			string section = null;
			string fileName = Path.GetFileName(path);
			int gridLine = 0;     // the file line of the grid's top row
			for (int i = 0; i < lines.Length; i++)
			{
				string line = lines[i];
				if (section == "map")
				{
					if (grid.Count == 0)
					{
						gridLine = i + 1;
					}
					grid.Add(line);
					continue;
				}
				string trimmed = line.Trim();
				if (trimmed.Length == 0 || trimmed.StartsWith("#"))
				{
					continue;
				}
				if (trimmed == "legend:" || trimmed == "owners:" || trimmed == "map:")
				{
					section = trimmed.TrimEnd(':');
					continue;
				}
				if (section == null || trimmed.Length < 3 || trimmed[1] != ' ')
				{
					problem = fileName + " line " + (i + 1) + ": expected \"legend:\", \"owners:\", \"map:\" or a line like \"S shelf: storeroom\".";
					return null;
				}
				char key = trimmed[0];
				string word = trimmed.Substring(2).Trim();
				if (section == "legend")
				{
					if (!char.IsLetter(key))
					{
						problem = fileName + " line " + (i + 1) + ": a thing in the legend is one letter, like \"S shelf: storeroom\".";
						return null;
					}
					int colon = word.IndexOf(':');
					if (colon >= 0)
					{
						roles[key] = word.Substring(colon + 1).Trim();
						word = word.Substring(0, colon).Trim();
					}
					legend[key] = word;
				}
				else
				{
					if (!char.IsDigit(key))
					{
						problem = fileName + " line " + (i + 1) + ": an owners line starts with its room's digit, like \"2 Alice\".";
						return null;
					}
					owners[key] = word;
				}
			}
			while (grid.Count > 0 && grid[grid.Count - 1].Trim().Length == 0)
			{
				grid.RemoveAt(grid.Count - 1);
			}
			if (grid.Count == 0)
			{
				problem = fileName + ": the map has no \"map:\" section.";
				return null;
			}

			LabMap map = new LabMap();
			problem = map.Build(grid, legend, roles, owners);
			if (problem != null)
			{
				// Build starts its problems with the grid row ("3: ..."; 0 = the top row); turn that
				// into the file's line.
				int colon = problem.IndexOf(':');
				problem = fileName + " line " + (gridLine + int.Parse(problem.Substring(0, colon))) + problem.Substring(colon);
			}
			return problem == null ? map : null;
		}

		private string Build(List<string> grid, Dictionary<char, string> legend, Dictionary<char, string> roles, Dictionary<char, string> owners)
		{
			int height = grid.Count;
			int width = 0;
			foreach (string row in grid)
			{
				width = Math.Max(width, row.Length);
			}
			// cells[x, z]
			char[,] cells = new char[width, height];
			for (int r = 0; r < height; r++)
			{
				int z = height - 1 - r;
				for (int x = 0; x < width; x++)
				{
					char c = x < grid[r].Length ? grid[r][x] : ' ';
					if (c != '#' && c != '+' && c != '.' && c != ' ' && !char.IsDigit(c) && !legend.ContainsKey(c))
					{
						return r + ": '" + c + "' is not in the legend.";
					}
					if (char.IsDigit(c) && !owners.ContainsKey(c))
					{
						return r + ": the digit " + c + " has no line under \"owners:\".";
					}
					cells[x, z] = c;
				}
			}

			// Flood fill every open cell (not wall, not door) into rooms.
			Room[,] roomAt = new Room[width, height];
			int[][] steps = { new[] { 1, 0 }, new[] { -1, 0 }, new[] { 0, 1 }, new[] { 0, -1 } };
			for (int r = 0; r < height; r++)
			{
				int z0 = height - 1 - r;
				for (int x0 = 0; x0 < width; x0++)
				{
					if (!Open(cells[x0, z0]) || roomAt[x0, z0] != null)
					{
						continue;
					}
					Room room = new Room();
					Stack<int[]> todo = new Stack<int[]>();
					todo.Push(new[] { x0, z0 });
					roomAt[x0, z0] = room;
					while (todo.Count > 0)
					{
						int[] cell = todo.Pop();
						room.cells.Add(cell);
						char c = cells[cell[0], cell[1]];
						if (c == ' ' || cell[0] == 0 || cell[1] == 0 || cell[0] == width - 1 || cell[1] == height - 1)
						{
							room.outdoors = true;
						}
						foreach (int[] s in steps)
						{
							int nx = cell[0] + s[0];
							int nz = cell[1] + s[1];
							if (nx < 0 || nz < 0 || nx >= width || nz >= height || !Open(cells[nx, nz]) || roomAt[nx, nz] != null)
							{
								continue;
							}
							roomAt[nx, nz] = room;
							todo.Push(new[] { nx, nz });
						}
					}
					if (!room.outdoors)
					{
						room.id = rooms.Count + 1;
						rooms.Add(room);
					}
				}
			}

			// Names, things and doors, in reading order (top row first).
			for (int r = 0; r < height; r++)
			{
				int z = height - 1 - r;
				for (int x = 0; x < width; x++)
				{
					char c = cells[x, z];
					Room room = roomAt[x, z];
					if (char.IsDigit(c))
					{
						if (room.outdoors)
						{
							return r + ": the digit " + c + " is outdoors, not in a room.";
						}
						if (room.owners != null)
						{
							return r + ": one room is marked twice; use one digit per room.";
						}
						room.owners = new List<string>();
						foreach (string owner in owners[c].Split(','))
						{
							if (owner.Trim().Length > 0)
							{
								room.owners.Add(owner.Trim());
							}
						}
					}
					else if (legend.ContainsKey(c))
					{
						Thing t = new Thing();
						t.id = things.Count + 1;
						t.kind = legend[c];
						string role;
						t.role = roles.TryGetValue(c, out role) ? role : null;
						t.x = x;
						t.z = z;
						t.room = room.outdoors ? null : room;
						things.Add(t);
					}
					else if (c == '+')
					{
						Door d = new Door();
						d.x = x;
						d.z = z;
						foreach (int[] s in steps)
						{
							int nx = x + s[0];
							int nz = z + s[1];
							if (nx < 0 || nz < 0 || nx >= width || nz >= height)
							{
								d.sides.Add(null);
							}
							else if (Open(cells[nx, nz]) && !d.sides.Contains(roomAt[nx, nz]))
							{
								d.sides.Add(roomAt[nx, nz]);
							}
						}
						doors.Add(d);
					}
				}
			}
			return null;
		}

		private static bool Open(char c)
		{
			return c != '#' && c != '+';
		}

		// ---- Host functions ----

		public void Register(ScriptHost host)
		{
			host.Register("rooms", 0, a =>
			{
				List<Value> list = new List<Value>();
				foreach (Room room in rooms)
				{
					Value v = Value.NewDict();
					v.AsDict.Set("id", Value.FromNumber(room.id));
					List<Value> names = new List<Value>();
					if (room.owners != null)
					{
						foreach (string owner in room.owners)
						{
							names.Add(Value.FromText(owner));
						}
					}
					v.AsDict.Set("owners", Value.FromList(names));
					list.Add(v);
				}
				return Value.FromList(list);
			});
			host.Register("things_in", 1, a =>
			{
				Room room = FindRoom(a[0], "things_in");
				List<Value> list = new List<Value>();
				foreach (Thing t in things)
				{
					if (t.room != room)
					{
						continue;
					}
					Value v = Value.NewDict();
					v.AsDict.Set("id", Value.FromNumber(t.id));
					v.AsDict.Set("kind", Value.FromText(t.kind));
					v.AsDict.Set("role", Value.FromText(t.role));
					v.AsDict.Set("x", Value.FromNumber(t.x));
					v.AsDict.Set("z", Value.FromNumber(t.z));
					list.Add(v);
				}
				return Value.FromList(list);
			});
			host.Register("doors_of", 1, a =>
			{
				Room room = FindRoom(a[0], "doors_of");
				List<Value> list = new List<Value>();
				foreach (Door d in doors)
				{
					if (!d.sides.Contains(room))
					{
						continue;
					}
					// The other side: the first side that isn't this room (a door between a room and
					// itself has no other side).
					Value to = Value.None;
					foreach (Room side in d.sides)
					{
						if (side != room)
						{
							if (side != null && !side.outdoors)
							{
								to = Value.FromNumber(side.id);
							}
							break;
						}
					}
					Value v = Value.NewDict();
					v.AsDict.Set("x", Value.FromNumber(d.x));
					v.AsDict.Set("z", Value.FromNumber(d.z));
					v.AsDict.Set("to", to);
					list.Add(v);
				}
				return Value.FromList(list);
			});
		}

		private Room FindRoom(Value v, string function)
		{
			double n = v.AsNumber;
			if (v.kind == ValueKind.Number && n == Math.Floor(n) && n >= 1 && n <= rooms.Count)
			{
				return rooms[(int)n - 1];
			}
			throw new ScriptError("'" + function + "' needs a room's id from rooms(); there is no room " + v.ToText() + ".");
		}
	}
}
