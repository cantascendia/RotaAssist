# RotaAssist 1.1.1-rc.7 — consensus across possible combat states

Astra implementation. The independent observer now retains correlations between
repeated unknown facts. It partitions their feasible ranges and checks all branches
of the current policy. A next action is definite only when all feasible outcomes
agree; a possible wait or different action prevents promotion. Search-budget
exhaustion preserves fallback behavior.

This proves consistency with the specified policy and input bounds, **not global
damage optimality**. No hidden resource, proc, enemy position or future action is
invented. In a deterministic synthetic set of 2,000 snapshots of the actual frozen
policy, definite decisions increased from 782 to 792. Mean offline evaluation time
was about 0.10 ms; neither number measures real-client coverage or frame time.

Use `/ra independent on` to enable the existing default-off experimental head;
`/ra independent off` disables it. EXP / 实验 / 実験 remains the source marker.
The packaged rotation policy is unchanged from rc.6. The new numerical and phase
policy candidates remain research-only because cross-scenario qualification has
not been established. Full results, including regressions, are included under
`docs/research/robust-consensus/` in the ZIP.

Validation: **655 Lua tests, 78 Python tests** (including the training parser),
**20 behavioral mutation checks**, and 164 addon Lua syntax checks. Package checks
cover bundled dependencies, the ordered load graph and every payload hash.
Tests and symbolic proofs do not replace real-client combat validation.

Extract `RotaAssist-1.1.1-rc.7.zip` to
`World of Warcraft/_retail_/Interface/AddOns/`, preserving
`RotaAssist/RotaAssist.toc`. Interface is `120100`; Ace3 is bundled.
The local installer retains the previous installation as a sibling backup.
The requested full battlefield understanding and highest-DPS result remain
unachieved; this release improves reasoning under explicitly incomplete information.
