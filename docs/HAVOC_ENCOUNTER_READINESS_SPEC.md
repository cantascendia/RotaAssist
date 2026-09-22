# Havoc encounter readiness and non-stationary validation

The objective is an eligible, timely next action in changing dungeon/raid
conditions. Current work removes a known observability defect and measures
existing policies in movement/add-wave scenarios. It does not promise a global
maximum over unknown future events or establish live dungeon/raid DPS.

## Action applicability

`IsSpellInRange` can be unavailable for spells without a target-range check.
The independent observer must not require that API to return true for every
player-centered area action. Nor may it treat every nil result as in range.

- Preserve native true/false range results exactly. Unknown targeted, cone,
  movement and ground-targeted actions stay unknown.
- For Havoc Immolation Aura, Blade Dance and Death Sweep only, if the native
  result is nil and `C_Spell.SpellHasRange` publicly returns false, a public
  in-range melee probe on the current hostile live target provides a conservative
  applicability witness. Registry IDs are versioned against pinned SimC source.
- A false melee probe is not proof that an eight-yard area cannot hit; return
  unknown. Do not infer exact AoE hit count, line of sight, facing, movement safety
  or readiness from this witness. Cooldown/learning/usability gates still apply.
- Keep generic `GetSpellRange` and per-spell targetable counts unchanged; expose
  separate `GetActionRange` and provenance for the independent evaluator.
- Every lookup uses the current target snapshot; target changes invalidate its
  cache. Out-of-spec, disabled, absent, erroneous and restricted inputs do not
  produce a synthetic positive witness.

## Non-stationary research

Freeze current Fel-Scarred and Aldrachi policies before testing. Compare each
against the complete pinned reference APL under identical movement, add-wave
and combined scenarios. Verify the simulator accepted the encounter events,
preserve inputs/raw hashes and warnings, and report losses. These synthetic
proxies are not specific live bosses, actual Mythic+ routes or addon execution.

## Acceptance

Add-only tests (Test-Lock scenario 3) cover native/area/unknown decisions, secret
values, target changes, API failure, specialization and real observer integration.
Generated properties must check that only explicit proof produces a true witness.
Behavioral mutation detection must be at least 80%. Existing policy hashes and
default-off experimental setting remain unchanged until performance is qualified.
