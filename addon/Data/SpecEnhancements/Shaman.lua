------------------------------------------------------------------------
-- RotaAssist - Spec Enhancements: Shaman
------------------------------------------------------------------------

local _, NS = ...
local RA = NS.RA

RA.SpecEnhancements = RA.SpecEnhancements or {}

------------------------------------------------------------------------
-- Enhancement (specID 263)
------------------------------------------------------------------------
RA.SpecEnhancements[263] = {
    majorCooldowns = {
        { spellID = 114051, name = "Ascendance",      alertThreshold = 10 },
        { spellID = 384352, name = "Doom Winds",      alertThreshold = 5  },
        { spellID = 197214, name = "Sundering",       alertThreshold = 5  },
        { spellID = 375982, name = "Primordial Wave", alertThreshold = 5  },
    },
    interruptSpell = { spellID = 57994, name = "Wind Shear", cooldown = 12 },
    defensives = {
        { spellID = 108271, name = "Astral Shift",       hpThreshold = 0.40 },
        { spellID = 198103, name = "Earth Elemental",    hpThreshold = 0.25 },
        { spellID = 462854, name = "Ancestral Guidance", hpThreshold = 0.45 },
    },
    resource = {
        type = 0,
        secondary = {
            name = "Maelstrom Weapon",
            max  = 10,
            spendAt = 5,
            procChance = 0.20,
        },
        spellCosts = {
            [17364] = 0,
            [60103] = 0,
            [187874] = 0,
            [188196] = "5-10 MW stacks",
            [188443] = "5-10 MW stacks",
            [462620] = 0,
            [384063] = 0,
        },
    },
    burstWindows = {
        ascendance = { trigger = 114051, name = "Ascendance", duration = 15 },
        doomWinds  = { trigger = 384352, name = "Doom Winds", duration = 8  },
    },
    prePullChecks = {
        flask = { type = "aura", spellID = 428484, name = "Flask of Tempered Mastery" },
        food  = { type = "aura", spellID = 104273, name = "Well Fed" },
        rune  = { type = "aura", spellID = 270058, name = "Crystallized Augment Rune" },
        weaponImbues = { mainHand = "Windfury Weapon", offHand = "Flametongue Weapon" },
        shields = { "Lightning Shield" },
    },
    inferenceRules = {
        aoeSpells            = { 187874, 188443, 197214, 384063 },
        singleTargetSpells   = { 17364, 60103, 188196, 462620 },
        generatorSpells     = { 17364, 60103, 187874 },
        spenderSpells       = { 188196, 188443, 462856 },
        burstIndicatorSpells = { 114051, 384352 },
        burstCooldownSpell  = 114051,
        burstDuration  = 15,
        executeSpells = {},
    },
    secondaryPowerType = 11, -- Maelstrom
}
