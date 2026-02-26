--- RotaAssist Markov Transition Matrix: Warrior Fury (specID 72)
local _, NS = ...
local RA = NS.RA
local TM = {}
TM.specID = 72
TM.generatedDate = "2026-02-26"

TM.matrix = {
    [23881] = { [85288] = 0.35, [184367] = 0.30, [5308] = 0.15, [23881] = 0.10, [190411] = 0.10 },
    [85288] = { [184367] = 0.40, [85288] = 0.25, [23881] = 0.20, [5308] = 0.10, [190411] = 0.05 },
    [184367] = { [85288] = 0.35, [23881] = 0.30, [5308] = 0.15, [184367] = 0.10, [190411] = 0.10 },
    [5308] = { [184367] = 0.35, [85288] = 0.25, [5308] = 0.20, [23881] = 0.15, [190411] = 0.05 },
    [190411] = { [85288] = 0.30, [23881] = 0.25, [184367] = 0.20, [5308] = 0.15, [190411] = 0.10 },
    [227847] = { [184367] = 0.40, [85288] = 0.25, [23881] = 0.20, [190411] = 0.15 },
    [385059] = { [184367] = 0.40, [85288] = 0.25, [23881] = 0.20, [190411] = 0.15 },
    [6343] = { [85288] = 0.30, [23881] = 0.30, [184367] = 0.20, [190411] = 0.20 },
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
RA.TransitionMatrices[72] = TM
