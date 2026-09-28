# Why the interpreter is the way it is: decisions and the user's own words

Every quote here is a **whole message** the user typed, verbatim (spelling and swearing kept), taken
from `notes\user_words\router_language_quotes.md` / `all_user_messages.md` at the project root (extracted
from the session transcripts by a Sonnet agent, 2026-09-28). Format: session id, timestamp (UTC). Where
a message answers a question, the question is given in one line as context (from the transcript).

Honesty rule for this file: if a decision has **no** user quote behind it, it says so and names where the
decision really came from (usually brief 17, which the coordinating Claude session wrote). Nothing here
is attributed to the user that the user didn't type.

---

## D1. The router is a readable, programmable file the mod runs — not logic compiled into the DLL
**User's words:**

> 83ddf995 2026-09-28T01:27:30Z
> ```
> you may start compiling. and do realize that the router is essentially a programmable language, and probably needs to be on a VERY READABLE format probably not even in .dll format. think shit like python, because thats essentially what the language is.
> ```

> 83ddf995 2026-09-28T01:30:00Z (context, from the transcript: at 01:28:45 the assistant had proposed a plain-text *rules file* "the mod reads each time an order comes in", holding only `if ...: offer ...` lines)
> ```
> lol no that's not something haiku reads it. that's something it literally runs
> ```

> 83ddf995 2026-09-28T01:41:04Z
> ```
> dont that peseudocode.md i post literally state that this is basically a natural language that is programmable
> ```

Earlier history (2026-09-27, the 5-step router): the user described step 1 (regex) as local, not an
LLM call:

> 83ddf995 2026-09-27T01:39:53Z
> ```
> can you do a router in anthropics api console where:
>
> 1 > regex rule looks at keyword matches first. if there are combinations that can be seen in sentences, step 2 is skipped and goes to 4
> 2 > haiku looks at the ~~garbage~~ prompt and replaces user's words with something that is regexable
> 3 > output of haiku's prompt goes into the tooling (into user) and makes apporporaite call.
> 4 > the actual model user selected on api console setting goes in and then does the shabam.
> 5 > the actual model makes arrangement.
> ```

> 83ddf995 2026-09-27T01:41:09Z
> ```
> well duh 1 stays in DLL. DUHHHHHH?
> why the hell would i even use haiku or any llm to do that?
> ```

> 83ddf995 2026-09-27T01:42:03Z
> ```
> There is no "confidence". there is only "me regex, regex dont see required keyword combination. regex route this garbage prompt of user to haiku and have it unfuck it".
> ```

(Reading of these, the coordinating session's: "stays in DLL" contrasts running locally with calling an
LLM. The later message, 2026-09-28T01:27:30, sets the format: the routing logic is a readable
program, "probably not even in .dll format". The interpreter itself is C# inside the mod; the router
logic is the text file it runs. Both hold.)

The user's README (`intent.md` = GitHub README, Router V2), written by the user:
> 2. **Haiku's output** goes into the interpreter to see if the prompt is actually valid.
> ...
> Result: Significant token saving (if it works well enough, that is) since LLMs don't have to write bill changes by themselves, since the interpreter is the one manipulating game state.

**Where in the code:** the whole library exists for this. `Script.Load` + `RunAsync` (Script.cs:50-84)
run a text file; nothing router-specific is compiled in. Players are not expected to edit it (D2).

---

## D2. Its own language, not Python; the file is `router.txt`; it ships with the mod
**User's words:**

