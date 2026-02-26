--- RotaAssist Markov Transition Matrix: Mage Fire (specID 63)
local _, NS = ...
local RA = NS.RA
local TM = {}
TM.specID = 63
TM.generatedDate = "2026-02-26"

TM.matrix = {
    [133] = { [133] = 0.30, [108853] = 0.25, [11366] = 0.20, [2948] = 0.15, [257541] = 0.10 },
    [11366] = { [133] = 0.30, [108853] = 0.25, [257541] = 0.20, [11366] = 0.15, [2948] = 0.10 },
    [108853] = { [11366] = 0.40, [133] = 0.25, [108853] = 0.20, [257541] = 0.15 },
    [2948] = { [11366] = 0.35, [108853] = 0.25, [2948] = 0.20, [133] = 0.20 },
    [257541] = { [11366] = 0.40, [108853] = 0.25, [133] = 0.20, [257541] = 0.15 },
    [190319] = { [108853] = 0.35, [257541] = 0.25, [11366] = 0.25, [2948] = 0.15 },
}

function TM.GetTopTransitions(fromSpellID, topN)
    topN = topN or 3
    local row = TM.matrix[fromSpellID]
    if not row then return {} end
    local result = {}
    for sid, prob in pairs(row) do result[#result + 1] = {spellID = sid, probability = prob} end
    table.sort(result, function(a, b) return a.probability > b.probability end)
    local top = {}
    for i = 1, math.min(topN, #result) do top[i] = result[i] end
    return top
end

RA.TransitionMatrices = RA.TransitionMatrices or {}
RA.TransitionMatrices[63] = TM
