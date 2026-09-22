# RotaAssist 1.1.1-rc.16 — Scoped decision evidence

The independent consensus engine now returns at most two reusable interval
witnesses when compatible abstract states choose different policy actions.
Waiting is an alternative. Observer diagnostics carry these witnesses and the
scope `supplied_policy_only`. Exhaustive policy agreement is explicitly separate
from damage optimality. Invalid inputs and lifecycle resets clear prior evidence.

A separate Python calculator implements exact rational regret bounds over a
finite supplied return table. It can certify interval dominance within that
table and evaluate an explicitly supplied prior; it is not a WoW damage model.
Synthetic examples demonstrate both a positive conditional certificate and
indistinguishable futures with no common best action. The research report also
audits 40 historical simulator outputs and their inputs, without a new DPS claim.

Validation: 761 Lua tests, 131 Python tests, 170 Lua syntax checks and nine
behavioral mutations. Generated interval witnesses replay independently through
the base evaluator; numerical certificates are checked against exhaustive cases.
These tests validate evidence logic, not Mythic+ or raid optimality.

Install by extracting `RotaAssist-1.1.1-rc.16.zip` into
`_retail_/Interface/AddOns/`, preserving `RotaAssist/RotaAssist.toc`.
Interface remains `120100`; independent main-slot mode remains opt-in with
`/ra independent on`. No personal export or external calculator is required by
the addon. Shipped priority policies and recommendation selection are unchanged.
The local installer keeps a backup. No running/usable local WoW client has been
available for live acceptance, and no highest-output claim is made.
