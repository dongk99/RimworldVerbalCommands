# Mental breaks: what each one does

Source: RimWorld Wiki, "Mental break" (revision 184203). Not checked in a live game.

One file per event, description only. The chance of each break for a pawn is in the mental break
watch alert (src\VerbalCommands\MentalBreakWatch.cs), not here. `general.md`: what every break shares
(control, arrest, catharsis).

Ask for one with the router sentence "what does BREAK do." (BREAK: the file name, or the break's name as an
alert or the game says it); "list breaks." lists them (only the DLCs in this game).
Game defs: the defName of the game's MentalBreakDef / MentalStateDef that the file describes, so a name the
game prints (sitting_alone, wandering_in_psychosis) finds its file (src\VerbalCommands\MentalBreakTips.cs).
Core, Royalty, Ideology, Biotech defs: the 1.6 Defs XML (MentalStates_*.xml). Anomaly defs: the 1.6 decompile
(RimWorld\MentalStateDefOf.cs, MentalBreakDefOf.cs; EntityKiller by its class MentalState_EntityKiller, a
slaughter-things state). `?`: the defName is not known here (Anomaly is not installed), so only the file name
finds it.

## Minor mood breaks

| Event | File | DLC | Game defs |
|---|---|---|---|
| Food binge | `food_binge.md` | none | Binging_Food |
| Sad wander | `sad_wander.md` | none | Wander_Sad, WildDecree |
| Hide in room | `hide_in_room.md` | none | Wander_OwnRoom |
| Insulting spree | `insulting_spree.md` | none | InsultingSpree |
| Targeted insulting spree | `targeted_insulting_spree.md` | none | TargetedInsultingSpree |
| Crying | `crying.md` | Biotech | Crying |
| Giggling | `giggling.md` | Biotech | Giggling |
| Dark visions | `dark_visions.md` | Anomaly | ? |

## Major mood breaks

| Event | File | DLC | Game defs |
|---|---|---|---|
| Social drug binge | `social_drug_binge.md` | none | Binging_DrugMajor |
| Psychotic wandering (daze) | `psychotic_wandering.md` | none | Wander_Psychotic, Wander_Psychotic_Short |
| Tantrum | `tantrum.md` | none | Tantrum |
| Targeted tantrum | `targeted_tantrum.md` | none | TargetedTantrum |
| Bedroom tantrum | `bedroom_tantrum.md` | none | BedroomTantrum |
| Sadistic rage | `sadistic_rage.md` | none | SadisticRage |
| Corpse obsession | `corpse_obsession.md` | none | CorpseObsession |
| Insane ramblings | `insane_ramblings.md` | Anomaly | ? |
| Entity slayer | `entity_slayer.md` | Anomaly | EntityKiller |
| Humanity break | `humanity_break.md` | Anomaly and Ideology | HumanityBreak |

## Extreme mood breaks

| Event | File | DLC | Game defs |
|---|---|---|---|
| Berserk | `berserk.md` | none | Berserk |
| Fire starting spree | `fire_starting_spree.md` | none | FireStartingSpree |
| Hard drug binge | `hard_drug_binge.md` | none | Binging_DrugExtreme |
| Catatonic breakdown | `catatonic_breakdown.md` | none | Catatonic |
| Jailbreaker | `jailbreaker.md` | none | Jailbreaker |
| Slaughterer | `slaughterer.md` | none | Slaughterer |
| Murderous rage | `murderous_rage.md` | none | MurderousRage |
| Run wild | `run_wild.md` | none | RunWild |
| Given up and leaving | `given_up_and_leaving.md` | none | GiveUpExit |
| Crisis of belief | `crisis_of_belief.md` | Ideology | IdeoChange |
| Entity liberator | `entity_liberator.md` | Anomaly | ? |
| Terrifying hallucinations | `terrifying_hallucinations.md` | Anomaly | ? |

## Special states (not from mood)

| Event | File | DLC | Game defs |
|---|---|---|---|
| Confusion | `confusion.md` | none | WanderConfused |
| Social fighting | `social_fighting.md` | none | SocialFighting |
| Fleeing in panic | `fleeing_in_panic.md` | none | PanicFlee |
| Fleeing fire | `fleeing_fire.md` | Biotech | PanicFleeFire, FireTerror |
| Manhunter | `manhunter.md` | none | Manhunter |
| Manhunter (permanent) | `manhunter_permanent.md` | none | ManhunterPermanent |
| Roaming | `roaming.md` | none | Roaming |
| Berserk (short) | `berserk_short.md` | Anomaly | BerserkShort |
| Manhunter (blood rain) | `manhunter_blood_rain.md` | Anomaly | ManhunterBloodRain |
| Cube sculpting | `cube_sculpting.md` | Anomaly | CubeSculpting |