> 83ddf995 2026-09-28T01:36:35Z (context: the assistant asked (1) `router.py`, which editors colour as Python but isn't Python, or `router.txt`; (2) what happens on a mod update if the player edited the router)
> ```
> I would like colouring, and I expect that i dont even touch my own router and cause a mismatch like this because this is way too complex
> ```

> 83ddf995 2026-09-28T01:37:45Z (context: at 01:36:55 the assistant asked whether brief 16's Haiku instruction file should also ship in the mod folder and be replaced by updates, like the router)
> ```
> didnt the choices i made above already fucking say the answer to last?
> ```

> 83ddf995 2026-09-28T02:12:32Z
> ```
> is the language itself being worked on, or not. I dont think that agent built an interpreter because you never fucking knew what you were doing
> ```

> 83ddf995 2026-09-28T02:14:04Z
> ```
> go build the interpreter first. and maybe drop the fucking .py extension. before you start conflating this is python
> and no, dont let sonnet do this job.
> ```

So: "think shit like python" (D1) is about the *look* (indentation blocks, plain words); the language
is not Python and must not be called Python (the `.py` name was dropped, and with it the colouring).
Nobody edits the router ("this is way too complex"): it ships in the mod folder and every update
replaces it (`briefs\router_script_draft.md:127-134`, "Decided (user, 2026-09-27)").

**Where in the code:** English keywords `and or not none true false` and no symbols like `!`, `&&`,
`.method()` (Lexer.cs:56-63, 402-409; Parser.cs:503-506); indentation blocks (Parser.cs:6-9); B17:6-8
("This is its own small language ... It is NOT Python ... meant to read like plain English"). No
colouring exists (it would be an editor feature; nothing was built for it).

---

## D3. Arduino-style: a small core plus read/write functions the mod provides
**User's words:**

> 83ddf995 2026-09-28T01:33:03Z
> ```
> id expect C++ have basically all the feature it needs. especially arduino fitted ones. write, read functions. that does not mean you write that in C++ because c++ is borderline human unreadable
> ```

What the mod must read for the router (room labels as the game gives them):

> 83ddf995 2026-09-27T01:16:31Z
> ```
> those need to be added to dll so agents can grab storage and what room they are in. I noticed (as i said on compact) you two incorrectly labeled room (i.e. creative interpretation). you should be reading room label as is (the main room is shrine, not rec room, even though it looks like one) to avoid confusion, since room label data gets sent as is without interpretation by dll
> ```

Background (the user's framing from the project's first session, typed as `/compact` instructions,
`817c6ac8` 2026-08-31T02:44:54Z, long; not repeated here): RimWorld has no API layer, so the mod *is*
the API layer.

**Where in the code:** `ScriptHost.Register` / `RegisterAsync` (Script.cs:152-246): the script reaches
the game only through functions the host registers (B17:79-80). The core is the ~22 instructions and 22
built-ins; everything game-specific is a host function. Lab stand-ins: `rooms()`, `things_in()`,
`doors_of()` (LabMap.cs). No real game functions exist yet.

---

## D4. The language is sentences with slots: one template, used to write for the player and to read the model
**User's words:** 83ddf995 2026-09-28T01:41:04Z, quoted whole in D1 ("dont that peseudocode.md i post
literally state that this is basically a natural language that is programmable").

The pseudocode the user posted (`spatial_context_pseudocode.md:4-6`):
> ```
> ## ---- Output requirement ----
> # every template fills into a full sentence a player can read as-is.
> # same sentences go to the model: one text, two readers (player + model).
> ```

Fixed phrasing so a small model can handle it:

> 83ddf995 2026-09-27T01:23:39Z
> ```
> i have a better idea. instead of doing a multi loop, we expect that a sane person would say shelving storage as "shelving", shelving storage as "shelving settings" or something similar. so expected prompt would look like "storage settings in... [room name]" or "storage settings for [shelves that is meant for outputting specific goods from specific table]".
>
> I was thinking about making a rule like this so even dummy like haiku can process data without being bombared with 50k of useless context slop
> ```

> 83ddf995 2026-09-27T01:31:36Z
> ```
> What about synynomes, because that is a thing.
> Im sure you can probably say "Change my storage settings for shelves located close to bar inside my church" in like 5 diff ways using different wordings.
> do that right now
> ```

The user's README (`intent.md`):
> Since the interpreter accepts natural language (e.g. "build shelves that only accept food item into my freezer room"), that's all models need to type in.
>
> End goal is to have easily typable language that is natural enough so people can simply verbally speak without having to use an LLM at all, and also an interpreter/harness so one day LLMs could play rimworld by reading game states and verbally typing (and receiving game state) from/to interpreter.

The "fill / parse / teach" split (one template used three ways) is the coordinating session's wording in
`briefs\router_script_draft.md:8-16`, derived from the pseudocode; the user didn't use those three words.

**Where in the code:** `Sentences.cs` (`fill`, `parse`, `split_list`, `join_list`), exposed as built-ins
(Builtins.cs:158-180). Why `parse` ignores case, spaces, one trailing `.` and wrapping backticks: B17:69
(brief 17 was written after the first lab run, where Haiku wrapped one line in backticks:
`brief17_agent_report.md`, "including the backtick-wrapped one in order 4").

---

## D5. Everything the player sees is plain words: no error codes, no exception text; file and line
**User's words** (the general rule; the message answers a numbered list of review points, item 1 being
how failure messages should read):

> 83ddf995 2026-09-28T01:15:20Z (fullest of three near-identical sends, 01:13:46 / 01:14:18 / 01:15:20)
> ```
> 1 should be as plainy as what the fail says. this should be about as default for anything happens. no error code, just literally what happened.
>
> 2. block from offering unless it's placement/planning.
>
> 3. it's fucking why we have this room-label/not-room label thing, remember? that's a relative location of where that shelf even is
>
> 4. this needs more context.
>
> 5. how?
>
> 6. well fucking duh.
>
> 7. Sure. even though so far i never even had a crash where i cant send stuff.
>
> 8. i have no idea which idiot would do this. you could block that setting so people can only change it on start screen, but you can also "grey it out".
>
> 9. But they are single words with different character. is this even an issue?
>
> 10. block order containing no room name. probably one that also haiku would send to router. Haiku is probably smart enough to say "you forgot to say what room, dipshit". add that to instruction.
>
> 11. leave it like that and have mod give the rimworld-style notis ("changes have been applied") with that bee-beep noise.
>
> 12. not enough storage warning shouldnt really affect mod itself.
> ```

Earlier (2026-09-27), before that rule:

> 83ddf995 2026-09-27T03:10:55Z (context: what the router still needs)
> ```
> Pending user fixes there: `##Router (V2)` need..
> Ah. those. regex && rules, delays (so router runs well for potential network issues), probably exception error codes, etc.
> does that sound about right
> ```
The later message ("no error code, just literally what happened", "about as default for anything") is
the rule in force.

"Always with file and line" is brief 17's wording (B17:95: "Errors: plain words, always with file and
line (the user's general rule)"): the plain-words part is the user's; adding file and line is the
brief's.

**Where in the code:** every message in Lexer/Parser/Compiler/Runner/Operations/Builtins/Sentences;
`Value.Describe` ("a number", "text" instead of type names, Value.cs:442-460); `Script.Where` (file and
line, Script.cs:86-90); interpreter bugs become one plain sentence (Script.cs:60-64, Runner.cs:107-111);
a host crash shows only `'name' failed.` (Runner.cs:430-442).

---

## D6. Check the whole file first; report every problem at once
**No user quote found.** Source: brief 17 (B17:81-83), written by the coordinating session. Every pass
carries on after a bad line for this (Lexer.cs:50-51, Parser.cs:6-9, Compiler.cs:61-63).

---

## D7. A broken router must never hang or crash the game (limits)
**No direct user quote found** for the limits. Source: brief 17 (B17:90-93: "a broken router must never
hang or crash the game"), written by the coordinating session. Related user words: "delays (so router
runs well for potential network issues)" in the 2026-09-27T03:10:55Z message quoted whole in D5.
The limit values (1,000,000 steps, depth 200, the size caps) are B17's defaults and the brief 17 agent's
choices (R17-14).

**Where in the code:** Script.cs:93-103 (options), Runner.cs:444-525, Operations.cs:11-13,
Builtins.cs:24-26, Sentences.cs:40-45, Parser.cs:12-13; script calls never use the C# stack
(Runner.cs:12-14).

---

## D8. Host functions may answer later; the game's main thread never waits on the script
**No direct user quote found.** Source: brief 17 (B17:84-86). The need follows from the user's router
steps (D1, the 5-step router): the router calls Haiku (a network call) in the middle of routing. Related:
"delays (so router runs well for potential network issues)" (D5, 2026-09-27T03:10:55Z).

**Where in the code:** `RegisterAsync` (Script.cs:173-187), the single `await` in the run loop
(Runner.cs:255-261, 376-428), thread notes (Script.cs:22-25).

---

## D9. How it is built and tested
**Offline lab, the user's workflow:**

> 83ddf995 2026-09-28T01:54:56Z (fuller resend of 01:54:20)
> ```
> i dont even plan on deploying and then run haiku to it, im going to type some example shit, have haiku turn it into something the language can parse (which you will make system prompt on what it should turn those into, and what it should reject due to ambiguity, etc) and ultimately have that as a rule (probably elseif)  if some context is missing, etc. then have you/sonnet/etc try to make very small changes, where everything goes into the router first in intended way
> ```

**Who works on it:**

- 83ddf995 2026-09-28T02:14:04Z: quoted whole in D2 (its second line: "and no, dont let sonnet do
  this job.").

> 83ddf995 2026-09-28T04:39:22Z (typed as /compact instructions)
> ```
> /compact Router language: read COMPACT_2026-09-28_router_language.md in the project root first, then intent.md (the README; the workflow should match it).
>   Brief 17 interpreter is built (src\RouterScript + CLI, 94/94 tests); next step is writing router.txt, which waits for my go. Mod DLL 15b/15c compile-only,
>   NOT deployed. Interpreter/language work is Opus only. Drop all /context and /usage output from the summary; keep everything else from the session.
> ```

> 83ddf995 2026-09-28T05:05:49Z
> ```
> Have opus medium agent start adding to the interpreter.
> ```

**Prompt tests are Haiku's, never Opus's:**

> 83ddf995 2026-09-28T04:48:35Z
> ```
> which agent yapped those during test. opus? or haiku.
> ```

> 83ddf995 2026-09-28T05:09:52Z
> ```
> test prompt is done by haiku. not opus.
> ```

> 83ddf995 2026-09-28T06:15:15Z (typed as /compact instructions)
> ```
> /compact use session handoff pointer. list what the interpreter does and why it exists. state in short bulletpoints what the interpreter can do. use extra effort to account for all of what it can do and what it cannot do based on facts (use files as pointers). Remind next agent that only haiku is allowed to make example prompts.
> ```

> 83ddf995 2026-09-28T05:43:17Z
> ```
> maybe write a "this is unrealistic scenario".md for agents doing example prompt.
> ```

**Deploying:**

> 7ce6ce14 2026-09-24T22:50:40Z
> ```
> I will not be closing it and deploying unless I actually say a yes, maybe give that agent a reminder
> ```

**These notes:**

> 83ddf995 2026-09-28T06:38:49Z
> ```
> go dig that code and start putting literally line by line what code does, and i fucking hope that interpreter already has some notes on rationale behind why it does something. Looking at past compact is allowed and is recommended. reading https://github.com/dongk99/RimworldVerbalCommands/blob/main/README.md to see router interpreter is recommended. I expect every line of that code have note and have .md say why it's there, logic behind it based on what i actually fucking said (because I did verbally type a lot of this shit). you are not allowed to add any new code. you may use sonnet/haiku to grab exact transcripts of what i said but it better be full fucking sentences and not snippets.
>
> you fuck up here and every agent from there on has no idea wtf you are doing. you're on xhigh effort.
> ```

**Where:** `router_lab\` (offline), `RouterScript.Cli` (Program.cs), tests in
`router_lab\script_tests\`, `router_lab\unrealistic_scenarios.md`.

---

## D10. Locations and rooms (brief 18 and handoff §3b)
**Directions and the reference point:**

> 83ddf995 2026-09-28T04:55:56Z
> ```
> I take the interpreter also has direction clause (north, west, south, east, up, down, left, right) relative to an object, yes?
> object relativeness should be door, if none exist, then whatever is the fewest object in room to more.
> ```

> 83ddf995 2026-09-28T05:01:06Z (fuller resend of 04:59:52)
> ```
> Ah, those. room with several doors can be described relative to center of position of those doors. if it has a door leading to another room, then it can use that door + [room label leading to door] as intent to user (and as interpreter). If it does not (like for example, matryoshka type rooms) then it can fallback to  relative position using center.
> ```

> 83ddf995 2026-09-28T05:02:18Z
> ```
> [Image #8] This kinda room might be problematic.
> [image attached]
> ```
(The image: a U-shaped storeroom wrapped around two bedrooms, `Documents\ShareX\Screenshots\2026-09\RimWorldWin64_pMCypbNZpO.jpg`.)

> 83ddf995 2026-09-28T05:03:37Z
> ```
> Simply say which door leads to which room. Though im not sure how interpreter would need to define a room as U-shape.
> ```

> 83ddf995 2026-09-28T05:04:36Z
> ```
> and if the room is something like, 1x10 cross-shape (essentially a corridor)?
> ```

**Every room has a name, from its furniture:**

> 83ddf995 2026-09-27T23:45:16Z
> ```
> if it labels as bedroom, then router says [pawn_name, and pawn_name]'s bedroom instead. if the bed is placed outside, then the [pawn_name] bed is used as relative coordinate. 3 is mainly so if someone wants to place an output shelf to a station with bills.
> ```

> 83ddf995 2026-09-27T23:46:58Z (fuller resend)
> ```
> I know 1 already does that, but multiple bedrooms just labels it as "barracks". this is for players to read since players approve what shit goes to where. perhaps read up on what the game does for exceptions?
> ```

> 83ddf995 2026-09-27T23:49:34Z
> ```
> No, dont put everyons name for multiple owner. first and last, and that's what it gets shown to users.
> ```

> 83ddf995 2026-09-28T00:22:52Z (fuller resend)
> ```
> "Preferred" is the default unless players specify shelves (low, normal, preferred, important, critical). no other word is allowed.
>
> 5 seems fine.
>
> a/c. see how game labels rooms. However, if multiple conflicting furniture is shown (bed + production bench) then it will just say [furniture type name 1 (and)&& furniture type name 2]. if more than 2 is present than default is "mixed room [num]" which contains {furniture/production building list} e.g. "mixed room which contains 3 beds, 2 end tables, 1 dresser, 1 electric stove, 1 shrine"...
> do not count "minor" furnitures such as desks and chairs (but they are still placeable using blueprint).  goal is to have least amount of bloat sentences while describing the actual room reasonably accurate to user. if the room contains shelves, the default is "shelves" [no number]. for planning only; if the user is asking shelving specific question then the mod uses aforementioned array rule to count shelves of different types. (Preferably, the mod should "learn" from user). Exception being when the shelves already have specific type of resources  (e.g. food shelves typically contain majorly food, and few other resources such as herbal medicine which is expirable). weapon shelves primarily contain weapons (even specific weapons) and clothing (typically armor).
> ```

> 83ddf995 2026-09-28T05:38:46Z
> ```
> write a compact first including what is build, what is added and what is missing and unnamed rooms dont fucking exist, I already said a while ago they get force-named based on what furniture or what is even on there.
> ```

> 83ddf995 2026-09-28T05:43:46Z
> ```
> "Naming rooms by their furniture isn't built. Step I only covers major furniture, so the wording for a room with only minor things, like a corridor with
>       lamps, isn't written yet."
>
> Define major furniture.
> ```

> 83ddf995 2026-09-28T05:45:17Z
> ```
> let me guess. the interpretert sucks because you didnt look at those
> ```

> 83ddf995 2026-09-28T05:48:08Z
> ```
> iron out interpreter by adding room lables of those first. except "dining room". Dining room gets dining room. desk/chair otherwise dont count as major.
> ```

**Where:** not in `src\RouterScript` itself (the core has no rooms). In the lab: `LabMap.cs` (rooms by
flood fill, roles, owners, door sides; north = +z) and `router_lab\locations.txt` (the naming and location
rules, written in the language). Brief 16 Step I holds the naming rule; the name for a room with only
minor things is still open (the game's "room" is used meanwhile).

---

## D11. Sentence-language rules (they live in the router lab scripts, not in the interpreter)
Listed so nobody looks for them in `src\RouterScript`: they are in `router_lab\haiku_prompt.md` and
`router_lab\parse_results.txt`, and later `router.txt`.

> 83ddf995 2026-09-28T04:42:17Z
> ```
> one thing i thought about. a lot of of the sentences are actually parallel, so the interpreter needs to be able to parse parallel. e.g. there is really no need to have a sequential command where one relies on another. e.g. placing doors on a wall does not require walls to be deconstructed. stockpile zones on fridge does not need to be cleaned out, a shelf blueprint can simply placed right over.
> ```

> 83ddf995 2026-09-28T04:45:16Z
> ```
> certain grammar likely does not even need to be used e.g. "a". I expect haiku to use "a" a lot. they could safely be ignored. but most action verbs (put, place, build, construct, draft, sleep, place...) is something that defines actions. addn. bed assignment, they dont really need to be un-assigned since reassigning pawns unassign former. this is something you dont need to waste token looking at game state as i know for fact.
> ```

> 83ddf995 2026-09-28T04:47:40Z
> ```
> show me an example interpretable-acceptable line.
> ```

> 83ddf995 2026-09-28T04:51:42Z
> ```
> haiku.md (or whatever this file is named) should show what is an ACCEPTABLE sentence and what isn't. and something it is shortish enough that its dimwitty little neural net can have enough attention for and transform user's intent into yaps.
> Furthermore, incase haiku MAKE something up (e.g. if player never said "3" shelves when haiku yaps "build 3 shelves" the interpreter (now harness) needs to check if the present-number 3 was actually present on original player statement. naturally, this is something that would work best with number context
> ```

Storage items the game refuses (a rule for the router, not the interpreter core):

> 83ddf995 2026-09-28T01:18:59Z
> ```
> either that item actually exists or dont and that's fucking trivial to check by having mod look at game states. are you overthinking? and if the player can never get, then they would also not say it in the beginning.
> ```

> 83ddf995 2026-09-28T01:21:02Z
> ```
> and for 4. router shouldnt even be allowing agent to allow items that cant even go in.
> ```

The interpreter needs nothing new for parallel sentences: a script loops over the sentences and no
sentence reads another's result (old handoff §2c).

---

## Decisions made by the building agents, not the user
Where brief 17 was silent, the Opus agent chose; these are NOT the user's decisions and can be changed
if the user says so. Full list with reasons: `brief17_agent_report.md`, "Ambiguities and what I chose".
The main ones: top-level lines run on every run; local-then-global lookup and no global assignment from
functions; `and`/`or` give true/false; `for` over a copy; no negative positions; `/` always decimal and
`%` keeps the left sign; case-sensitive text comparisons except `parse`/`find_pattern`; `fill`'s optional
part rule; `parse` details (trailing `.`, backticks, shortest slot, repeated slot); `split_list` splits on
"and" inside names; tabs only reported on code lines; the "never given a value" check; thread behaviour;
the limit values. Brief 18's agent chose: continuation stops at a statement word or `=`; the "never
closed" message; trailing commas; the lab host functions' shape; the tie rule in `locations.txt`.
