# Robust state consensus and independent policy refinement

2026-09-22. Extend rc.6 without claiming complete observability or maximum DPS.

## Symbolic consensus

The existing independent evaluator is sound but conservative: it treats unknown
predicates independently. Add a bounded symbolic evaluator which keeps repeated
uses of the same fact correlated. Partition numeric domains at policy thresholds,
including open endpoints; do not replace missing values with guessed values.
Unknown readiness and spell knowledge include both true and false. Each action's
charges have their own domain. Missing form is unknown. Preserve supplied bounds.

Follow all feasible branches of the ordered rules. Return a decided action only
if every feasible completion selects that same action. A possible no-action
outcome prevents a decision. Distinct action witnesses prove ambiguity. Node or
depth budget exhaustion never permits a decision. Fast-path existing determinate
results. Validate policy edits on every call; reuse allocated buffers.

Wire consensus into the independent observer. Its experimental opt-in, channel
guard and official fallback remain unchanged. No new simulated damage values,
secret reads, probabilistic certainty claims or automatic casting.

## Policy experiments

Search modifications of our own policy: resource/cooldown thresholds, rule removal,
off-GCD retreat and enemy-count-conditioned action promotion. Use the pinned real
SimC engine and exact fixed-profile envelope. Rank discovery by the worst ratio
across single/five targets and 300 seconds. Freeze the selected policy before
fresh holdout seeds and previously unused target counts/durations. Retain inferior
results. Report uncertainty and full-state versus live-observable boundaries.
Do not promote the new policy merely because discovery improves. No policy search
result establishes that live unknown information has become observable.

## Validation (Test-Lock scenario 3: additive)

Complementary/equality predicates, contradictory conjunctions, repeated fact
correlation, form, per-action charges, possible wait, unknown readiness, secret
inputs, invalid/editable policies, bounds and exhausted budgets. Hypothesis must
compare decisions to an independently implemented exhaustive completion oracle.
Mutation checks must catch unsound shortcuts. Record actual cost on representative
snapshots; offline timing is not an in-client frame-time result.
