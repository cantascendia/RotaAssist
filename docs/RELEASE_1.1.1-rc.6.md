# RotaAssist 1.1.1-rc.6 — public signals and experimental independent head

Astra implementation. This local candidate adds a concrete alternative when exact
combat resources are unavailable: guarded public spell usability and minimum costs
provide resource bounds. Public player aura facts extend the independent observer.
Unknown or conflicting information remains unknown.

To try independent immediate recommendations, enter `/ra independent on`.
The option is **off by default**. A definite eligible independent decision can
replace the main action; subsequent estimates start from that selected action.
The icon carries **EXP / 实验 / 実験**, and diagnostics retain the Blizzard reference.
Unknown results and active/unknown channel state preserve the existing queue.
Use `/ra independent off` to return to default behavior.

The frozen candidate is limited to Havoc Fel-Scarred research. It has not qualified
for a performance claim: prior fixed-profile full-state simulations lost
1.42%–2.68% to stock SimC. No new DPS benchmark is claimed in rc.6. This is not full
battlefield observability, exact AoE geometry, all-build support, or proof of
matching/exceeding historical Hekili. Public API availability in combat is still
subject to actual-client verification.

Validation: **646 Lua tests, 39 Python tests, 11 behavioral mutation checks**;
163 addon Lua files pass syntax checks. ZIP dependency/hash verification and
ordered-load smoke tests are offline evidence, not real client acceptance.
The design and source evidence are included under `docs/PUBLIC_SIGNAL_DECISION_SPEC.md`
and `docs/research/public-signals/` in the ZIP.

Extract `RotaAssist-1.1.1-rc.6.zip` into
`World of Warcraft/_retail_/Interface/AddOns/` so that
`RotaAssist/RotaAssist.toc` exists. Ace3 is bundled; Interface is `120100`.
The local installer preserves the previous installation as a sibling backup.
Restart the client or `/reload`, then check target changes, channeling and the
experimental badge. No real-client combat or visual validation has been completed.
