# RotaAssist — Agent Instructions

> Updated Round 16 (2026-09-01). Full context in `docs/ai-cto/`.

## Project Overview
RotaAssist is a **rotation coach** addon for WoW Midnight — it layers multi-step
lookahead, accuracy feedback, and combat-phase context on top of Blizzard's
Assisted Combat. It does not merely restate Blizzard's suggestion (7 competitors
already do that).

- **Language**: Lua 5.1 (WoW addon), Python 3.11 (training pipeline)
- **Framework**: Ace3 (AceAddon, AceDB, AceEvent, AceLocale, AceTimer, AceConfig)
- **Architecture**: Modular (RegisterModule/GetModule pattern, event-driven)
- **Target client**: **Midnight 12.1.0 — TOC Interface `120100`**
  (the file currently says `120000`; that is 3 patches stale and the game flags
  the addon as out of date)

## Critical Constraints — Midnight Secret Values

**The single most violated rule in this codebase: `pcall` protects the API call,
it does NOT protect the comparison you do afterwards.**

1. Run `issecretvalue()` BEFORE any comparison, arithmetic, or truthiness test on
   values from `UnitPower` / `UnitHealth` / `C_Spell.GetSpellCooldown` /
   `C_Spell.GetSpellCharges` / `C_UnitAuras`.
   - ❌ `mx = (ok and mx and mx > 0 and mx) or 1`  — `mx > 0` already violated it
   - ✅ `if issecretvalue(mx) then return fallback end` first, then compare
   - Known live violations: `PatternDetector.lua:117-119`,
     `NeuralPredictor.lua:261-263`, `SmartQueueManager.lua:388-395`,
     `APLEngine.lua:287-291`, `SmartQueueManager.lua:373`
2. All cooldown reads go through `RA:GetSpellCooldownSafe()`. Never call
   `C_Spell.GetSpellCooldown` directly. Reference implementation:
   `Core/Init.lua:137-201`.
3. Primary resource (Fury/Mana/Rage) is SECRET in combat — drive
   `StatusBar:SetValue()` only, never branch on it. Correct pattern:
   `UI/Widgets/ResourceBar.lua:110-114`.
4. Secondary resources (Soul Fragments, Combo Points, Holy Power) are NON-SECRET.
5. `COMBAT_LOG_EVENT_UNFILTERED` errors on register since 12.0.
   The replacement is `COMBAT_LOG_EVENT_INTERNAL_UNFILTERED`.
6. Prefer `C_Secrets.ShouldUnitPowerBeSecret()` / `ShouldSpellCooldownBeSecret()` /
   `ShouldUnitAuraSlotBeSecret()` / `ShouldUnitHealthMaxBeSecret()` for RUNTIME
   decisions instead of hardcoding dev-time assumptions about what is secret.
   The codebase currently uses zero of these.

## Critical Constraints — APL Data

`APLEngine:EvaluateCondition` (`APLEngine.lua:232-319`) silently returns `false`
for any token it does not recognise (`L310`). **70 of 352 APL rules (19.9%) are
currently dead this way** and neither CI nor the test suite catches it.

Only these tokens are implemented:
```
cd_ready  ready  always  cd_soon:N  after:ID  not_after:ID
estimated_resource OP N   target_count OP N   combat_time OP N
charges OP N   window:X   not_window:X   in_meta   not_in_meta
```
`splitConditions` (`APLEngine.lua:60-67`) splits on uppercase ` AND ` only —
`OR` and lowercase `and` are NOT supported and kill the whole rule.

Do not author rules using `buff:` `debuff:` `debuff_missing:` `debuff_remains:`
`cp>=N` `resource>=N` `target_hp<N` `proc:` `stacks:` `charges:<name>>=N`
`cd_not_ready:ID` — they compile fine and never fire.

## Code Style
- Bilingual comments: English + Chinese (中文). Japanese (日本語) where already present.
- Use `local` for all module-level state
- Zero-allocation patterns: `wipe()` + reuse tables instead of creating new ones in hot paths
- All pcall-protected API calls, never assume WoW APIs are available
- Module lifecycle: `OnInitialize()` → `OnEnable()` → `OnDisable()`

## Build & Test

There is NO CI (GitHub abandoned, see docs/ai-cto/DECISIONS.md D-010).
The local runner is the only regression defense — run it before every commit.

```bash
# Full test suite (506 cases, ~0.3s) — busted-compatible shim w/ file insulation
"/c/Program Files (x86)/Lua/5.1/lua.exe" scripts/run_tests.lua
# filter: ... scripts/run_tests.lua registry sqm

# Syntax check (no luacheck on this machine; luac -p is the substitute)
"/c/Program Files (x86)/Lua/5.1/luac.exe" -p <file.lua>

# Training pipeline test
cd training && pip install -r requirements.txt
python -m pytest test_apl_parser.py -v

# Package for release
./scripts/package.sh 1.0.0
```

## Key Architecture Rules
- Data flows: Bridge → APLEngine → NeuralPredictor → SmartQueueManager → UI
- PASSIVE_BLACKLIST and OVERRIDE_PAIRS live in Data/Registry.lua — do NOT duplicate
- Per-spec data goes in Data/SpecEnhancements/<Class>.lua and Data/APL/<Class>_<Spec>.lua
- Engine modules MUST NOT directly reference UI modules
- All events go through EventHandler:Subscribe/Fire — no direct cross-module calls

## Safety Rules
- Always create a branch before modifying code
- NO git reset --hard, git checkout -- ., rm -rf
- Commit after each logical unit of work
- Push when task is complete

## Lessons Learned (Auto-Updated)

### Round 1-2 Findings
- `Predictor.lua` in `addon/Engine/` is dead code — NOT loaded by TOC. Do not
  modify it; it should be deleted. (The modules it referenced — `AssistCapture`,
  `CooldownTracker`, `RecommendationManager` — were deleted in Round 17 per D-013.)
- SpecEnhancements schema is inconsistent: DH uses `interruptSpellID` (flat),
  Evoker/Rogue use `interruptSpell = { spellID, ... }` (nested). Always use the
  nested format going forward.
- `resource.type` vs `resource.powerType`: Both exist. Prefer `powerType`.
  SmartQueueManager already handles both via fallback.
- Every module that creates frames or C_Timer tickers MUST implement `OnDisable()`
  to clean them up.
