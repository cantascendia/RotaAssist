--- RotaAssist Decision Tree: Warrior Fury (specID 72)
local _, NS = ...
local RA = NS.RA
local DT = {}
DT.specID = 72
DT.generatedDate = "2026-02-26"
DT.treeDepth = 6
DT.trainingAccuracy = 0.80

function DT.Evaluate(features)
    if features.blizzardRecommendation == 6552 then return {spellID=6552, confidence=0.95} end -- Pummel
    if features.blizzardRecommendation == 1719 then return {spellID=1719, confidence=0.90} end -- Recklessness
    if features.nameplateCount >= 3 then
        if features.blizzardRecommendation == 227847 then return {spellID=227847, confidence=0.88} end -- Bladestorm
        if features.blizzardRecommendation == 190411 then return {spellID=190411, confidence=0.85} end -- Whirlwind
    end
    if features.blizzardRecommendation == 184367 then return {spellID=184367, confidence=0.85} end -- Rampage
    if features.blizzardRecommendation == 5308 then return {spellID=5308, confidence=0.88} end -- Execute
    if features.blizzardRecommendation == 396719 then return {spellID=396719, confidence=0.86} end -- Thunder Blast
    if features.blizzardRecommendation == 23881 then return {spellID=23881, confidence=0.80} end -- Bloodthirst
    return {spellID=85288, confidence=0.55} -- Raging Blow
end

RA.DecisionTrees = RA.DecisionTrees or {}
RA.DecisionTrees[72] = DT
