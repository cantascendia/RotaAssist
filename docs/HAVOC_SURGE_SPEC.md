# Havoc burst-state tracking

Scope is Havoc Fel-Scarred, not all specializations. The pinned SimC engine
774babde5ddc7c5fc9f1abb129b473f8a076df70 models per-action Demonsurge charges as
virtual flags. No real aura ID will be invented for those flags.

## Contract

- Track model-derived flags for Annihilation, Death Sweep and Immolation Aura
  from public player cast-success events and a complete current talent snapshot.
  Require selected Demonsurge. Eye Beam additionally requires selected Demonic.
- Manual Metamorphosis arms all three. Eye Beam/Abyssal Gaze rearm the two
  spenders, including inside an existing transformation; they do not rearm Aura.
  Successful matching casts consume only their own flag, including base aliases.
- Use conservative validity horizons: manual Meta 20 seconds, Demonic 5 seconds.
  Eye Beam extends still-valid flag horizons by 5 seconds. Expiry becomes unknown,
  never proof of absence. Do not infer extra hasted-channel duration.
- At read time, require the real public Metamorphosis aura to be confirmed active
  before exposing tracked values. Publicly proven absence clears history and
  supplies zero. Restricted/unknown aura supplies no facts. Never use cast-estimated
  form state as independent proof for this tracker.
- Bound cast-GUID deduplication to 32 entries. Ignore other units; invalidate on
  restricted player event identity or unknown spell ID. Duplicate events must not
  rearm a previously consumed flag. Deduplicate before invalidation/recovery.
- Clear state on build change, specialization change, world transition, death,
  disable and time reversal. Do not clear on target switch or leaving combat:
  these do not intrinsically end a transformation. Never persist across reload.
  On a player aura-change event, clear history if public Meta cannot be confirmed
  active, so a cancelled/hidden form transition cannot carry old charges forward.
- Feed the independent evaluator with explicit `cast_model` provenance and count.
  Keep its existing experimental opt-in and performance gate unchanged. This is
  determinate under the declared mechanic/event model, not live-certified truth.
- Existing policy ordering remains frozen. This change does not establish DPS
  gains or complete Aldrachi support. Validate model behavior against pinned
  simulation traces where available, not by merely counting tests.

Tests are additive (Test-Lock scenario 3): burst/reset/consumption sequences,
mid-form refresh, exact-expiry uncertainty, unknowns, event identity/lifecycle,
and real independent-observer integration. Include generated temporal invariants
and >=80% killed behavioral mutations. Preserve existing assertions.
