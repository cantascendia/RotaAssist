# Changelog

All notable changes to RotaAssist will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1-rc.15] - 2026-09-22

[Public GCD action timing](docs/RELEASE_1.1.1-rc.15.md), implemented by Astra.

- Use event-scoped GCD evidence for independent hints within a maximum 400 ms
  queue horizon; preserve real cooldown, charge and secret-value boundaries.
- Recheck aura and Demonsurge expiry at that horizon without extending history.
- Verify the real main slot without native input, population changes and target loss.
- Validate 756 Lua / 118 Python tests, 170 Lua files and twelve behavioral mutations.
- Keep priority policies and opt-in defaults unchanged; no live DPS claim.

## [1.1.1-rc.14] - 2026-09-22

[Enhanced Eye Beam integration](docs/RELEASE_1.1.1-rc.14.md), implemented by Astra.

- Include current Abyssal Gaze replacements in learned checks, cooldown identity,
  selected Demonic transitions and Chaotic Transformation resets.
- Use shared-base cooldown metadata for post-cast prediction filtering and
  shared-base channel classification.
- Retain a rejected population-priority experiment: no proven performance
  improvement, so both shipped policy files and default settings stay unchanged.
- Validate 741 Lua / 116 Python tests, 169 Lua files and nine behavioral mutations.

## [1.1.1-rc.13] - 2026-09-22

[Havoc action applicability](docs/RELEASE_1.1.1-rc.13.md), implemented by Astra.

- Use explicit current-target melee evidence for three player-centered Havoc
  area actions when a public API confirms they have no target-range check.
- Preserve native true/false range, unknown signals and current-target invalidation.
- Verify real main-queue integration; keep both policies and default settings.
- Add six movement/add-wave SimC comparisons and six event execution traces;
  preserve the larger measured losses and open real-instance acceptance work.
- Validate 731 Lua / 111 Python tests, 169 Lua files and 18 behavioral mutations.

## [1.1.1-rc.12] - 2026-09-22

[Aldrachi Havoc and active replacements](docs/RELEASE_1.1.1-rc.12.md), implemented by Astra.

- Select a separate Aldrachi policy from current complete hero talent evidence.
- Read Reaver's Glaive, Rending Strike and Glaive Flurry public aura facts and
  query current range for actions missing from the older generic APL.
- Retain publicly confirmed learned active replacements through default and
  experimental queue filters, melee probes and resource-bound evidence.
- Freeze and benchmark the same policy exported to Lua: 96.35%–97.27% of the
  reference on six held-out scenarios; experimental mode remains default-off.
- Validate 723 Lua / 109 Python tests, 169 Lua files and ten behavioral mutations.

## [1.1.1-rc.11] - 2026-09-22

[Havoc burst-state tracking](docs/RELEASE_1.1.1-rc.11.md), implemented by Astra.

- Track Fel-Scarred Demonsurge flags from selected talents and public cast events,
  with conservative expiry and confirmation from the real Meta aura.
- Model manual Meta refresh, Demonic spender refresh, per-action consumption and
  invalidation after death, build changes or unconfirmed aura transitions.
- Feed explicit cast-model provenance to the existing experimental independent
  evaluator; do not change the frozen policy or its default-off setting.
- Replay four actual pinned SimC traces: 628 cast-model assertions and 393 public
  absence assertions agree; 878 observations remain unknown. No DPS gain claim.

## [1.1.1-rc.10] - 2026-09-22

[Automatic runtime context](docs/RELEASE_1.1.1-rc.10.md), implemented by Astra.

- Discover the current player's learned active spellbook and overrides without
  personal exports; refresh on specialization, talent and spellbook changes.
- Check current-target range for recommendations across specs, including specs
  without a loaded APL and newly appearing proc replacements.
- Record per-spell targetable enemy lower bounds with identity deduplication,
  combat filtering and explicit unknowns; these are not AoE damage inputs.
- Add bounded storage, generated count invariants and behavioral mutations.
  Universal optimal rotations and live-client compatibility remain unverified.

## [Calibration toolkit 0.1] - 2026-09-22

- Added local character-export normalization preserving equipped item modifiers,
  talents and supplied consumables while removing name/server metadata.
- Compare five frozen-family policies with a pinned reference using the same
  character, multi-target scenarios and separate discovery/holdout seeds.
- Validate simulated character identity and original artifact hashes; expose
  modeled buffed stats, DPS, conservative comparison bounds and raw evidence.
- Standalone ZIP and launcher, verified on two public upstream configurations.
  No live character capture, addon policy replacement or maximum-DPS claim.

## [1.1.1-rc.9] - 2026-09-22

[Talent-aware transitions](docs/RELEASE_1.1.1-rc.9.md), implemented by Astra.

### Fixed
- Havoc Eye Beam respects selected Demonic; unknown selection remains unknown.
- Chaotic Transformation resets simulated Eye Beam and both Blade Dance forms.
- Extend existing form windows and preserve uncertainty at lower-bound expiry.
- Clear cast-based form estimates on build changes. No new DPS qualification.

## [1.1.1-rc.8] - 2026-09-22

[Character-specific context](docs/RELEASE_1.1.1-rc.8.md), implemented by Astra.

### Added
- Guarded talent ranks/choices, hero subtree, gear identity, public attributes and
  relevant spell metadata with separate completeness and snapshot provenance.
- Complete-build profile resolution and independent talent-rank facts; immediately
  invalidate old recommendations and caches on configuration changes.
