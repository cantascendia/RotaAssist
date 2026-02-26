------------------------------------------------------------------------
-- RotaAssist - Spec Enhancements: Death Knight
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA

RA.SpecEnhancements = RA.SpecEnhancements or {}

------------------------------------------------------------------------
-- Frost (specID 251)
------------------------------------------------------------------------
RA.SpecEnhancements[251] = {
    majorCooldowns = {
        { spellID = 51271, alertThreshold = 10, name = "Pillar of Frost" },
        { spellID = 47568, alertThreshold = 10, name = "Empower Rune Weapon" },
        { spellID = 152279, alertThreshold = 10, name = "Breath of Sindragosa" },
        { spellID = 279302, alertThreshold = 5,  name = "Frostwyrm's Fury" },
    },
    interruptSpell = { spellID = 47528, name = "Mind Freeze", cooldown = 15 },
    defensives = {
        { spellID = 48792, hpThreshold = 0.30, name = "Icebound Fortitude" },
        { spellID = 49998, hpThreshold = 0.40, name = "Death Strike" },
        { spellID = 48707, hpThreshold = 0.60, name = "Anti-Magic Shell" },
    },
    resource = { type = 6, maxBase = 100, spellCosts = {} },  -- Runic Power
    burstWindows = {
        pillar = { trigger = 51271, duration = 12, label = "Pillar of Frost" }
    },
    prePullChecks = {
        flask  = { type = "aura", spellID = 428484, name = "Flask of Tempered Mastery" },
        food   = { type = "aura", spellID = 104273, name = "Well Fed" },
        rune   = { type = "aura", spellID = 270058, name = "Crystallized Augment Rune" },
    },
    inferenceRules = {
        aoeSpells = { 196770, 49184, 279302 },
        singleTargetSpells = { 49020, 49143, 49184 },
        generatorSpells = { 49020, 49184 },
        spenderSpells = { 49143, 279302 },
        burstIndicatorSpells = {},
        burstCooldownSpell = 51271,
        burstDuration = 12,
        executeSpells = {},
    },
    secondaryPowerType = 5, -- Runes (Optional)
}
