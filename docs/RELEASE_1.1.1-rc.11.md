# RotaAssist 1.1.1-rc.11 — Havoc burst-state tracking

This release focuses on Havoc Fel-Scarred. It adds a bounded cast-history model
for Demonsurge's Annihilation, Death Sweep and Immolation Aura flags. Manual
Metamorphosis refreshes all three; Eye Beam/Abyssal Gaze with selected Demonic
refresh the two spenders; successful matching casts consume their own flag.

The tracker requires a complete talent snapshot and public confirmation of the
real Meta aura. Its values are explicitly marked as cast-model evidence. They
are not fabricated client aura readings. Conservative expiry becomes unknown;
death, build changes, world changes and unconfirmed player aura transitions
discard history. Deduplication is bounded to 32 cast identities.

The existing independent evaluator uses this evidence when available, allowing
some previously ambiguous burst decisions to become determinate. Its policy
order, performance qualification and default-off experimental setting remain
unchanged. `/ra independent on` remains an explicit experimental opt-in.
No personal export or external tool is required for in-game tracking.

Validation: 705 Lua tests, 102 Python tests, 168 addon Lua syntax checks and nine
behavioral mutations. Generated temporal tests cover 60 cast/time configurations.
Four actual pinned SimC runs (one/five targets, two seeds, 180 seconds each)
agree with all 628 emitted cast-model values and 393 public-absence values.
Another 878 observations stay unknown. This is mechanic replay validation, not
a DPS measurement or proof of real-client event ordering/API availability.

Extract `RotaAssist-1.1.1-rc.11.zip` under `_retail_/Interface/AddOns/` and retain
`RotaAssist/RotaAssist.toc`. The local installer preserves the prior installation.
Interface remains `120100`. The package verifies payload hashes and ordered load.

Havoc is not yet fully qualified: live combat acceptance, complete damage/build
coverage and an independent Aldrachi policy remain unfinished. No claim of
maximum DPS or superiority to Hekili is made.
