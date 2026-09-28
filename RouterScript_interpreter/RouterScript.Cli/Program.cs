using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace VerbalCommands.RouterScript.Cli
{
	// Brief 17: offline runner for the router language.
	//
	//   RouterScript.Cli run <script> [input file] [options]
	//   RouterScript.Cli test <folder>
	//
	// Options (also read from "# cli: ..." lines at the top of a test script):
	//   --entry <function>      call this function after the top level runs
	//   --arg <text>            a value for the entry function (repeat for more)
	//   --steps <n>             step limit (default 1,000,000)
	//   --depth <n>             call depth limit (default 200)
	//   --time <seconds>        wall-clock limit (default none)
	//   --cancel-after <seconds> cancel the run's token after this long
	//   --map <file>            brief 18: load a lab map and add its read functions (see LabMap.cs)
	//   --script <file>         test mode only: run this script instead of the test file itself
	//                           (to test a lab script such as router_lab\locations.txt)
	//
	// In test mode, --map and --script paths are relative to the test folder.
	//
	// Host functions: print(value), read_lines() (the input file's lines, or stdin; in test mode the
	// lines of <name>.input next to the test, if there is one). Test mode adds test_* functions that
	// exercise the host side: answers that come later, host failures, hangs, argument ranges.
	internal static class Program
	{
		private sealed class RunSettings
		{
			public string entry;
			public List<Value> args = new List<Value>();
			public ScriptOptions options = new ScriptOptions();
			public TimeSpan cancelAfter = TimeSpan.Zero;
			public string mapPath;
			public string scriptPath;
		}

		private static int Main(string[] argv)
		{
			Console.OutputEncoding = new UTF8Encoding(false);
			if (argv.Length >= 2 && argv[0] == "run")
			{
				return Run(argv);
			}
			if (argv.Length == 2 && argv[0] == "test")
			{
				return Test(argv[1]);
			}
			Console.Error.WriteLine("usage: RouterScript.Cli run <script> [input file] [--entry f] [--arg text]... [--steps n] [--depth n] [--time s] [--cancel-after s]");
			Console.Error.WriteLine("       RouterScript.Cli test <folder>");
			return 2;
		}

		// ---- run ----

		private static int Run(string[] argv)
		{
			string scriptPath = argv[1];
			string inputPath = null;
			List<string> rest = new List<string>();
			for (int i = 2; i < argv.Length; i++)
			{
				if (inputPath == null && rest.Count == 0 && !argv[i].StartsWith("--"))
				{
					inputPath = argv[i];
				}
				else
				{
					rest.Add(argv[i]);
				}
			}
			RunSettings settings = new RunSettings();
			string problem = ReadOptions(rest, settings);
			if (problem != null)
			{
				Console.Error.WriteLine(problem);
				return 2;
			}

			string source;
			try
			{
				source = File.ReadAllText(scriptPath, Encoding.UTF8);
			}
			catch (Exception)
			{
				Console.Error.WriteLine("cannot read the script file " + scriptPath);
				return 2;
			}

			List<string> inputLines;
			try
			{
				inputLines = inputPath != null ? ReadLines(File.ReadAllText(inputPath, Encoding.UTF8)) : null;
			}
			catch (Exception)
			{
				Console.Error.WriteLine("cannot read the input file " + inputPath);
				return 2;
			}

			ScriptHost host = new ScriptHost();
			host.Register("print", 1, a =>
			{
				Console.WriteLine(a[0].ToText());
				return Value.None;
			});
			host.Register("read_lines", 0, a =>
			{
				if (inputLines == null)
				{
					inputLines = ReadLines(Console.In.ReadToEnd());
				}
				return Value.FromStrings(inputLines);
			});
			if (settings.mapPath != null)
			{
				LabMap map = LabMap.Load(settings.mapPath, out problem);
				if (map == null)
				{
					Console.Error.WriteLine(problem);
					return 2;
				}
				map.Register(host);
			}

			List<string> output = new List<string>();
			bool ok = RunScript(Path.GetFileName(scriptPath), source, host, settings, output);
			foreach (string line in output)
			{
				(ok ? Console.Out : Console.Error).WriteLine(line);
			}
			return ok ? 0 : 1;
		}

		// Runs one script; output gets "returned: ..." (for an entry function) or the error lines.
		private static bool RunScript(string fileName, string source, ScriptHost host, RunSettings settings, List<string> output)
		{
			Script script = Script.Load(fileName, source, host);
			if (!script.Ok)
			{
				output.AddRange(script.errors);
				return false;
			}
			script.options = settings.options;
			using (CancellationTokenSource cancel = new CancellationTokenSource())
			{
				if (settings.cancelAfter > TimeSpan.Zero)
				{
					cancel.CancelAfter(settings.cancelAfter);
				}
				ScriptResult result = script.RunAsync(settings.entry, settings.args, cancel.Token).GetAwaiter().GetResult();
				if (!result.ok)
				{
					output.AddRange(result.errors);
					return false;
				}
				if (!string.IsNullOrEmpty(settings.entry))
				{
					output.Add("returned: " + result.value.ToText());
				}
				return true;
			}
		}

		private static string ReadOptions(List<string> args, RunSettings settings)
		{
			for (int i = 0; i < args.Count; i++)
			{
				string name = args[i];
				if (i + 1 >= args.Count)
				{
					return "the option " + name + " needs a value";
				}
				string value = args[++i];
				double number;
				bool isNumber = double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out number);
				switch (name)
				{
					case "--entry":
						settings.entry = value;
						break;
					case "--arg":
						settings.args.Add(Value.FromText(value));
						break;
					case "--steps":
						if (!isNumber)
						{
							return "--steps needs a number";
						}
						settings.options.maxSteps = (long)number;
						break;
					case "--depth":
						if (!isNumber)
						{
							return "--depth needs a number";
						}
						settings.options.maxCallDepth = (int)number;
						break;
					case "--time":
						if (!isNumber)
						{
							return "--time needs a number of seconds";
						}
						settings.options.timeLimit = TimeSpan.FromSeconds(number);
						break;
					case "--map":
						settings.mapPath = value;
						break;
					case "--script":
						settings.scriptPath = value;
						break;
					case "--cancel-after":
						if (!isNumber)
						{
							return "--cancel-after needs a number of seconds";
						}
						settings.cancelAfter = TimeSpan.FromSeconds(number);
						break;
					default:
						return "unknown option " + name;
				}
			}
			return null;
		}

		private static List<string> ReadLines(string text)
		{
			List<string> lines = new List<string>(text.Replace("\r\n", "\n").Split('\n'));
			if (lines.Count > 0 && lines[lines.Count - 1].Length == 0)
			{
				lines.RemoveAt(lines.Count - 1);
			}
			return lines;
		}

		// ---- test ----

		private static int Test(string folder)
		{
			if (!Directory.Exists(folder))
			{
				Console.Error.WriteLine("no such folder: " + folder);
				return 2;
			}
			string[] files = Directory.GetFiles(folder, "*.txt");
			Array.Sort(files, StringComparer.Ordinal);
			int passed = 0;
			int failed = 0;
			foreach (string file in files)
			{
				string name = Path.GetFileName(file);
				string expectedPath = Path.ChangeExtension(file, ".expected");
				if (!File.Exists(expectedPath))
				{
					Console.WriteLine("FAIL " + name + ": no " + Path.GetFileName(expectedPath));
					failed++;
					continue;
				}
				List<string> actual = RunTest(file);
				List<string> expected = ReadLines(File.ReadAllText(expectedPath, Encoding.UTF8));
				TrimTrailingEmpty(actual);
				TrimTrailingEmpty(expected);
				if (Same(expected, actual))
				{
					Console.WriteLine("PASS " + name);
					passed++;
				}
				else
				{
					Console.WriteLine("FAIL " + name);
					PrintDiff(expected, actual);
					failed++;
				}
			}
			Console.WriteLine();
			Console.WriteLine(passed + " passed, " + failed + " failed, " + files.Length + " tests");
			return failed == 0 ? 0 : 1;
		}

		private static List<string> RunTest(string file)
		{
			List<string> output = new List<string>();
			string source = File.ReadAllText(file, Encoding.UTF8);

			RunSettings settings = new RunSettings();
			foreach (string line in ReadLines(source))
			{
				if (line.StartsWith("# cli:"))
				{
					string problem = ReadOptions(SplitCommandLine(line.Substring("# cli:".Length)), settings);
					if (problem != null)
					{
						output.Add("bad # cli: line: " + problem);
						return output;
					}
				}
			}

			string folder = Path.GetDirectoryName(file);
			string fileName = Path.GetFileName(file);
			if (settings.scriptPath != null)
			{
				fileName = Path.GetFileName(settings.scriptPath);
				try
				{
					source = File.ReadAllText(Path.Combine(folder, settings.scriptPath), Encoding.UTF8);
				}
				catch (Exception)
				{
					output.Add("cannot read the script file " + settings.scriptPath);
					return output;
				}
			}

			string inputPath = Path.ChangeExtension(file, ".input");
			List<string> inputLines = File.Exists(inputPath) ? ReadLines(File.ReadAllText(inputPath, Encoding.UTF8)) : new List<string>();

			ScriptHost host = new ScriptHost();
			host.Register("print", 1, a =>
			{
				// Text with "\n" in it prints as several lines, as it would on the console.
				output.AddRange(a[0].ToText().Split('\n'));
				return Value.None;
			});
			host.Register("read_lines", 0, a => Value.FromStrings(inputLines));
			AddTestFunctions(host);
			if (settings.mapPath != null)
			{
				string problem;
				LabMap map = LabMap.Load(Path.Combine(folder, settings.mapPath), out problem);
				if (map == null)
				{
					output.Add(problem);
					return output;
				}
				map.Register(host);
			}

			RunScript(fileName, source, host, settings, output);
			return output;
		}

		// Host functions that only exist in test mode, to test the host side of the language.
		private static void AddTestFunctions(ScriptHost host)
		{
			// Gives its value back, but only after a real wait (the script must await it).
			host.RegisterAsync("test_later", 1, async (a, token) =>
			{
				await Task.Delay(10, token).ConfigureAwait(false);
				return a[0];
			});
			host.RegisterAsync("test_wait", 1, async (a, token) =>
			{
				await Task.Delay((int)a[0].AsNumber, token).ConfigureAwait(false);
				return a[0];
			});
			// Busy on the calling thread (a slow host function that answers "immediately").
			host.Register("test_block", 1, a =>
			{
				Thread.Sleep((int)a[0].AsNumber);
				return a[0];
			});
			host.Register("test_fail", 1, a =>
			{
				throw new ScriptError(a[0].ToText());
			});
			host.RegisterAsync("test_fail_later", 1, async (a, token) =>
			{
				await Task.Delay(10).ConfigureAwait(false);
				throw new ScriptError(a[0].ToText());
			});
			// A host bug: its exception text must never reach the player.
			host.Register("test_crash", 0, a =>
			{
				throw new InvalidOperationException("System.InvalidOperationException: internal detail at Foo.Bar()");
			});
			// Never answers and ignores cancellation.
			host.RegisterAsync("test_hang", 0, (a, token) => new TaskCompletionSource<Value>().Task);
			// A Task the host cancelled by itself (the run was not cancelled).
			host.RegisterAsync("test_cancelled", 0, (a, token) =>
			{
				TaskCompletionSource<Value> source = new TaskCompletionSource<Value>();
				source.SetCanceled();
				return source.Task;
			});
			// Take 1 to 3 (or 1 or 2) values and say how many they got.
			host.Register("test_range", 1, 3, a => Value.FromNumber(a.Length));
			host.Register("test_optional", 1, 2, a => Value.FromNumber(a.Length));
			// Value -> plain C# data -> Value.
			host.Register("test_convert", 1, a => Value.From(a[0].ToObject()));
			// C# strings, numbers, lists and dictionaries -> Value.
			host.Register("test_from_csharp", 0, a =>
			{
				Dictionary<string, object> d = new Dictionary<string, object>();
				d["name"] = "Alice";
				d["age"] = 31;
				d["weight"] = 60.5f;
				d["rooms"] = new List<string> { "kitchen", "rec room" };
				d["drafted"] = false;
				d["pet"] = null;
				return Value.From(d);
			});
			// Value -> C# strings (the list helper the mod will use).
			host.Register("test_to_strings", 1, a => Value.FromText(string.Join("|", a[0].ToStringList().ToArray())));
		}

		// Splits `--arg "two words" --entry route` into ["--arg", "two words", "--entry", "route"].
		private static List<string> SplitCommandLine(string line)
		{
			List<string> result = new List<string>();
			StringBuilder current = new StringBuilder();
			bool quoted = false;
			bool any = false;
			foreach (char c in line)
			{
				if (c == '"')
				{
					quoted = !quoted;
					any = true;
				}
				else if (c == ' ' && !quoted)
				{
					if (any)
					{
						result.Add(current.ToString());
						current.Length = 0;
						any = false;
					}
				}
				else
				{
					current.Append(c);
					any = true;
				}
			}
			if (any)
			{
				result.Add(current.ToString());
			}
			return result;
		}

		private static void TrimTrailingEmpty(List<string> lines)
		{
			while (lines.Count > 0 && lines[lines.Count - 1].Length == 0)
			{
				lines.RemoveAt(lines.Count - 1);
			}
		}

		private static bool Same(List<string> a, List<string> b)
		{
			if (a.Count != b.Count)
			{
				return false;
			}
			for (int i = 0; i < a.Count; i++)
			{
				if (a[i] != b[i])
				{
					return false;
				}
			}
			return true;
		}

		private static void PrintDiff(List<string> expected, List<string> actual)
		{
			int n = Math.Max(expected.Count, actual.Count);
			for (int i = 0; i < n; i++)
			{
				string e = i < expected.Count ? expected[i] : null;
				string a = i < actual.Count ? actual[i] : null;
				if (e == a)
				{
					continue;
				}
				Console.WriteLine("  line " + (i + 1) + ":");
				Console.WriteLine("    expected: " + (e ?? "(nothing)"));
				Console.WriteLine("    actual:   " + (a ?? "(nothing)"));
			}
		}
	}
}
