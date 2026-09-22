# Aldrachi Havoc policy research

The shipped candidate is an independently authored priority policy, selected
before its final holdout. It is not a full damage optimizer. No personal export
is needed in the addon. A complete current talent snapshot selects Aldrachi or
Fel-Scarred; unavailable or conflicting hero evidence clears the selection.

## Reproducible evidence

SimulationCraft source: [`774babde5ddc7c5fc9f1abb129b473f8a076df70`](https://github.com/simulationcraft/simc/tree/774babde5ddc7c5fc9f1abb129b473f8a076df70).
Mechanics: [Demon Hunter implementation](https://github.com/simulationcraft/simc/blob/774babde5ddc7c5fc9f1abb129b473f8a076df70/engine/class_modules/sc_demon_hunter.cpp).
Profile: [MID2 Aldrachi Reaver](https://github.com/simulationcraft/simc/blob/774babde5ddc7c5fc9f1abb129b473f8a076df70/profiles/MID2/MID2_Demon_Hunter_Havoc_Aldrachi_Reaver.simc).

Engine, original profile, generated inputs and raw result hashes are retained
in `holdout.json`. `artifact-verification.json` records matching hashes for all
12 final raw reports and generated input profiles. Absolute raw paths refer to
this workspace's `dist/research/aldrachi-order/`; raw reports are not in the addon
ZIP. Engine 1210-01 models WoW 12.1.0.69875; these pins do not establish that its
mechanics match every subsequent live hotfix.

Four searches tested 12 initial variants, 70 structure variants, 11 burst-window
variants and 188 order variants (counts within each search, not globally unique).
The burst-window experiment failed to improve its starting policy; that outcome
is retained. Final order screening used 150 iterations and seed 20261025, followed
by eight finalists at 1000 iterations and seed 20261026. Selection maximized the
minimum DPS ratio of the one/five-target 120-second discovery cases. Only then
was the candidate frozen and evaluated on seed 20261027.

| Targets | 120 seconds, candidate / reference | 300 seconds, candidate / reference |
|---|---:|---:|
| 1 | 96.49% | 96.51% |
| 2 | 96.87% | 97.27% |
| 5 | 96.35% | 97.23% |

Each final side requests 3000 iterations; the report contains 2999 DPS samples,
for 35988 samples across 12 runs. Gear, talents, items and encounter settings are
identical within each comparison. Reference APL keeps its fragment pickup and
target-management behavior. The candidate does not model all of those actions.
The simulator's unverified Rune of Unleashed Fire warning is preserved.
Uncertainty uses three times the sum of marginal standard errors, without
assuming independent random streams. All six candidate means lose to reference.

The full-information SimC ratios are **not addon DPS measurements**: runtime
secret values may leave the independent decision ambiguous and cause fallback.
This research covers one reference build, fixed stationary encounters and
perfect execution. Neither all builds, live enemy geometry, movement, proc
observation coverage nor superiority to Hekili has been validated. Independent
mode remains explicitly experimental and off by default.

## Repeat the search

Use the pinned engine/profile paths above as `ENGINE` and `PROFILE`, and distinct
output directories. Scripts verify their hashes and fail on drift.

```text
python scripts/benchmark_aldrachi.py --simc ENGINE --profile PROFILE --fel research/independent-policy/candidate.json --output dist/research/aldrachi-policy
python scripts/refine_aldrachi.py --simc ENGINE --profile PROFILE --start research/aldrachi-policy/initial-candidate.json --output dist/research/aldrachi-refined
python scripts/refine_aldrachi.py --simc ENGINE --profile PROFILE --start research/aldrachi-policy/structure-candidate.json --family burst --rounds 1 --discovery-seed 20261022 --holdout-seed 20261023 --output dist/research/aldrachi-burst
python scripts/reorder_aldrachi.py --simc ENGINE --profile PROFILE --start research/aldrachi-policy/structure-candidate.json --output dist/research/aldrachi-order
python scripts/mutate_aldrachi.py --output dist/research/aldrachi-mutations
```

`candidate.json` is the sole source for the shipped registered Lua policy.
`export_registered` in `scripts/export_independent_policy.py` creates the additional
hero policy without changing the frozen Fel-Scarred export. Tests compare the
shipped bytes, policy hash and action/predicate ordering, then compare 60 generated
complete snapshots against an independent Python priority interpreter.
