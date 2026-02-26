------------------------------------------------------------------------
-- RotaAssist - Spec Enhancements: Evoker
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA

RA.SpecEnhancements = RA.SpecEnhancements or {}

------------------------------------------------------------------------
-- Devastation (specID 1467)
------------------------------------------------------------------------
RA.SpecEnhancements[1467] = {
    majorCooldowns = {
        { spellID = 375087, name = "Dragonrage",     alertThreshold = 10 },
        { spellID = 357210, name = "Deep Breath",    alertThreshold = 5  },
        { spellID = 370455, name = "Tip the Scales", alertThreshold = 5  },
    },
    interruptSpell = { spellID = 351338, name = "Quell", cooldown = 40 },
    defensives = {
        { spellID = 363916, name = "Obsidian Scales", hpThreshold = 0.50 },
        { spellID = 374348, name = "Renewing Blaze",  hpThreshold = 0.35 },
        { spellID = 370665, name = "Rescue (self)",   hpThreshold = 0.20 },
    },
    resource = {
        type = 19, -- Essence
        maxBase = 5,
        spellCosts = {
            [357208] = 1,
            [359073] = 1,
            [356995] = 3,
            [357209] = 0,
            [362969] = 0,
            [357211] = 1,
        },
    },
    burstWindows = {
        dragonrage = { trigger = 375087, name = "Dragonrage", duration = 18 },
    },
    prePullChecks = {
        flask = { type = "aura", spellID = 428484, name = "Flask of Tempered Mastery" },
        food  = { type = "aura", spellID = 104273, name = "Well Fed" },
        rune  = { type = "aura", spellID = 270058, name = "Crystallized Augment Rune" },
    },
    inferenceRules = {
        aoeSpells            = { 357211, 362969, 357210, 357208 },
        singleTargetSpells   = { 356995, 357208, 359073, 357209 },
        generatorSpells     = { 357209, 362969 },
        spenderSpells       = { 356995, 357211, 357208, 359073 },
        burstIndicatorSpells = { 375087 },
        burstCooldownSpell  = 375087,
        burstDuration  = 18,
        executeSpells = {},
    },
    secondaryPowerType = nil,
}
