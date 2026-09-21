# Pinned SimC action traces for Havoc replay

The exporter [scripts/simc_trace.py](../../scripts/simc_trace.py) runs the same
official SimC `1210-01` binary and Fel-Scarred Havoc MID2 profile pinned in
[the benchmark provenance](README.md). These are **single simulated fights for
structural replay**, separate from the 20-run DPS experiment. They cannot
measure addon DPS, live Midnight API behavior, or player performance.

## Source-backed capture

The pinned SimC source [parses](https://github.com/simulationcraft/simc/blob/774babde5ddc7c5fc9f1abb129b473f8a076df70/engine/sim/sim.cpp)
`json=PATH,version=2.0.0,full_states=1`. Its [JSON writer](https://github.com/simulationcraft/simc/blob/774babde5ddc7c5fc9f1abb129b473f8a076df70/engine/report/json/report_json.cpp)
emits the action sequence with time, action ID/name/target, buffs, cooldowns,
target debuffs, and resources. The [snapshot constructor](https://github.com/simulationcraft/simc/blob/774babde5ddc7c5fc9f1abb129b473f8a076df70/engine/player/player_collected_data.cpp#L33-L80)
reads current resources, active non-quiet buffs, `down()` cooldowns, and active
non-quiet target debuffs. It stores `cooldown.charges` as `stacks`: **this is the
configured maximum, not current available charges**. Some indefinite buff or
debuff `remains` values serialize as a very large negative sentinel and must not
be used as a numeric duration.

For ordinary selected actions, [player.cpp](https://github.com/simulationcraft/simc/blob/774babde5ddc7c5fc9f1abb129b473f8a076df70/engine/player/player.cpp#L7388-L7403)
calls `sequence_add` after starting the action's line cooldown and queueing it;
the [queued execution path](https://github.com/simulationcraft/simc/blob/774babde5ddc7c5fc9f1abb129b473f8a076df70/engine/action/action.cpp#L69-L88)
also snapshots before `action->execute()`. Thus the row is a pre-execution state,
but is not necessarily a pristine pre-decision state. Precombat and special
action paths require separate interpretation. The trace also contains automatic
attacks, items, potion, fragment pickups, and occasionally `wait` rows without
an action ID. Replay must explicitly select comparable foreground spell rows.

Rows retain SimC's original shape at
`sim.players[0].collected_data.action_sequence`, with precombat in the sibling
`action_sequence_precombat`. `sim.options` includes seed, time, target count,
threads, game build; the player includes its static talent string. `provenance`
stores the full source commit, executable/profile/APL hashes, raw JSON/log
hashes, and exact command. The exporter rejects mismatched build/options and
unknown warnings. Observed Rune of Unleashed Fire model uncertainty remains in
`logs`. Missing current charges, GCD remaining, target health, and per-rule APL
evaluation are flagged in `coverage` and are never filled with zero.

Run the final matrix with the pinned executable and profile from `README.md`:

```powershell
python scripts/simc_trace.py `
  --simc dist/research/simc/extract/simc-1210.01.774babd-win64/simc.exe `
  --profile dist/research/simc/official-MID2_Demon_Hunter_Havoc.simc `
  --output-dir dist/research/simc/trace `
  --targets 5 --duration 120 --seed 20260923
```

Each actual run used one SimC thread, `iterations=1`, `log=1`,
`log_spell_id=1`, fixed fight length, and `full_states=1`. The ignored local
outputs are:

| Trace file under `dist/research/simc/trace/` | Combat rows | Wait rows | SHA-256 |
| --- | ---: | ---: | --- |
| `stock-full-1t-120s-seed20260922.trace.json` | 140 | 0 | `8f74ea5a657874a6df6cbbd23b2e2ae4bb8b41be22d59aae4e7de85d61bd5233` |
| `stock-full-1t-120s-seed20260923.trace.json` | 133 | 0 | `7b955c57d266286f6abc265b11554edb23d5b5b50e9c40a80be819be94f60c67` |
| `stock-full-5t-120s-seed20260922.trace.json` | 143 | 1 | `5e874a063a8e0843a85c878540802fb612625d0af3e7f9dc743a0f41ed85f249` |
| `stock-full-5t-120s-seed20260923.trace.json` | 137 | 0 | `f026814699898137e48653cd1e437a73d9f6b201ff6e8c96787672b2752ed196` |
| `stock-full-1t-300s-seed20260923.trace.json` | 321 | 4 | `62d34c7645507706266dd2f6d162f2e561bc1e49cf2d8ad6bb2af228212e7986` |

The shorter 30-second 1- and 5-target traces remain alongside this matrix for
fast parser development. The matrix contains 874 combat sequence rows, including
five wait rows; rows are not independent DPS samples. A next-action agreement
comparison against the addon would show how often two different policies choose
the same spell when supplied a subset of the same simulated state. It must
preserve unknown inputs and report coverage/exclusions separately.

The additive validator is `python -m pytest tests/test_simc_trace.py -q`.
