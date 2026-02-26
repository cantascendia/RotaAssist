------------------------------------------------------------------------
-- RotaAssist - APL: Evoker / Devastation (specID 1467)
------------------------------------------------------------------------
local _, RA = ...
if not RA.APLData then RA.APLData = {} end

local APL = {
    specID      = 1467,
    specName    = "Devastation",
    className   = "EVOKER",
    version     = "12.0.2",
    lastUpdated = "2026-02-26",
    author      = "RotaAssist Team",
    profiles    = {}
}

APL.profiles["default"] = {
    singleTarget = {
        { spellID = 375087, priority = 1, condition = "cd_ready", note = "Dragonrage" },
        { spellID = 370455, priority = 2, condition = "cd_ready", note = "Tip the Scales" },
        { spellID = 359073, priority = 3, condition = "buff:tip_the_scales", note = "Eternity Surge (Max Rank Instant)" },
        { spellID = 357208, priority = 4, condition = "debuff_missing:fire_breath", note = "Fire Breath (Empower)" },
        { spellID = 359073, priority = 5, condition = "debuff:fire_breath", note = "Eternity Surge (Rank 1)" },
        { spellID = 356995, priority = 6, condition = "resource>=3", note = "Disintegrate" },
        { spellID = 357209, priority = 7, condition = "always", note = "Living Flame" },
        { spellID = 362969, priority = 8, condition = "moving", note = "Azure Strike (Movement)" },
    },
    aoe = {
        { spellID = 375087, priority = 1, condition = "cd_ready", note = "Dragonrage" },
        { spellID = 357208, priority = 2, condition = "cd_ready", note = "Fire Breath (Max Rank)" },
        { spellID = 359073, priority = 3, condition = "cd_ready", note = "Eternity Surge" },
        { spellID = 357210, priority = 4, condition = "cd_ready", note = "Deep Breath" },
        { spellID = 357211, priority = 5, condition = "resource>=1 AND targets>=3", note = "Pyre" },
        { spellID = 362969, priority = 6, condition = "always", note = "Azure Strike (Build Essence)" },
        { spellID = 357209, priority = 7, condition = "targets<=2", note = "Living Flame" },
    },
    opener = {},
    majorCooldowns = {
        { spellID = 375087, note = "Dragonrage" },
        { spellID = 357210, note = "Deep Breath" },
        { spellID = 370455, note = "Tip the Scales" },
    }
}

local defaultProfile = APL.profiles["default"]
local rules = {}
for _, entry in ipairs(defaultProfile.singleTarget) do
    rules[#rules + 1] = {
        spellID   = entry.spellID,
        name      = entry.note,
        priority  = entry.priority,
        condition = (entry.condition == "cd_ready" or entry.condition:find("cd_ready")) and "ready" or "always",
        reason    = entry.note,
    }
end

RA.APLData[1467] = {
    specID   = APL.specID,
    specName = APL.specName,
    class    = APL.className,
    version  = APL.version,
    author   = APL.author,
    rules    = rules,
    profiles = APL.profiles,
}
