# RotaAssist 1.1.1-rc.13 — Havoc action applicability

The independent observer can now use current-target melee evidence for Havoc
Immolation Aura, Blade Dance and Death Sweep when the game publicly identifies
them as having no target-range check. This fixes an unnecessary source of
ambiguous decisions for player-centered area actions. It preserves native range
results and does not treat nil as proof of range for other skills. Switching or
losing the target invalidates the evidence. Usability, learned-status and cooldown
gates still apply; generic targetable counts remain unchanged.

The evidence reaches the real main queue when experimental independent mode is
enabled. `/ra independent on` remains an explicit opt-in. Default settings and
both frozen hero policy orders remain unchanged. No personal export is required.

Validation: 731 Lua tests, 111 Python tests, 169 addon Lua syntax checks, eight
focused behavioral mutations and ten prior Aldrachi mutations. Generated tests
cover 65 range-evidence combinations. TOC/XML ordered loading and ZIP payload
hash verification are performed by the local packager and installer.

New fixed-profile SimC comparisons include movement, periodic add waves and both
together, for each Havoc hero path. Fel-Scarred reaches 91.82%–97.54% of reference;
Aldrachi reaches 94.71%–97.49%. All six means remain lower than reference. These
are full-information synthetic encounters, not measured addon DPS or real Mythic+
routes. Six extra traces prove that the event definitions executed. See the
[research record](../research/havoc-encounters/README.md).

Install `RotaAssist-1.1.1-rc.13.zip` into `_retail_/Interface/AddOns/`, retaining
`RotaAssist/RotaAssist.toc`. The local installer preserves the previous version.
Interface is `120100`. Actual client combat acceptance remains unfinished. This
release does not claim theoretical maximum damage or superiority to Hekili.
