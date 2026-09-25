#RimworldVerbalCommands
LLM-Assisted rimworld mod where users speak to an agent to set groups for different colony functions (e.g. pawn group by weapon they're holding, work priority based on skills, allowed zone based on pawn) and more.

Currently being tested with Anthropic models (claude-haiku-4-5, claude-sonnet-5, claude-opus-5, claude-opus-5-5). Test condition: 1 colony worth of 11 pawns (275x275 map), 1 colony (2 map) of 33 pawns (300x300) and 11 pawns (SOS2 space map, no odyssey), 1 colony of 325x325 map (57 pawns, 33 pawns).

Current testing done: Weapon groups, work priority based on skill. Tests needing to be done:

zoning based on pawn stats (so they dont waste time wandering around outside their jobsites), and eval metrics.
Verbal command itself (Currently all of the test was done with text input for fewer variability) based on Voice-to-text models.
Wishlist: Getting claude-haiku-4-5 to write changes properly. currently, haiku doesnt seem to make full changes and seem to accomplish tasks partially. a rule-based agentic process (sonnet + haiku), or multiple haikus (or 1 haiku with macro based rules) would be needed to keep API costs down.

Users are welcome to fork mod as needed and test with different models/add feature as necessary.
