# RotaAssist 1.1.1-rc.5 — independent-policy observation candidate

Astra implemented, tested and packaged this version on 2026-09-22.

The addon now evaluates an independently authored Havoc Fel-Scarred policy
alongside the existing recommendation queue. A shared policy file drives both
the Lua decision evaluator and external SimulationCraft experiments. Public
target/range, cooldown, charge, resource and selected aura facts can determine an
action independently of Blizzard's recommendation. Unknown facts remain explicit.

The independent candidate **did not pass performance qualification**: held-out
fixed-profile simulations lost 1.42%–2.68% to the stock SimC policy. Consequently
this release keeps its result in diagnostic observation mode; it does not replace
the displayed main action. It is not a maximum-DPS or Hekili-superiority release.
See `research/independent-policy/README.md` and `holdout.json` in this package's
docs folder for full conditions, hashes, uncertainty and limitations.

Validation: 628 Lua cases, 38 Python tests, plus five targeted behavioral mutation
checks. Generated cases compare the exported policy against an independent
reference evaluator. Package load-graph/hash checks remain offline evidence.
No retail combat or visual validation has been completed.

Extract the ZIP into `World of Warcraft/_retail_/Interface/AddOns/`, preserving
the `RotaAssist/RotaAssist.toc` structure. Ace3 libraries are bundled. Interface
is `120100`. The local installer verifies the payload and retains the old version.

The user-requested full battlefield understanding and highest-output recommendation
remain unachieved. Other builds, exact geometry, hidden combat state, movement,
future procs and personal equipment need additional modeling and validation.
