# Havoc movement and reinforcement-wave validation

These tests extend the stationary baseline with changing availability and target
population. They are synthetic encounter proxies, not actual Mythic+ runs or
raid-boss replays. The two existing hero policies were frozen before the first
run and were not tuned on these results.

| Hero | Movement | Add waves | Movement and add waves |
|---|---:|---:|---:|
| Fel-Scarred | 97.54% | 92.75% | 91.82% |
| Aldrachi Reaver | 97.49% | 94.71% | 95.82% |

Numbers are candidate/reference mean simulated DPS. Each side uses the identical
pinned hero profile, items and encounter definition, 180 seconds and 3000
requested iterations. Each returns 2999 DPS samples: 35988 across 12 runs.
One base enemy remains throughout; four adds are scheduled at 25 seconds and
every 60 seconds for 20 seconds. Movement begins at 15 seconds and repeats every
30 seconds over 20 yards. This is not a health-based multi-pull dungeon route.
SimC's default add-health/target behavior is part of this fixed synthetic model.

Six separate 90-second reference traces verify the configured events were
instantiated **and executed**. They do not add statistical DPS samples. Input,
raw report and trace hashes are verified in `artifact-verification.json`.
`holdout.json` retains commands, seed, model warning and marginal standard errors;
the conservative difference bounds use three times the sum of standard errors.
All six candidate means remain below reference. The simulator's unverified Rune
of Unleashed Fire assumption is preserved. Live API restrictions, player input
latency and errors, boss-priority damage and survival are not measured here.

## Action-range fix

The independent observer previously required a true native target-range result
even for radial spells with no target-range check. `GetActionRange` now accepts
a separate current-target melee witness for Havoc Immolation Aura, Blade Dance
and Death Sweep when `SpellHasRange` publicly returns false. Native true/false
results take precedence. A false or unknown melee result yields unknown, not a
claim that every enemy is outside the larger area. Target changes invalidate the
snapshot. No exact hit count, facing or line-of-sight proof is implied.

The evidence improves runtime eligibility; it is not a new simulated DPS gain.
The declarative policy files and experimental default-off setting are unchanged.
An end-to-end test verifies that an eligible area action reaches the actual main
queue and that target loss clears it. Eight focused mutations are detected;
the ten earlier Aldrachi mutations also pass after the observer call changed.
The initial attempt to remove a redundant local specialization guard survived
because the upstream configuration check still removed its melee probe. The
final specialization mutation disables that actual upstream check; assertions
were unchanged.

## Primary sources and reproduction

- [Blizzard generated spell API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua)
  distinguishes a spell having a target range from a specific target being in it.
- [Pinned SimC class implementation](https://github.com/simulationcraft/simc/blob/774babde5ddc7c5fc9f1abb129b473f8a076df70/engine/class_modules/sc_demon_hunter.cpp).
  The executable spell queries in `spell-ranges.txt` and `area-spells.txt`
  establish five-yard Chaos Strike/Annihilation and eight-yard radial effects.
- [SimulationCraft encounter events](https://github.com/simulationcraft/simc/wiki/RaidEvents)
  describes movement and periodic add events; actual pinned-engine traces are
  the acceptance evidence that these definitions ran.
- [Blizzard's combat-data restrictions](https://news.blizzard.com/en-us/article/24246290/combat-philosophy-and-addon-disarmament-in-midnight)
  explain why displayable combat values may be unavailable for decisions.

```text
python scripts/benchmark_havoc_encounters.py --simc dist/research/simc/extract/simc-1210.01.774babd-win64/simc.exe --output dist/research/havoc-encounters/holdout
python scripts/mutate_action_range.py --output dist/research/havoc-encounters/mutations-confirmed
```

## Real-instance qualification remains open

Qualifying actual dungeon/raid advice requires measured public-fact coverage,
decision latency, target switches/deaths, channel completion, changing pack
lifetimes, boss downtime, resource/cooldown carryover between pulls and tested
builds/gear. Compare total damage and required priority-target damage under the
same scenario and execution assumptions. Surviving mechanics must be part of
the objective; unsafe movement or avoidable channel clipping is not a DPS win.
Current tests and simulations establish neither this coverage nor a globally
optimal next action under hidden state and unknown future events.
