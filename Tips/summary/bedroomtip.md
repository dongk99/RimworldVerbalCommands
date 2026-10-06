# Beds in workrooms (made from agent_player\TIP_LIST.md; read by src\VerbalCommands\TipInjector.cs)
tip: Remind that one bed put into a dining room or laboratory turns it into a bedroom: keep beds out of workrooms. A furnished bedroom needs about 5 by 5 inside, which is `7 by 7` in the sentence.
between: 30000
category: furniture
order: build .*\bbed\b
order: build bedroom
order: build barracks
