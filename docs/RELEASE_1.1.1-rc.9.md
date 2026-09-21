# RotaAssist 1.1.1-rc.9 — talent-aware transitions

Astra implementation. Havoc lookahead now uses selected Demonic and Chaotic
Transformation ranks from the character snapshot. Eye Beam no longer creates
Metamorphosis for a known unselected Demonic talent. Manual Metamorphosis resets
Eye Beam and the shared Blade Dance / Death Sweep cooldown only when the reset
talent is selected. Unknown talents retain uncertainty.

Known existing form time is extended rather than shortened. Demonic's five-second
base contribution is a lower bound because hasted channel duration is not modeled;
its expiry becomes unknown, not a claim that normal form has returned. Manual
Metamorphosis uses the pinned twenty-second base duration. Build changes also
clear the previous cast-based form estimate.

Validated with **677 Lua tests, 80 Python tests, seven behavioral mutations** and
166 addon Lua syntax checks. The generated property test covers 50 configurations.
Package payload hashes and TOC/XML ordered loading are verified by the packager.

Install `RotaAssist-1.1.1-rc.9.zip` into `_retail_/Interface/AddOns/`, preserving
`RotaAssist/RotaAssist.toc`. The local installer retains the previous installation.
Use `/ra build` for recognized character configuration. Interface remains `120100`.

This improves forward-transition correctness, not a measured DPS score. No new
DPS benchmark or live-client acceptance was performed. The independent first-slot
policy is unchanged and remains default-off. Full talent/gear damage calculation
and maximum-output qualification are still incomplete. Detailed source evidence
is included in `docs/research/talent-transitions/README.md`.
