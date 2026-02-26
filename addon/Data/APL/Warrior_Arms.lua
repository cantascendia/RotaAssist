------------------------------------------------------------------------
-- RotaAssist - APL: Warrior / Arms (specID 71)
------------------------------------------------------------------------
local _, RA = ...
if not RA.APLData then RA.APLData = {} end

local APL = {
    specID      = 71,
    specName    = "Arms",
    className   = "WARRIOR",
    version     = "12.0.2",
    lastUpdated = "2026-02-26",
    author      = "RotaAssist Team",
    profiles    = {}
}

APL.profiles["default"] = {
    singleTarget = {
        { spellID = 772,    priority = 1, condition = "dot_missing", note = "Rend (Apply/Refresh)" },
        { spellID = 107574, priority = 2, condition = "cd_ready", note = "Avatar" },
        { spellID = 167105, priority = 3, condition = "cd_ready", note = "Colossus Smash" },
        { spellID = 436358, priority = 4, condition = "buff:colossus_smash", note = "Demolish (during CS)" },
        { spellID = 7384,   priority = 5, condition = "charges>=2", note = "Overpower (2 charges)" },
        { spellID = 12294,  priority = 6, condition = "buff:executioners_precision>=2", note = "Mortal Strike (ExePrecision)" },
        { spellID = 163201, priority = 7, condition = "proc:sudden_death", note = "Execute (Sudden Death)" },
        { spellID = 12294,  priority = 8, condition = "cd_ready", note = "Mortal Strike" },
        { spellID = 163201, priority = 9, condition = "target_hp<0.35", note = "Execute (<35%)" },
        { spellID = 227847, priority = 10, condition = "cd_ready", note = "Bladestorm" },
        { spellID = 7384,   priority = 11, condition = "cd_ready", note = "Overpower" },
        { spellID = 1464,   priority = 12, condition = "always", note = "Slam (Filler)" }
    },
    aoe = {},
    opener = {},
    majorCooldowns = {
        { spellID = 167105, note = "Colossus Smash" },
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

RA.APLData[71] = {
    specID   = APL.specID,
    specName = APL.specName,
    class    = APL.className,
    version  = APL.version,
    author   = APL.author,
    rules    = rules,
    profiles = APL.profiles,
}
