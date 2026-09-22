# Complete the missing Aldrachi Havoc decision path

The generic Havoc default APL is also its Aldrachi alias, but lacks Reaver's
Glaive. A Fel-Scarred policy is not a valid substitute. This change adds a
separate, independently authored and benchmarked Aldrachi priority policy.

- Generate Lua and SimC from the same own policy source. Preserve the existing
  Fel-Scarred candidate byte-for-byte. Pin engine and both reference profiles.
  Compare on identical gear/talents/encounters; separate discovery and holdout.
- Select Aldrachi only from a complete current Havoc talent snapshot proving
  Art of the Glaive (442290). A default APL label alone is insufficient. Expose
  selected profile/hash and clear on unknown/conflicting builds.
- Collect documented Reaver's Glaive (444686), Glaive Flurry (442435) and Rending
  Strike (442442) aura facts. Preserve secret/absent/unknown distinctions. Do not
  fabricate fragment pickup, target geometry or combo proc state.
- Reaver's Glaive (442294) is a live replacement of Throw Glaive (185123).
  A publicly confirmed active replacement of a learned base spell can establish
  learned status even if IsPlayerSpell on the replacement returns false. Neither
  a static pair nor an old spellbook entry proves an active proc. Gate replacement
  identity and availability at runtime; reject secrets before comparisons.
- Make the current-target range query available to policy-only actions so new
  spells do not remain permanently unknown merely because the old APL omits them.
- Keep independent main-slot replacement explicitly experimental/default-off.
  Simulation policy results do not certify live observation, highest DPS, or all
  builds. Record remaining losses rather than weakening the reference.
- Additive tests (Test-Lock scenario 3) cover policy selection and build changes,
  real aura/range/readiness integration, replacement identity and restricted APIs.
  Add generated evaluator parity and behavioral mutation coverage >=80%.
