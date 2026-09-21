# Havoc model validation — 2026-09-22

Astra owns implementation, research, review and delivery from this phase's final
handoff onward, following the user's updated instruction. Earlier changes from
Sol were preserved and reviewed.

## Corrections shipped in rc.3

The pinned SimulationCraft revision is
[`774babde5ddc7c5fc9f1abb129b473f8a076df70`](https://github.com/simulationcraft/simc/tree/774babde5ddc7c5fc9f1abb129b473f8a076df70),
whose generated spell data targets WoW **12.1.0.69875**.

- Havoc Demon's Bite generates 25 Fury and Felblade 15 in the base model,
  replacing the previous 40/40. Talent procs and incidental autoattack gains are
  not folded into these fixed amounts.
- Eye Beam's base fallback cooldown is 30 seconds, Metamorphosis 120 and the
  shared Felblade cast 12. Essence Break APL metadata consistently says 40.
  These are base fallbacks, not a complete talent/haste cooldown model.
- Glaive Tempest 342817 is a background effect in the pinned class model, not
  a standalone cast. Its three manual APL rules were removed and the ID was
  added to the passive blacklist. The previous three blacklist IDs remain.
- A readable `UnitPowerMax` supplies the prediction's resource cap after secret,
  type and value checks. A trace build has 170 Fury, but that number is not
  hardcoded. When the maximum is unavailable, the conservative fallback never
  lowers an already observed amount to the stale static 120 cap.

The repository's `research/havoc-model/AUDIT.md` and `data.json` contain pinned
source locations, hashes, baseline facts and remaining gaps. This is a partial
audit of Havoc, not a validation of every supported specialization.

## Independent replay

Five actual single-iteration full-state SimulationCraft traces cover 120-second
single-target and five-target fights with seeds 20260922/20260923, plus a
300-second single-target fight. They contain **874 sequence rows, including five
wait rows**. These trace runs are separate from rc.2's statistical DPS experiments.

`scripts/export_havoc_model.lua` exports the real loaded addon data.
`scripts/replay_havoc.lua` evaluates the actual APLEngine against each same-row
pre-action snapshot, comparing the preserved rc.2 addon with rc.3. Full-state
traces and reports stay outside the install ZIP; the compact matrix and report
hashes are tracked in `research/havoc-model/replay-results.json`.

Both revisions and both addon profiles mapped the same **733 action rows**,
returned a prediction on **605**, and agreed exactly or by the registered form
override on **307** (41.9% of mapped rows). They returned no prediction on 128.
The checked declared-cost/active-cooldown violations were zero, under the narrow
checks described below. There was no change in same-row choices. This is expected
for many forward-simulation fixes because each replay row restores the reference
state and uses depth one; it provides no evidence of a DPS improvement.

An initial replay-tool defect mutated the lookup table while iterating it and
skipped Death Sweep rows in one revision. The final harness snapshots the keys
before adding override IDs, with an executable regression test. The paired
matrix records equal row sets rather than comparing changing denominators.

The replay uses a nil head and depth one. It does not measure the production
queue behind Blizzard's recommendation, damage, or multi-step prediction quality.
Only uniquely trace-observed name aliases connect differing cooldown IDs. A
cooldown's `stacks` field is configured maximum charges, not available charges.
The harness never interprets it as available charges. Active Metamorphosis maps
to `inMeta`; Essence Break must be on the action's target. The synthetic Demonic
step window is not equated with the full Metamorphosis aura duration.

Missing learned-spell coverage, current charges, window timing and live API
availability prevent interpreting action agreement as a rotation quality score.
Declared-cost/cooldown checks only test those modeled prerequisites; a zero count
does not prove every recommendation is usable or optimal.

## Next evidence needed

The priority list still lacks complete talent, proc, channel and haste modeling.
Same-row source-data corrections must not be promoted as a DPS improvement
without evaluating the resulting policy under matching encounter assumptions.
Neither this replay nor the independent stock SimC DPS numbers establish that
RotaAssist matches or exceeds historical Hekili.

The local AddOns installation can be verified, but this machine lacks the retail
`Wow.exe`. Client loading, combat transitions, rendering and frame time remain
unverified. The package continues to preserve unknown protected state and use a
valid Blizzard suggestion as its primary action.
