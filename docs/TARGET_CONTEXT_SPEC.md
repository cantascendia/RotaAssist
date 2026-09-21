# Target-aware combat context

Owner: Astra. Target: Midnight Interface 120100. This change uses the existing
Lua patterns and Test-Lock skills; no project CONSTITUTION.md is present.

## Required behavior

1. Target changes invalidate recommendation caches, queued predictions and all
   target-specific inferred windows immediately. No GUID or secret comparison is
   needed: PLAYER_TARGET_CHANGED supplies a new local target generation.
2. Count only public, living, attackable enemies that are the current target or
   publicly in combat and pass a learned Havoc melee probe's spell-range check.
   Visible distant/idle nameplates must not inflate the count. The current target
   must not be counted twice. Unknown identity, hostility, engagement or range
   remains unknown. This is a nearby-enemy lower bound, not an exact AoE hit count.
3. Current-target per-spell range is separate from enemy count. A public false
   rejects that action from local prediction. Nil/secret/error is unknown, never
   converted into true or false. Self-centered spells can return nil.
4. Read selected non-secret player/target auras with guarded APIs. Never treat
   a nil GetUnitAuraBySpellID result as proven absence. The target's Essence Break
   observation replaces the target-agnostic cast timer in the live queue.
5. Negative target-count/window conditions cannot pass solely because a value is
   unknown. Future casts may create explicitly simulated windows; these remain
   predictions. Public aura time limits must expire as prediction time advances.
6. No target or a publicly dead/friendly target clears offensive predictions.
   An unknown target state must not create a local offensive recommendation.
7. All events use EventHandler. No engine-to-UI coupling; reuse snapshot buffers.
   Tests cover target swaps, distant/idle/dead units, duplicates, protected values,
   aura expiration, range rejection, lifecycle and end-to-end queue invalidation.

## Evidence boundary

Pinned Blizzard-generated API source is recorded in research/target-context/.
C_Spell.IsSpellInRange accepts a unit token and may return nil. It does not
describe cone angle, line of sight, hitbox overlap, or target-centered clusters.
The current reference probe is learned Chaos Strike/its override for Havoc.
No invented coordinates, hidden-state extraction or universal hit-count claim.

These changes improve observable context, not prove a globally optimal rotation.
The full goal still requires supported talent/encounter models, independent DPS
evaluation of the addon policy, and a retail client for combat validation.
