If wealth curve does not change, it's because "snowballing" effect did not happen yet. typically, models (or humans) that make poor judgement tend to have cascading effect, e.g. Poor food management results in starving pawns, which makes them less productive (less output) and eventually results in their death (loss of colony wealth). However, there are some randomized factors due to game's nature, which is why various metrics need to be observed at same time to infer model's capability.

## Arctic 1 (Opus 5.5, session 62e1b26f)

Effort: medium

Start state:
- Time: tick 20, 2nd of Jugust 5500, 06:00, paused
- Weather: permanent winter, -22C, clear
- Hicklin: healthy, rest 90%
- Stumpy: sick, rest 97%
- Zimmerman: sick, rest 96%
- All 3: in incoming drop pods, mood 50%, food 80%
- Food: 0 meals, 7 raw (6.3 nutrition)
- Power: none
- Research: no project

Failures:
- Save tick: 139839
- Failures in save: 34 (13 main claude-opus-5-5, 21 subagents claude-haiku-5-5)

Failures per 1000 ticks:
- Ticks 0-139839: 34 / 139839 = 0.24

Botched construction (save "Opus 5(.5) arctic 1.rws", played on to tick 201247; the save keeps botches per 60000 ticks):
- Ticks 0-119999: 8 of 87 builds (Stumpy)
- Ticks 120000-179999: 1 of 26 (before or after tick 139839 not kept)
- Ticks 0-201247: 9 of 127 (7.1%)

Mental breaks (same save):
- Ticks 0-139839: 0 breaks, 0 time below the break line
- Ticks 0-201247: 0 breaks; Stumpy below the minor break line twice, 2400 ticks (ticks 188215-191665)

Wealth (total, recorded every 30000 ticks; same save; human: "Shivalvard.rws", same map and start; every point in Model_Agent_Eval_wealth.md):
- Change ticks 0-120000: Opus 5.5 +1037, human +994
- Change ticks 0-180000: Opus 5.5 +1473, human +821


## Arctic 1 (Opus 5, session 1a86968d)

Effort: high

Start state:
- Time: tick 20, 2nd of Jugust 5500, 06:00, paused
- Weather: permanent winter, -22C, clear
- Hicklin: healthy, rest 90%
- Stumpy: sick, rest 97%
- Zimmerman: sick, rest 96%
- All 3: in incoming drop pods, mood 50%, food 80%
- Food: 0 meals, 7 raw (6.3 nutrition)
- Power: none
- Research: no project

Failures:
- Latest reply 10:48:20 UTC at tick 103436: 78 (44 main claude-opus-5, 34 subagents claude-haiku-5-5)

Failures per 1000 ticks:
- Ticks 0-103436: 78 / 103436 = 0.75

Botched construction (save "Opus 5 Arctic.rws", tick 115040; the save keeps botches per 60000 ticks):
- Ticks 0-59999: 3 of 30 builds (Stumpy)
- Ticks 60000-115040: 2 of 37 (before or after tick 103436 not kept)
- Ticks 0-115040: 5 of 67 (7.5%)

Mental breaks (same save):
- Ticks 0-115040: 0 breaks, 0 time below the break line

Wealth (total, recorded every 30000 ticks; same save; human: "Shivalvard.rws", same map and start; every point in Model_Agent_Eval_wealth.md):
- Change ticks 0-90000: Opus 5 +1402, human +1132


## Fable 5.1 Arctic 1

Effort: medium

Failures:
- Save tick: 65000
- Failures in save: 22

Failures per 1000 ticks:
- Ticks 0-65000: 22 / 65000 = 0.34

Botched construction (save "Fable 5.1 Arctic 1.rws", played on to tick 75020; the save keeps botches per 60000 ticks):
- Ticks 0-59999: 2 of 11 builds (Stumpy)
- Ticks 60000-75020: 0 of 24
- Ticks 0-75020: 2 of 35 (5.7%)

Mental breaks (same save):
- Ticks 0-75020: 0 breaks, 0 time below the break line

Wealth (total, recorded every 30000 ticks; same save; human: "Shivalvard.rws", same map and start; every point in Model_Agent_Eval_wealth.md):
- Change ticks 0-60000: Fable 5.1 +1735, human +814


## Opus 5.5 Desert 1 (low effort, session 7c963484)

Effort: low

Start state:
- Biome: desert
- Temperature: 40C to 50C
- Colonists: Skater, Beaver, Isla

Failures:
- Save: "Opus 5.5 Desert 1 (low effort).rws"
- Save tick: 72544
- Failures in save: 27 (12 main claude-opus-5-5, 15 subagents claude-haiku-5-5)

Failures per 1000 ticks:
- Ticks 0-72544: 27 / 72544 = 0.37

Botched construction (same save):
- Ticks 0-72544: 0 of 7 builds (Isla)

Mental breaks (same save):
- Ticks 0-72544: 0 breaks
- Below the minor break line (none reached major or extreme): 7 times, 85275 ticks total, 2 still going at the save
  - Isla: 3 times, 45722 ticks
  - Beaver: 2 times, 25003 ticks
  - Skater: 2 times, 14550 ticks

Wealth (total, recorded every 30000 ticks; same save; human: "Desert map human ref.rws", same map and start; every point in Model_Agent_Eval_wealth.md):
- Change ticks 0-60000: Opus 5.5 +609, human +859


## Opus 5.5 Desert 2 (medium effort, session 71a7bcb0)

Effort: medium

Start state:
- Time: tick 316, 1st of Aprimay 5500, 06:00, paused
- Weather: permanent summer, 43C, clear
- Skater: sick, rest 97%
- Beaver: in pain (little), rest 97%
- Isla: sick, in pain (little), rest 90%
- All 3: mood 51%, food 79%
- Food: 0 meals, 57 raw (51.3 nutrition)
- Power: none
- Research: no project

Failures:
- Save: "Opus 5.5 desert 2 (medium effort).rws"
- Save tick: 225016
- Failures in save: 43 (20 main claude-opus-5-5, 23 subagents claude-haiku-5-5)

Failures per 1000 ticks:
- Ticks 0-225016: 43 / 225016 = 0.19

Botched construction (same save):
- Ticks 0-225016: 5 of 138 builds (3.6%), all in ticks 0-59999
  - Beaver: 3 of 22
  - Isla: 2 of 116

Mental breaks (same save):
- Ticks 0-225016: 0 breaks
- Below the minor break line (none reached major or extreme): 10 times, 66452 ticks total, all Isla

Wealth (total, recorded every 30000 ticks; same save; human: "Desert map human ref.rws", same map and start; every point in Model_Agent_Eval_wealth.md):
- Change ticks 0-210000: Opus 5.5 +1941, human +2510
