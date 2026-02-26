------------------------------------------------------------------------
-- RotaAssist - APL: Warrior / Fury (specID 72)
------------------------------------------------------------------------
local _, RA = ...
if not RA.APLData then RA.APLData = {} end

local APL = {
    specID      = 72,
    specName    = "Fury",
    className   = "WARRIOR",
    version     = "12.0.2",
    lastUpdated = "2026-02-26",
    author      = "RotaAssist Team",
    profiles    = {}
}

APL.profiles["default"] = {
    singleTarget = {
        { spellID = 1719,   priority = 1, condition = "cd_ready", note = "Recklessness" },
        { spellID = 107574, priority = 2, condition = "buff:recklessness", note = "Avatar (with Recklessness)" },
        { spellID = 184367, priority = 3, condition = "not_enrage", note = "Rampage (not Enraged)" },
        { spellID = 396719, priority = 4, condition = "proc AND enraged", note = "Thunder Blast (Enraged)" },
        { spellID = 227847, priority = 5, condition = "enraged", note = "Bladestorm (Enraged)" },
        { spellID = 5308,   priority = 6, condition = "target_hp<0.20 OR proc:sudden_death", note = "Execute" },
        { spellID = 184367, priority = 7, condition = "resource>110", note = "Rampage (Rage cap)" },
        { spellID = 85288,  priority = 8, condition = "cd_ready", note = "Raging Blow" },
        { spellID = 23881,  priority = 9, condition = "cd_ready", note = "Bloodthirst" },
        { spellID = 5308,   priority = 10, condition = "always", note = "Execute (lower priority)" },
        { spellID = 85288,  priority = 11, condition = "charges>=1", note = "Raging Blow (second charge)" },
        { spellID = 385059, priority = 12, condition = "cd_ready", note = "Odyn's Fury" },
        { spellID = 6343,   priority = 13, condition = "always", note = "Thunder Clap (Filler)" },
        { spellID = 184367, priority = 14, condition = "always", note = "Rampage (dump)" },
        { spellID = 190411, priority = 15, condition = "always", note = "Whirlwind (Filler)" }
    },
    aoe = {},
    opener = {},
    majorCooldowns = {
        { spellID = 1719, note = "Recklessness" },
        { spellID = 107574, note = "Avatar" }
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

RA.APLData[72] = {
    specID   = APL.specID,
    specName = APL.specName,
    class    = APL.className,
    version  = APL.version,
    author   = APL.author,
    rules    = rules,
    profiles = APL.profiles,
}
