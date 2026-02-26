--- RotaAssist Decision Tree: Warrior Arms (specID 71)
local _, NS = ...
local RA = NS.RA
local DT = {}
DT.specID = 71
DT.generatedDate = "2026-02-26"
DT.treeDepth = 6
DT.trainingAccuracy = 0.80

function DT.Evaluate(features)
    if features.blizzardRecommendation == 6552 then return {spellID=6552, confidence=0.95} end -- Pummel
    if features.blizzardRecommendation == 167105 then return {spellID=167105, confidence=0.90} end -- Colossus Smash
    if features.blizzardRecommendation == 772 then return {spellID=772, confidence=0.88} end -- Rend
    if features.blizzardRecommendation == 163201 then return {spellID=163201, confidence=0.89} end -- Execute
    if features.blizzardRecommendation == 12294 then return {spellID=12294, confidence=0.85} end -- Mortal Strike
    if features.blizzardRecommendation == 7384 then return {spellID=7384, confidence=0.80} end -- Overpower
    if features.blizzardRecommendation == 436358 then return {spellID=436358, confidence=0.86} end -- Demolish
    return {spellID=1464, confidence=0.55} -- Slam
end

RA.DecisionTrees = RA.DecisionTrees or {}
RA.DecisionTrees[71] = DT
