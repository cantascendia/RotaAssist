# Target and range research — 2026-09-22

Implementation and review: Astra. Sources are pinned to Gethe's mirror of
Blizzard-generated UI/API source at
[`78282522143e25c3540583734fd192c3d69be910`](https://github.com/Gethe/wow-ui-source/tree/78282522143e25c3540583734fd192c3d69be910).
Per-file URLs and SHA-256 hashes are in [sources.json](sources.json).

## Findings applied

- `C_Spell.IsSpellInRange(spellIdentifier, targetUnit)` supports a specific unit.
  True, false and nil have different meanings. Each result is checked for secret
  provenance and boolean type before branching. API errors remain unknown.
- `UnitGUID` and `UnitIsUnit` may be restricted. Deduplication uses only public
  identities/comparisons; uncertainty does not increase the confirmed count.
- `GetUnitAuraBySpellID` requires a non-secret aura and can return nil for an
  invisible unit. Nil is not proof of absence. Only public matching spell IDs,
  finite expiration times and, for the target debuff, the player's source are used.
- No public API in these findings establishes an exact set of enemies hit by a
  cone, trajectory or target-centered area. The installed Havoc probe is Chaos
  Strike/its learned override. Its count is a nearby-enemy lower bound; it does
  not establish full Blade Dance, Eye Beam or Essence Break hit coverage.

The implementation scans target plus up to 40 nameplate tokens, excluding public
dead/friendly units and idle non-targets. Distant units fail the range probe.
Unseen enemies, missing tokens, restricted identities and unverified coverage
prevent an exact-count claim. UnitAffectingCombat is not proof of engagement with
this particular group; other nearby combat can still be part of the estimate.

## Changes in the recommendation path

TargetContext feeds AIInference and SmartQueueManager. The latter passes range,
count provenance, current-target Essence Break and readable player Metamorphosis
remaining seconds into APLEngine. Positive count thresholds can use a lower bound;
exact-count and upper-bound conditions cannot pass on incomplete observations.
Unknown aura state cannot satisfy either positive or negative presence conditions.
Public aura time limits decay through the simulated horizon. Cast-triggered
Demonic windows and newly simulated casts remain approximations.

Target switches broadcast a local context event, resetting the bridge cache,
sticky head, predictions and target-specific inferred window. A known invalid
target clears offensive recommendations. If validity is unknown, only a valid
official head can remain; local APL generation is disabled for that snapshot.
Known out-of-range actions are excluded. Unknown range does not prove readiness.
The valid official head remains authoritative; the addon has not become a full
independent damage optimizer.

Talent events rebuild the range spell set and re-resolve the learned override.
Existing numeric hero-profile selection remains in SpecDetector/APLEngine.
Detailed observation is currently Havoc-specific; this research does not
establish Vengeance/Devourer or arbitrary talent-build parity.

## Verification and limits

New Lua cases cover counts, duplicates, protected values, ownership, transitions,
observed expiration and queue/bridge invalidation. A generated Hypothesis test
varies in-range, engaged and dead populations. Six isolated mutations were rejected.
The cache mutation initially survived because the mock CVar disabled caching;
correcting that fixture to 0.1 seconds made the unchanged behavior assertion fail.

The actual APLEngine was exercised as a unit moves out of/into/out of range:
the synthetic contract switches single-target/AoE/single-target lists. This proves
context plumbing and transition behavior, not that those test spells maximize DPS.
No damage benchmark or live-client test was performed for this change.

[Blizzard's combat philosophy](https://news.blizzard.com/en-us/article/24246290/combat-philosophy-and-addon-disarmament-in-midnight)
explains why visible combat information is not necessarily available for addon
decisions. More frequent polling cannot recover restricted state. Establishing
best expected damage still requires a calibrated action/damage model under the
same observation constraints and independent encounter comparisons. Current
stock SimC benchmarks do not measure this addon policy.