- Localized `/ra build` diagnostics and independent dynamic-stat refresh.
- Two-build SimC negative controls, generated identity checks and seven behavioral
  mutations. The policy and maximum-DPS qualification remain unchanged.

## [1.1.1-rc.7] - 2026-09-22

[Symbolic state consensus](docs/RELEASE_1.1.1-rc.7.md), implemented by Astra.

### Added
- Bounded all-feasible-state checks preserve correlations between unknown facts,
  distinguish open/equal endpoints and retain possible waiting outcomes.
- Integrate consensus into the existing experimental observer, keeping its
  opt-in, channel guard and fallback behavior.
- Exhaustive generated oracle, mutation checks and synthetic proof-cost evidence.
- Real SimC threshold/structure search and separately frozen elapsed-time phase
  experiments. Retain regressions; neither research candidate replaces the shipped policy.

## [1.1.1-rc.6] - 2026-09-22

[Public-signal decisions](docs/RELEASE_1.1.1-rc.6.md), implemented by Astra.

### Added
- Infer fresh resource bounds from public native usability and minimum costs.
- Read selected public player auras with explicit absence/unknown handling.
- Default-off experimental independent head with localized source badge,
  channel/unknown fallback and lookahead seeded from the actual selected action.
- Generated resource evidence checks and end-to-end independent queue coverage.
  The frozen policy remains below the prior SimC benchmark; no new DPS claim.

## [1.1.1-rc.5] - 2026-09-22

[Independent policy observation](docs/RELEASE_1.1.1-rc.5.md), implemented by Astra.

### Added
- Shared own-policy export for real SimC searches and a Lua decision evaluator.
- Tri-valued conditions and range-count bounds; unresolved earlier actions block
  a different later action instead of treating missing facts as false.
- Live independent diagnostics alongside the queue, cleared on context changes.
- Frozen held-out benchmark evidence: the candidate loses 1.42%–2.68% to the
  stock simulator policy, so it is not promoted to the displayed main action.
- Additive tests, generated policy comparisons and targeted mutation checks.

## [1.1.1-rc.4] - 2026-09-22

[Target-aware local candidate](docs/RELEASE_1.1.1-rc.4.md), implemented by Astra.

### Changed
- Invalidate target-specific recommendations and caches on target changes.
- Use guarded Havoc melee-range observations instead of all visible nameplates.
- Feed per-action range and selected public player/own-target aura expiration
  into lookahead. Keep incomplete counts and unknown aura states explicit.
- Verify generated enemy populations, queue transitions and targeted mutations.
  This is not an exact AoE hit model or a DPS superiority result.

## [1.1.1-rc.3] - 2026-09-22

Local model-correction candidate; [delivery notes](docs/RELEASE_1.1.1-rc.3.md).
Astra now owns coding, review and delivery.

### Fixed
- Correct Havoc generator Fury and Eye Beam/Metamorphosis base cooldowns;
  correct shared Felblade base cooldown and Essence Break APL metadata.
- Exclude passive Glaive Tempest from manual recommendations.
- Use a guarded public resource maximum and preserve observed Fury above the
  static fallback cap.

### Research
- Export the actual loaded model and replay five independent full-state SimC
  traces against baseline/current APLs. Action agreement is not addon DPS.

## [1.1.1-rc.2] - 2026-09-22

Local adaptive-prediction candidate; [delivery notes](docs/RELEASE_1.1.1-rc.2.md).

### Fixed
- Isolate predictive state from caller tables and advance each action's simulated
  time, including the current Blizzard recommendation.
- Consume known charges, use readable recharge metadata, validate opener actions,
  and retain unknown resource/cooldown provenance instead of assuming zero/ready.
- Select Havoc hero profiles by numeric talent spell IDs across client locales.

### Research
- Run a pinned official SimulationCraft reference and explicit APL interventions
  with fixed encounter inputs. These results are not live-addon DPS measurements.
- Document the runtime observation boundary and the remaining performance gates.

## [1.1.1-rc.1] - 2026-09-21

Local installation candidate. No public marketplace release or live-client/DPS
acceptance is claimed. See [delivery notes](docs/RELEASE_1.1.1-rc.1.md) and
[quality evidence requirements](docs/QUALITY_BASELINE.md).

### Changed
- Keep a valid Blizzard suggestion in the main action slot. APL lookahead is a
  sequence; unrelated scored candidates and uncalibrated neural output must not
  fill later steps as though they had been simulated.
- Disable unverified Devourer APL prediction in favor of Blizzard-only behavior.
- Preserve truthful module initialization/enabling status on failure.
- Replace unverified marketplace installation instructions with local ZIP delivery.

### Fixed
- Seed the cooldown panel after its data becomes available; avoid a permanently
  empty panel and repeated rebuilds beyond the icon limit.
- Clean up UI and queue subscriptions, timers, global fades and independent alerts
  on disable. Public empty resource values and protected values are handled safely.
- Preserve repeated lookahead steps through the displayed queue.
- Report the recommendation-following metric as adherence in all three UI locales.
- Package in an isolated staging directory, verify nested TOC/XML dependencies and
  per-file SHA-256 hashes, and retain the previous installation during upgrades.

### Known limitations
- No live client or independent DPS benchmark was available for this delivery.
- Havoc talent profile selection may fall back to default on zhCN/jaJP because
  the current signatures use English talent names.

## [1.1.0] - 2026-09-01

**Release-preparation build.** A public upload is not verified by the current
delivery audit. 1.0.0 was an internal build.
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
