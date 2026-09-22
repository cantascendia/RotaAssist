# Optimality evidence contract

There are three distinct questions: whether every state compatible with an
observation selects the same policy action; whether the action maximizes expected
remaining reward in a specified model; and whether this model describes real
Mythic+/raid combat accurately. None implies the next without extra evidence.

Runtime: augment IndependentConsensus with at most two reusable interval witnesses
for different policy outcomes, including wait. Every witness is a feasible box
in the evaluator's numeric abstraction, not a reconstructed hidden game state.
Unknown predicates stay correlated. Invalid input, missing evaluator, reset and
budget exhaustion cannot retain a prior certificate. Invariance is explicitly
scoped to the supplied priority policy; maximumDPSProven stays false. Observer
diagnostics carry these witnesses without changing selection or defaults.

Offline: implement exact rational regret bounds over explicitly supplied worlds,
alternatives and intervals for remaining-horizon return. For alternative a:

    regretUpper(a) = max_w max(0, max_{b != a} U(w,b) - L(w,a))

Zero proves a is optimal in every supplied world under those bounds. The action
itself must be excluded from the competitor maximum. Compare within each world;
do not subtract one world's lower value from another world's upper value.
All alternatives must appear in every world; invalid or inverted bounds are
rejected. A certificate covers only this finite comparison set. To extend it to
all feasible policies requires independently justified coverage and global upper
bounds. Immediate spell damage cannot substitute for remaining-fight return.

Optional explicit rational world probabilities give expected Q intervals and an
expected-regret bound. There is no implicit uniform prior. Alternatives must be
single-stage choices or complete non-anticipating policies shared across worlds.
Averaging per-world clairvoyant Q-star is NOT a POMDP optimality proof (it may
cheat by adapting future actions to unobserved information). Expected optimality
does not imply hindsight optimality in every realization. Exact inputs permit
an exact common-argmax audit, including ties. Numerical intervals and rational
arithmetic certificates are conditional on model coverage and bound validity;
they are never automatically promoted to live-game proof.

Ship a clearly synthetic indistinguishability example with two same-observation
futures requiring different actions. Also demonstrate robust dominance and an
exact prior-based expected optimum. Synthetic numbers must not use live spell
IDs or masquerade as WoW damage coefficients. Real policies supply runtime
ambiguity examples, not fabricated Q values.

Validation: add-only unit tests, generated witnesses independently replayed through
IndependentDecision, exhaustive finite payoff-table oracles and mutation tests.
Existing assertions and priority data remain unchanged. No policy release may be
described as maximum DPS based on these tests alone.
