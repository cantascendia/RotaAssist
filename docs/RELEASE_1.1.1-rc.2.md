# RotaAssist 1.1.1-rc.2 — local adaptive-prediction candidate

Date: 2026-09-22. Astra directed the work and review; Sol implemented the code.
This release follows the user's choice of a local installation package.

## Changes users can observe

- Lookahead advances through simulated casts and cooldowns instead of evaluating
  every step against the starting moment. Public charge counts are consumed and
  public recharge timers can restore charges.
- A scripted opener stops when its next known action is unavailable, then the
  normal priority list is evaluated from the resulting simulated state.
- Unknown resources and cooldowns remain unknown. Lookahead can become shorter
  when the addon cannot establish the next action's prerequisites.
- Havoc hero-profile selection uses numeric talent spell IDs, avoiding
  English-only name matching on Chinese and Japanese clients.
- The current valid Blizzard suggestion remains the primary action. Research
  changes to a full-state SimulationCraft APL do not replace it.

## Install

Extract `RotaAssist-1.1.1-rc.2.zip` into the retail client's
`Interface/AddOns/` directory, producing `Interface/AddOns/RotaAssist/`.
The ZIP includes its required libraries. A source-code ZIP is not equivalent.
The repository's `scripts/install_test.ps1` validates every payload hash and
retains a backup before upgrading an existing installation.

## Evidence and limits

The delivery verification directory accompanies the local ZIP. It contains
the Lua regression results, syntax/package validation and installation evidence.
The research tools record official SimulationCraft source and executable
provenance, run parameters, results and uncertainty separately from the addon.
See [research notes](ADAPTIVE_RESEARCH_2026-09-22.md) and
[quality criteria](QUALITY_BASELINE.md).

The declared target is Interface `120100`. This machine has an AddOns directory
but no retail `Wow.exe`; real client loading, combat behavior and frame time
are not verified. The predictor still approximates parts of the combat model.
No globally optimal rotation or DPS superiority over historical Hekili is claimed.
