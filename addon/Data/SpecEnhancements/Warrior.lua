------------------------------------------------------------------------
-- RotaAssist - Spec Enhancements: Warrior
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA

RA.SpecEnhancements = RA.SpecEnhancements or {}

------------------------------------------------------------------------
-- Fury (specID 72)
------------------------------------------------------------------------
RA.SpecEnhancements[72] = {
    majorCooldowns = {
        { spellID = 1719, alertThreshold = 10, name = "Recklessness" },
        { spellID = 107574, alertThreshold = 10, name = "Avatar" },
        { spellID = 227847, alertThreshold = 10, name = "Bladestorm" },
        { spellID = 385059, alertThreshold = 5,  name = "Odyn's Fury" },
    },
    interruptSpell = { spellID = 6552, name = "Pummel", cooldown = 15 },
    defensives = {
        { spellID = 97462, hpThreshold = 0.30, name = "Rallying Cry" },
        { spellID = 184364, hpThreshold = 0.40, name = "Enraged Regeneration" },
        { spellID = 23920, hpThreshold = 0.50, name = "Spell Reflection" },
    },
    resource = { type = 1, maxBase = 100, spellCosts = {} },  -- Rage
    burstWindows = {
        recklessness = { trigger = 1719, duration = 12, label = "Recklessness" }
    },
    prePullChecks = {
        flask  = { type = "aura", spellID = 428484, name = "Flask of Tempered Mastery" },
        food   = { type = "aura", spellID = 104273, name = "Well Fed" },
        rune   = { type = "aura", spellID = 270058, name = "Crystallized Augment Rune" },
    },
    inferenceRules = {
        aoeSpells = { 190411, 227847, 6343, 385059 },
        singleTargetSpells = { 85288, 23881, 184367, 5308 },
        generatorSpells = { 85288, 23881 },
        spenderSpells = { 184367, 227847 },
        burstIndicatorSpells = {},
        burstCooldownSpell = 1719,
        burstDuration = 12,
        executeSpells = { 5308 },
    },
    secondaryPowerType = nil,
}

------------------------------------------------------------------------
-- Arms (specID 71)
------------------------------------------------------------------------
RA.SpecEnhancements[71] = {
    majorCooldowns = {
        { spellID = 167105, alertThreshold = 5,  name = "Colossus Smash" },
        { spellID = 107574, alertThreshold = 10, name = "Avatar" },
        { spellID = 227847, alertThreshold = 10, name = "Bladestorm" },
    },
    interruptSpell = { spellID = 6552, name = "Pummel", cooldown = 15 },
    defensives = {
        { spellID = 97462, hpThreshold = 0.25, name = "Rallying Cry" },
        { spellID = 118038, hpThreshold = 0.30, name = "Die by the Sword" },
        { spellID = 197690, hpThreshold = 0.50, name = "Defensive Stance" },
        { spellID = 190456, hpThreshold = 0.60, name = "Ignore Pain" },
    },
    resource = { type = 1, maxBase = 100, spellCosts = {} },  -- Rage
    burstWindows = {
        colossusSmash = { trigger = 167105, duration = 10, label = "Colossus Smash" }
    },
    prePullChecks = {
        flask  = { type = "aura", spellID = 428484, name = "Flask of Tempered Mastery" },
        food   = { type = "aura", spellID = 104273, name = "Well Fed" },
        rune   = { type = "aura", spellID = 270058, name = "Crystallized Augment Rune" },
    },
    inferenceRules = {
        aoeSpells = { 845, 227847, 228920 },
        singleTargetSpells = { 12294, 7384, 1464, 163201 },
        generatorSpells = { 7384, 23922 },
        spenderSpells = { 12294, 1464, 163201 },
        burstIndicatorSpells = {},
        burstCooldownSpell = 167105,
        burstDuration = 10,
        executeSpells = { 163201 },
    },
    secondaryPowerType = nil,
}
