# RotaAssist 1.1.1-rc.12 — Aldrachi Havoc and active replacements

Havoc now has separate Fel-Scarred and Aldrachi independent policies. The current
complete talent snapshot selects the hero path automatically; changing builds
reselects it, and missing or conflicting evidence clears it. The new Aldrachi
policy uses Reaver's Glaive, Rending Strike and Glaive Flurry aura facts, resource
bounds, form, cooldown and target-count evidence. Public unknowns remain unknown.
No personal export or external program is required for in-game operation.

The default recommendation filters also receive a concrete fix: a publicly
confirmed current replacement of a learned base spell survives learned-status
checks. This prevents Reaver's Glaive from being discarded as unlearned, and keeps
the Meta Annihilation melee probe and resource evidence usable. A static spell
pair or stale spellbook entry does not establish an active proc. Expired,
restricted or unconfirmed replacements are not assumed available.

The frozen Aldrachi policy reaches 96.35%–97.27% of the full reference SimC APL in
six held-out scenarios: one/two/five targets, 120/300 seconds, 3000 requested
iterations per side. All six means remain below reference. These are controlled
full-information simulations of one build, not observed addon DPS. The existing
Fel-Scarred candidate is unchanged. See [research](../research/aldrachi-policy/README.md).

Independent main-slot selection remains off by default. `/ra independent on`
opts into the experimental immediate recommendation when public evidence reaches
a decision; unknown evidence falls back. Later queue icons remain estimates
from the existing forward model, not a simulated full Aldrachi optimal sequence.

Validation: 723 Lua tests, 109 Python tests, 169 addon Lua syntax checks and ten
behavioral mutations caught. New generated tests cover 60 complete snapshots.
Integration tests cover both native and experimental main queues, shipped policy
loading, build changes, current range, proc expiry and restricted values.
Package verification checks all payload hashes and ordered TOC/XML loading.

Extract `RotaAssist-1.1.1-rc.12.zip` under `_retail_/Interface/AddOns/`, retaining
`RotaAssist/RotaAssist.toc`. The local installer backs up the previous install.
Interface is `120100`. Actual WoW combat/API compatibility, comprehensive build
and battlefield coverage, highest DPS and superiority to Hekili remain unproven.
