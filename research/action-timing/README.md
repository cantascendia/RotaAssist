# Event-proven next-action timing

The previous observer rejected every positive cooldown. In a reproducible public
GCD fixture it returned `wait`; the new event-aware path chooses the independent
spell inside the configured queue window, without a native recommendation.
The real SmartQueueManager main slot is exercised, not only a mock evaluator.

The horizon is the remaining public GCD, limited by SpellQueueWindow and capped
at 400 ms. Spell and GCD start/duration must match exactly, and the event's public
isOnGCD and enabled flags must be true. Charge spells also require a public
available charge. A targeted cooldown event refreshes only the matching spell
or base identity; it cannot bless other spells' flags. Every read rechecks clocks
and charges. Casts, charge/build updates, world entry and disable discard proof.

At that horizon, expiring auras no longer satisfy positive-buff conditions.
Positive flags without readable expiry become unknown. Cast-modeled Demonsurge
facts require both their own expiry and a public Meta window to cover the
horizon. Looking ahead does not erase history still valid at the current time.
There is no extrapolated regeneration, future proc, pack spawn or target lifetime.

Validation: 756 Lua tests, 118 Python tests, 170 addon Lua syntax checks,
100 generated evidence combinations and 55 generated surge horizon combinations
(exact floating-point boundary combinations are handled conservatively).
Twelve of twelve behavioral mutations were rejected. The initial mutation pass
missed a missing-charge check because the shared reader already rejected the
fixture's visible recharge clock. Added cases cover hidden recharge fields and
an empty single-charge spell; the final mutation pass rejects that defect too.

The first queue fixture omitted TargetContext's `supported` flag and consequently
produced no main slot. The fixture was corrected to supply the real snapshot
contract; its expected main-slot assertions were retained. Existing tests and
priority-policy files were not changed.

Reproduce:

```text
lua scripts/run_tests.lua action_timing
python -m pytest tests/test_action_timing_property.py -q
python scripts/mutate_action_timing.py --output dist/research/action-timing/mutations
```

API provenance is pinned in `sources.json`; the original generated documentation
is archived locally in dist. It specifies event-only trust for isOnGCD.
This release changes observation timing, not the policy's damage model. No new
SimC DPS result, real-client observation coverage, Mythic+ route or raid damage
measurement is claimed. The local inspected retail path has no Wow.exe and no
running Wow process was found. Independent main-slot mode remains opt-in with
`/ra independent on`; future hints are conditional and re-evaluated.
