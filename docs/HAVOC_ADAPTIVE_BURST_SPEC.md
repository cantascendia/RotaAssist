# Adaptive Havoc area-burst policy

The dynamic encounter baseline exposes losses not visible on stationary targets.
Improve immediate action priority using current enemy evidence before attempting
to hold cooldowns for unknown future pulls. Do not invent next-pack timing or
target lifetime from inaccessible combat values.

- Search independently authored variants of the existing hero policies. Test
  whether earlier Immolation Aura above an enemy threshold improves damage in
  reinforcement windows. Preserve original frozen files and action semantics.
- Include unchanged policies in discovery. Rank eligible variants by their worst
  ratio to the full reference across single-target, waves and movement+waves.
  Reject a candidate if discovery single-target performance loses over 1% to the
  prior policy. Separate discovery, finalist confirmation and final holdout seeds.
- Export the selected policy from the exact source simulated. Keep an explicit
  selected-hero registry; complete talent proof is required before using it.
  Existing policy selection remains a fallback if no adaptive policy is loaded.
- Runtime active_enemies remains public melee-range evidence or a lower bound,
  never an exact fabricated count. Unknown state uses the existing consensus
  evaluator. No new main-slot automatic promotion or secret-value arithmetic.
- Retain all selected/discarded results. A relative improvement is not proof of
  beating the reference, all builds, real Mythic+ routes or real-client DPS.
- Additive tests (Test-Lock scenario 3) validate source/export parity, hero
  selection, threshold/boundary decisions and unknown evidence. Include generated
  properties and targeted behavior mutations at the project gate (>=80%).

## Burst replacement correctness

The current replacement registry also omits Abyssal Gaze (452497), the enhanced
Eye Beam action (198013). A publicly confirmed replacement must survive learned
filters, share the Eye Beam cooldown/soft-block identity, and receive the selected
Demonic forward transition. A static pair alone must not prove it is currently
active. A successful replacement cast must use its learned base's cooldown
metadata when only the base is in the whitelist. Preserve channel treatment.
