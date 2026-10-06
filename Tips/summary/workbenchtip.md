# Workbenches (made from agent_player\TIP_LIST.md; read by src\VerbalCommands\TipInjector.cs)
tip: Remind that a tool cabinet gives +6% to a linked bench within 8 tiles in the same room (2 at most, one between two benches serves both); work is slower in the dark; a stockpile of the bench's ingredients beside it saves a lot of walking.
between: 30000
category: furniture
order: tool cabinet
order: build .*(bench|stove)\b
order: build kitchen
