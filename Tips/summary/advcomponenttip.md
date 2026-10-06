# Advanced components (made from agent_player\TIP_LIST.md; read by src\VerbalCommands\TipInjector.cs)
tip: Remind that late techs cost advanced components, and those are made only after Advanced fabrication, from 1 component, 20 steel, 10 plasteel and some gold each. {count:ComponentSpacer}
between: 50000
order: advanced component
order: research .*(advanced fabrication|bionic|charged shot|ground-penetrating|long-range mineral|cryptosleep|ship)
order: \bbionic
order: charge (rifle|lance)
