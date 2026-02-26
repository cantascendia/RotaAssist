------------------------------------------------------------------------
-- RotaAssist - Transition Matrix: Evoker / Devastation (1467)
------------------------------------------------------------------------
local _, RA = ...
if not RA.TransitionMatrices then RA.TransitionMatrices = {} end

local TM = {
    specID = 1467,
    matrixName = "Devastation_TM",
    version = "12.0.2",
    author = "RotaAssist Team",
    lastUpdated = "2026-02-26",
    matrix = {}
}

-- Initialize empty matrix
TM.matrix = setmetatable({}, {
    __index = function(t, k)
        return setmetatable({}, {
            __index = function() return 0.0 end
        })
    end
})

-- Transition probabilities (spellID -> nextSpellID = probability)
local transitions = {
    [375087] = { [370455] = 0.90 }, -- Dragonrage -> Tip the Scales
    [370455] = { [359073] = 0.95 }, -- Tip the Scales -> Eternity Surge
    [359073] = { [357208] = 0.75 }, -- Eternity Surge -> Fire Breath
    [357208] = { [356995] = 0.70 }, -- Fire Breath -> Disintegrate
    [356995] = { [359073] = 0.55, [357209] = 0.35 }, -- Disintegrate -> Eternity Surge / Living Flame
    [357209] = { [356995] = 0.50 }, -- Living Flame -> Disintegrate
    [362969] = { [357209] = 0.60 }, -- Azure Strike -> Living Flame
}

for fromSpell, toSpells in pairs(transitions) do
    if not rawget(TM.matrix, fromSpell) then
        rawset(TM.matrix, fromSpell, setmetatable({}, { __index = function() return 0.0 end }))
    end
    for toSpell, prob in pairs(toSpells) do
        TM.matrix[fromSpell][toSpell] = prob
    end
end

function TM:GetTransitionProbability(fromSpellID, toSpellID)
    return self.matrix[fromSpellID][toSpellID] or 0.0
end

RA.TransitionMatrices[1467] = TM
