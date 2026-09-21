# Havoc Demonsurge state evidence

Mechanic source: [pinned SimulationCraft class implementation](https://github.com/simulationcraft/simc/blob/774babde5ddc7c5fc9f1abb129b473f8a076df70/engine/class_modules/sc_demon_hunter.cpp).
The addon implementation is independently authored; no upstream engine/APL code
is packaged. Source SHA-256 and simulator executable/profile hashes are recorded
in `verification.json`.

The pinned model refreshes all virtual surge flags on manual Meta, refreshes the
two spender flags through Demonic even inside Meta, and consumes individual flags
when their actions execute. These are virtual flags sharing a placeholder, not
distinct observable client aura IDs. Talent 452402 is Demonsurge; 213410 is Demonic.
Abyssal Gaze uses 452497. The 20/5-second conservative horizons reuse the earlier
talent-transition audit. Hasted channel extensions and later duration modifiers
are deliberately not inferred by this tracker.

Four actual `debug=1` simulator runs use the fixed MID2 Fel-Scarred build, 180s,
one/five targets and seeds 20261012/20261013. The validator extracts action
executions and actual virtual flag gain/loss events, grouping equal timestamps.
The real addon Lua tracker replays those casts; supplied Meta state is the
simulator's public ground truth. No flag values are injected into the tracker.

Across 633 event-time snapshots, 628 cast-model values and 393 public-form-absence
values match the reference; 878 values remain unknown. Assertions are correlated
along four trajectories and are not independent performance samples or a live
observability percentage. Raw logs, commands and semantic fixtures remain in
`dist/research/havoc-surge/traces`. One compact factual fixture is committed for
regression coverage. Repeated debug runs have identical semantic fixtures but
different raw log hashes due to runtime diagnostics.

Reproduce:

```powershell
python scripts/validate_havoc_surge.py --simc <pinned-simc.exe> --profile <MID2_Demon_Hunter_Havoc.simc> --output dist/research/havoc-surge/traces
python scripts/mutate_havoc_surge.py --output dist/research/havoc-surge/mutations
```

Additional tests cover secret inputs, interrupted observation, duplicate casts,
event lifecycle, talent selection, form cancellation, conservative expiry and the
real independent observer. All tests are additive. Sixty generated temporal cases
ensure a consumed flag cannot become available through time/unrelated casts.

This does not validate client event ordering, hidden aura access, unseen event
loss, all gear/talent configurations or DPS. Default independent recommendation
mode and the frozen policy remain unchanged; Aldrachi is not covered by this model.
