# Spots are placed (made from agent_player\TIP_LIST.md; read by src\VerbalCommands\TipInjector.cs)
tip: Remind that anything named "spot" is PLACED, not built: `place BUILDING at SPOT.` or `place BUILDING near SPOT.`; `build` refuses a spot. (user)
between: 50000
category: furniture
order: (build|place) .*\bspot\b
