--- RotaAssist Markov Transition Matrix: Warrior Arms (specID 71)
local _, NS = ...
local RA = NS.RA
local TM = {}
TM.specID = 71
TM.generatedDate = "2026-02-26"

TM.matrix = {
    [12294] = { [7384] = 0.40, [1464] = 0.25, [772] = 0.15, [163201] = 0.10, [12294] = 0.10 },
    [7384] = { [12294] = 0.45, [7384] = 0.25, [1464] = 0.15, [163201] = 0.10, [772] = 0.05 },
    [1464] = { [7384] = 0.35, [12294] = 0.30, [1464] = 0.20, [772] = 0.10, [163201] = 0.05 },
    [163201] = { [163201] = 0.40, [12294] = 0.30, [7384] = 0.20, [772] = 0.10 },
    [167105] = { [12294] = 0.40, [163201] = 0.30, [7384] = 0.20, [227847] = 0.10 },
    [227847] = { [12294] = 0.35, [163201] = 0.25, [7384] = 0.25, [1464] = 0.15 },
    [772] = { [12294] = 0.40, [7384] = 0.35, [163201] = 0.15, [1464] = 0.10 },
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
RA.TransitionMatrices[71] = TM
