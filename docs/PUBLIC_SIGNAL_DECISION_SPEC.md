# Public-signal independent decisions

2026-09-22. User requests implementation and alternative paths around missing
combat information. Astra owns implementation. No secret value is decoded,
compared, converted, or recovered from display widgets.

## Public resource evidence

When an exact primary resource is unavailable, public native spell usability and
public *minimum required* cost can supply inequalities. Use minCost, not total
optional cost. Accept only a single applicable flat resource cost of the desired
power type, a publicly learned spell, and complete public cost metadata. Reject
percentage/drain costs, uncertain aura applicability, multiple resources, free
costs, secret results, errors and contradictory observations. A usable spell
implies resource >= minimum; an explicitly insufficient-power result implies
resource < minimum. The runtime may keep the upper endpoint inclusive to be
conservative. Inference is tagged as evidence bounds, never resourceKnown=true.
Rebuild every evaluation; do not carry resource bounds through a cast or reset.

## Aura evidence

Map actual Initiative and Inertia Trigger buff IDs from the pinned class source.
Read public player aura presence/remains. Nil means unknown unless both general
and spell-specific secrecy predicates explicitly say unrestricted and player
existence/visibility are public true. Do not invent aura IDs for SimC's internal
Demonsurge flags. Queries and individual fields remain guarded even when a
predicate reports unrestricted.

## Experimental independent head

The frozen rc.5 policy is still below stock SimC in the tested full-information
scenarios. Add an explicit, default-off experimental option, not an automatic
performance-qualified replacement. `/ra independent on|off` controls it and
explains the experimental status in the player's locale. Only a definite result
from a fresh observer snapshot can replace the immediate head. Preserve the
official reference in diagnostics, label the selected source INDEPENDENT, and
seed all subsequent prediction from the actual selected head. Unknown results
fall back to the existing queue. Do not interrupt an active player channel to
promote the research head. Disabling/changing context clears the old decision.

This is a spec extension to the prior unconditional reference-head contract.
Existing default-mode tests keep their assertions; new tests exercise opt-in
behavior (Test-Lock scenario 3). An experimental choice is not a highest-DPS
claim, nor proof of hidden-state recovery or current-client API availability.

## Verification

Adversarial secret/error inputs; optional versus minimum costs; free casts;
multi-resource ambiguity; contradictory bounds; generated true-resource cases
contained in inferred intervals; absent versus inaccessible auras; independent
head different from reference; tail seeded from selected head; unknown/disabled
fallback; target invalidation. Targeted mutation checks must detect these faults.
Package checks and mocked tests do not replace a real client validation.
