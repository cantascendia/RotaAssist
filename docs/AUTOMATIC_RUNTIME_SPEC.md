# Automatic in-game context for every player

Product direction: install the addon and automatically discover the current
character and target. No per-user SimC export or companion is required for the
real-time recommendation path. Do not confuse this with validated optimal DPS
models for every specialization; those models do not yet exist in this project.

Add a spec-independent spellbook catalog of learned, active, non-passive spells,
including the spellbook's current override ID. Exclude off-spec/future spells and
flyouts. Bound scans to 32 skill lines and 2048 slots. Check secret values before
using fields. Track completeness separately from the observed subset. Rebuild on
world entry, spellbook, specialization and talent changes, never every frame.

Feed the catalog into character spell metadata and target range observations.
All specs receive per-spell current-target range checks; missing Havoc context
must not disable generic range collection. Include current native rotation IDs
as additional observations, not as an independent damage model. Any new current
recommendation gets an on-demand guarded range check.

Provide a per-spell lower bound of unique living hostile engaged units that are
targetable by that spell, including the selected target before pull. Unknown
identity, hostility, combat state or range never becomes a positive count.
Spell targetability is not the number hit by a cleave/cone/target-centered AoE.
Never substitute these counts for AoE geometry in the existing Havoc policy.

Target/build changes invalidate ranges and counts immediately. Reuse per-spell
result buffers and bound them to 256 IDs; cache for the current target sample.
Queue filtering must use these live range facts for every spec, even without an
APL. Reject explicit out-of-range actions without manufacturing an alternative
optimal action. Preserve unknown range and existing assisted fallback behavior.

Test-Lock scenario 3: new catalog, secret-value, off-spec, override, invalidation,
bounded-scan and queue integration tests across multiple synthetic specs;
generated unique-enemy invariants and behavior mutations. Offline tests are not
client acceptance or proof of universal maximum output.
