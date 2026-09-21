# Independent Havoc policy experiment — 2026-09-22

Astra authored the decision core, policy generator, search and tests. This is an
independent policy experiment, **not proof of maximum DPS or superiority to Hekili**.

## Actual result

The selected own policy lost to the pinned stock SimulationCraft policy in every
held-out scenario. Its 98.69% discovery score did not qualify it for production
head replacement. The released observer can determine a policy action without a
Blizzard recommendation, but its result remains diagnostic.

| Targets | Duration | Reference DPS | Own-policy DPS | Difference |
|---|---:|---:|---:|---:|
| 1 | 120 s | 276,184 | 272,252 | -1.42% |
| 1 | 300 s | 252,941 | 247,722 | -2.06% |
| 5 | 120 s | 539,832 | 531,872 | -1.47% |
| 5 | 300 s | 497,277 | 483,961 | -2.68% |

Exact values, raw-report hashes, profile hashes and sampling errors are in
`holdout.json`. Eight runs produced **39,992 actual DPS samples** (4,999 each).
Requested iterations were 5,000, threads 2, fixed duration, seed 20260925.
The standard-error combination assumes independent differences; it is a
screening statistic, not a paired-seed confidence interval. All observed losses
are larger than three times that reported error.

## Shared policy and provenance

`candidate.json` is the frozen source. `export_independent_policy.py` serializes it
into the addon; `simc_lines` exports those same ordered conditions for SimC.
The Python reference evaluator and actual Lua evaluator agree on generated
full-information snapshots. This verifies priority/predicate semantics, not all
simulator readiness, timing, movement or damage mechanics. SimC supplies its own
execution/resource/cooldown rules; the live observer requires public readiness.

The fixed profile is MID2 Demon Hunter Havoc Fel-Scarred, including its gear and
talents. Engine: SimC 1210-01, WoW 12.1.0.69875 Live, source
`774babde5ddc7c5fc9f1abb129b473f8a076df70`. Engine/profile/policy hashes are in the
holdout report. No other hero build or player's equipment is certified by this.

Discovery used seed 20260924, 120 seconds, 1 and 5 targets, 500 requested
iterations. Parameter searches retained basic, burst-aware and refined families;
three local ordering rounds evaluated 124 candidate entries. Selection maximized
the worse of the two target-count DPS ratios. The candidate was then frozen
before measuring seed 20260925 and the added 300-second duration. A frozen
holdout directory rejects replacement by a different candidate. Cached runs
verify profile/raw hashes, request identity and recomputed summary statistics.

The benchmark preserves stock gear, precombat and item/consumable lists. The own
policy lacks stock's virtual fragment pickup and auto-attack retargeting actions.
Thus the full-reference comparison includes those action-envelope differences;
it does **not** isolate only skill ordering. No weaker reference was substituted
to claim a victory. Rune of Unleashed Fire has a documented simulator warning
about proc-target assumptions, retained in the report.

## Live observation boundary

The observer reads publicly available resource, range, learned/usable skills,
cooldowns, charges and selected aura observations. Enemy population supports a
lower bound: `>= 3` may be established without pretending the total equals 3.
Unknown earlier choices block a different later choice. Hidden-state completions
are tested to agree whenever the evaluator reports a definite action.

The simulator's per-ability Demonsurge availability flags are internal state.
The pinned source creates distinct quiet buffs using one placeholder spell ID;
that is not evidence for distinct publicly readable game auras. We deliberately
leave these, and unmapped aura facts, unknown. A result of `decided` means only
that all possible earlier policy choices agree; it does not mean optimal DPS.
The observer may frequently abstain under Midnight's restricted combat state.

The runtime remains `observation_only`, `performanceQualified=false`. Inspect
the borrowed diagnostic snapshot through
`RotaAssist:GetModule("SmartQueueManager"):GetIndependentStatus()` while debugging.
It exposes status, candidate spell IDs, missing facts and policy hash. No new
user-facing control or automatic head replacement is claimed. Target changes,
invalid target states and inapplicable profiles clear the diagnostic.

## Primary sources

- [SimulationCraft priority-list semantics](https://github.com/simulationcraft/simc/wiki/ActionLists)
- [SimulationCraft conditional expressions](https://github.com/simulationcraft/simc/wiki/Action-List-Conditional-Expressions)
- [Pinned Demon Hunter simulator source](https://github.com/simulationcraft/simc/blob/774babde5ddc7c5fc9f1abb129b473f8a076df70/engine/class_modules/sc_demon_hunter.cpp)
- [Blizzard's combat-state access explanation](https://news.blizzard.com/en-us/article/24246290/combat-philosophy-and-addon-disarmament-in-midnight)

Upstream simulator/source/profile stay external local test fixtures; they are not
redistributed in the MIT addon. The generated research policy is authored here.
See `docs/INDEPENDENT_POLICY_SPEC.md` for the implementation and acceptance contract.

## Reproduction

Run scripts from the repository root; the pinned engine/profile are local inputs:

```powershell
python scripts/search_independent_policy.py --simc <simc.exe> --profile <stock.simc> --output dist/research/independent-policy --family burst
python scripts/search_independent_policy.py --simc <simc.exe> --profile <stock.simc> --output dist/research/independent-policy --family refined
python scripts/optimize_independent_order.py --simc <simc.exe> --profile <stock.simc> --start dist/research/independent-policy/search-results-refined.json --output dist/research/independent-policy --rounds 3
python scripts/validate_independent_policy.py --simc <simc.exe> --profile <stock.simc> --selection dist/research/independent-policy/order-search.json --output dist/research/independent-policy --evidence research/independent-policy
python scripts/export_independent_policy.py research/independent-policy/candidate.json addon/Data/IndependentPolicy.lua
python -m pytest tests/test_independent_policy.py -q
python scripts/mutate_independent_policy.py --output dist/research/independent-policy/mutations
```

Still required: movement/add-wave/interruption scenarios, wider builds and gear,
qualified observed-state policies, actual retail observation coverage and frame
time, and in-client combat validation. A completely known battlefield and a
globally highest-DPS next action have **not** been implemented or demonstrated.
