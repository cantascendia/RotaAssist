# Changelog

All notable changes to RotaAssist will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-09-01

**First public release.** 1.0.0 was an internal build and was never published.
Target client: **World of Warcraft: Midnight 12.1** (Interface `120100`).

Scope note: this release ships **Demon Hunter only** — Havoc (577), Vengeance (581),
and Devourer (1480, experimental). See "Changed" for why.

### Added
- **APL load-time condition validation.** Every APL rule's condition vocabulary is
  checked once per spec at load time. Rules using tokens the engine cannot evaluate
  are recorded instead of silently never firing.
- **`/ra aplcheck` slash command.** Prints the load-time validation report: which
  rules use unsupported tokens, which spec/list they belong to, and the offending
  token. Expected output for the three shipped DH specs is zero entries.
- **`OR` reported as unsupported.** `splitConditions()` only splits conjunctions, so a
  disjunction previously collapsed into one unmatchable token and killed the rule
  silently. It is now reported rather than half-implemented over guessed data.
- **CooldownViewer coexistence hook (`Engine/CDMHook.lua`).** Optional integration with
  the 12.x native cooldown viewer so RotaAssist's cooldown panel does not double up
  with Blizzard's. **Disabled by default**; enable it in `/ra config`.
- **Combat-aware throttling.** Resident update frames now run at a reduced rate out of
  combat instead of at full speed, cutting idle CPU cost substantially while parked
  in a city.
- **spellID existence guards.** Every `C_Spell.GetSpellInfo` lookup is wrapped and
  nil-checked, so an unknown or datamined spellID degrades to "recommendation not
  shown" instead of throwing a Lua error. This is what makes shipping Devourer safe.
- **1s refresh ticker on the cooldown panel**, active only while the panel is visible
  and cancelled on disable.

### Changed
- **TOC `Interface` bumped to `120100`** (Midnight 12.1). Previously `120000`, three
  patches behind, which made the client flag the addon as out of date.
- **Product scope narrowed to Demon Hunter's three specs.** The other 17 specs remain
  in the repository as incubating data but are no longer loaded by the TOC. Those
  specs averaged roughly 30% permanently-dead APL rules; several decision trees were
  14–30 line stubs. Shipping three specs that work beats shipping twenty that claim to.
- **Cooldown panel data source migrated** from the removed `CooldownTracker` to
  `CooldownOverlay`. `CooldownOverlay` is a superset source that tracks the current
  spec at 5Hz rather than polling a static 131-spell whitelist at 10Hz — more accurate
  for the player, and far cheaper. User overrides in
  `db.profile.cooldowns.trackedSpells` are preserved.
- **Charge scanning narrowed by roughly 95%.** `SmartQueueManager` no longer walks the
  entire spell whitelist every frame.
- **`InterruptAdvisor` moved into `MODULE_ORDER`**, so it initializes with the engine
  rather than after every UI module.

### Fixed
- **Six secret-value compliance violations** (12.x hard requirement — secret values must
  never reach a comparison or arithmetic operation):
  - `PatternDetector.lua` — nameplate count compared before the `issecretvalue` guard.
  - `NeuralPredictor.lua` — the same defect, duplicated verbatim.
  - `SmartQueueManager.lua` — `currentCharges` used with no `issecretvalue` check at all.
  - `SmartQueueManager.lua` — the project's only bare `UnitPower` call, unwrapped.
  - `APLEngine.lua` — consumed the above tainted values in `compareNumber`, forming a
    reproducible end-to-end violation chain.
  - `RecommendationManager.lua` — comparison plus division on a secret value (removed
    with the file, see "Removed").

  All reads now follow one template: `pcall → issecretvalue → type check → fallback`.
- **Pre-pull panel never appeared.** `PrePullPanel` had no `Show()` call anywhere in the
  chain, so the pre-pull checklist was unreachable in a shipped build.
