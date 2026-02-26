------------------------------------------------------------------------
-- RotaAssist - APL: Mage / Fire (specID 63)
------------------------------------------------------------------------
local _, RA = ...
if not RA.APLData then RA.APLData = {} end

local APL = {
    specID      = 63,
    specName    = "Fire",
    className   = "MAGE",
    version     = "12.0.2",
    lastUpdated = "2026-02-26",
    author      = "RotaAssist Team",
    profiles    = {}
}

APL.profiles["default"] = {
    singleTarget = {
        { spellID = 190319, priority = 1, condition = "cd_ready", note = "Combustion (Major CD)" },
        { spellID = 257541, priority = 2, condition = "cd_ready AND in_combustion", note = "Phoenix Flames (during Combustion)" },
        { spellID = 11366,  priority = 3, condition = "proc:hot_streak OR in_combustion", note = "Pyroblast (Hot Streak/Combustion)" },
        { spellID = 108853, priority = 4, condition = "proc:heating_up AND charges>=1", note = "Fire Blast (convert to Hot Streak)" },
        { spellID = 133,    priority = 5, condition = "always", note = "Fireball (Filler)" },
        { spellID = 2948,   priority = 6, condition = "moving", note = "Scorch (Movement filler)" }
    },
    aoe = {},
    opener = {},
    majorCooldowns = {
        { spellID = 190319, note = "Combustion" }
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

RA.APLData[63] = {
    specID   = APL.specID,
    specName = APL.specName,
    class    = APL.className,
    version  = APL.version,
    author   = APL.author,
    rules    = rules,
    profiles = APL.profiles,
}
