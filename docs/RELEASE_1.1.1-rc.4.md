# RotaAssist 1.1.1-rc.4 — target-aware local candidate

Astra implemented and reviewed this version on 2026-09-22.

- Switching targets immediately clears the previous target's recommendation
  cache, predicted queue and inferred target-debuff window.
- Havoc's nearby-enemy estimate now uses public spell-range checks for living,
  attackable, already-engaged nameplate units, plus the explicit current target.
  Distant/idle units and duplicate target nameplates do not increase the count.
- A public out-of-range result excludes that skill from local predictions.
  Public current-target Essence Break and player Metamorphosis observations
  carry remaining seconds; target debuff ownership must be this player.
- Unknown aura state is not treated as absence. Talent/config changes refresh
  observations and spell overrides. Public aura expiration advances with the
  prediction horizon. Unknown target validity permits only the official head.

Extract the ZIP into `World of Warcraft/_retail_/Interface/AddOns/` so that
`RotaAssist/RotaAssist.toc` exists. Required libraries are bundled. The installer
verifies hashes and retains an old-version backup.

The range count is a **nearby-enemy lower bound**, not an exact cone/AoE hit count.
The detailed observation model is Havoc-specific. This does not fully model all
talents, buffs, enemy debuffs, geometry or future procs, and does not establish
maximum DPS. Blizzard's valid recommendation remains the main action.

Target Interface is `120100`. Local package and installation verification do not
replace combat testing: this machine still lacks the retail `Wow.exe`.
See [context contract](TARGET_CONTEXT_SPEC.md) and the repository's
`research/target-context/README.md` for source evidence and remaining work.
