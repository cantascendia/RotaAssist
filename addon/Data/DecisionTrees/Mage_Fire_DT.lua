--- RotaAssist Decision Tree: Mage Fire (specID 63)
local _, NS = ...
local RA = NS.RA
local DT = {}
DT.specID = 63
DT.generatedDate = "2026-02-26"
DT.treeDepth = 6
DT.trainingAccuracy = 0.80

function DT.Evaluate(features)
    if features.blizzardRecommendation == 2139 then return {spellID=2139, confidence=0.95} end -- Counterspell
    if features.blizzardRecommendation == 190319 then return {spellID=190319, confidence=0.90} end -- Combustion
    if features.blizzardRecommendation == 257541 then return {spellID=257541, confidence=0.88} end -- Phoenix Flames
    if features.blizzardRecommendation == 11366 then return {spellID=11366, confidence=0.90} end -- Pyroblast
    if features.blizzardRecommendation == 108853 then return {spellID=108853, confidence=0.85} end -- Fire Blast
    if features.blizzardRecommendation == 2948 then return {spellID=2948, confidence=0.75} end -- Scorch
    return {spellID=133, confidence=0.55} -- Fireball
end

RA.DecisionTrees = RA.DecisionTrees or {}
RA.DecisionTrees[63] = DT