- **Confidence star rating was inverted.** `MainDisplay` passed a 0–1 float to a function
  expecting an integer 1/2/3, so high-confidence recommendations displayed as low.
- **Cooldown swipe was always zero.** The remaining-time expression in `CooldownBar`
  reduced to a constant 0, so the radial cooldown never animated.
- **Keybind text and cooldown countdown were mutually exclusive.** They shared one font
  string; showing either hid the other.
- **Icon cross-fade race.** Rapid recommendation changes could leave two icons partially
  faded on top of each other, or strand an icon at partial alpha.
- **Cooldown panel countdown froze out of combat.** The event-driven refresh had no
  ticker after the data-source migration; a visible-only 1s ticker restores it.
- **EventHandler debug spam.** Event-fire logging printed to chat outside debug mode.
- **Assisted-combat helper icons leaked into the main display.**

### Removed
- **975 lines of dead code**, verified by grep to have no remaining callers:
  - `Engine/RecommendationManager.lua` (457 lines) — already commented out of the TOC,
    zero call sites, and the source of two of the secret-value violations above.
  - `Core/CooldownTracker.lua` (262 lines) — polled 131 spells at 10Hz, roughly 1310
    API calls per second, permanently, including out of combat.
  - `Core/AssistCapture.lua` (256 lines) — consumed only by `RecommendationManager`.
  - Corresponding tests removed in the same change.
- **17 non-Demon-Hunter specs removed from the TOC load order** (files retained in-repo).

### Known Issues
- **Devourer (specID 1480) is experimental.** Several spellIDs originate from early
  datamining and have not been verified against a live 12.1 client. Runtime guards
  prevent errors, but affected recommendations simply will not display. Verify with
  `/dump C_Spell.GetSpellInfo(<id>)` and please report corrections in the CurseForge
  comments.
- **No EditMode integration yet.** The display uses its own drag-and-lock rather than
  the 12.x EditMode system.
- **No UI design system yet.** Colors, fonts, and spacing are still defined per-widget.
- **Two combat-phase detection systems coexist** (`AIInference` and `PatternDetector`),
  with overlapping sampling. Consolidation is planned.

## [1.0.0] - 2026-03-13

> Internal build only — never published to CurseForge or Wago.

### Added
- Core engine: Blizzard C_AssistedCombat bridge with throttling and passive filtering
- APL Engine: SimC-based priority simulation with opener sequences and multi-profile support
- Neural Predictor: Decision tree + Markov chain prediction with personal learning (SavedVariables)
- Smart Queue Manager: 5-source weighted fusion (Blizzard, APL, AI, CD, Defensive) with anti-flicker
- Pattern Detector: 12-phase combat detection using non-secret signals only
- Cast History Recorder: Ring buffer with per-spec SavedVariables persistence
- Accuracy Tracker: Real-time and historical accuracy with per-phase breakdown
- Cooldown Overlay: Whitelisted CD tracking with override pair support
- Defensive Advisor: HP-threshold based defensive reminders
- Interrupt Advisor: 12.0-compliant interrupt alerts with sound and visual flash
- Pre-Pull Checker: Flask, food, rune verification before combat
- T-shaped UI layout with keybind display, drag/lock, context menu, scaling
- Resource bar (Secret Value safe)
- Phase indicator with 12 combat phases
- Accuracy meter widget
- Multi-language support: English, Chinese (Simplified), Japanese
- Training pipeline: Python scripts for decision tree and Markov matrix generation
- Full Demon Hunter support: Havoc, Vengeance, Devourer (⚠ Devourer spellIDs unverified)
- Partial support: Evoker (3 specs), Rogue Subtlety, Shaman Elemental, Druid Balance
- APL data for: Warrior Arms/Fury, Mage Fire

### Known Issues
- Devourer (specID 1480) spell IDs are placeholders pending live server verification
- Evoker/Rogue/Shaman/Druid missing SpecEnhancements data (degraded prediction quality)
- No automated tests
