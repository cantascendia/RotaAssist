------------------------------------------------------------------------
-- RotaAssist - Decision Tree: Evoker / Devastation (1467)
------------------------------------------------------------------------
local _, RA = ...
if not RA.DecisionTrees then RA.DecisionTrees = {} end

local DT = {
    specID = 1467,
    treeName = "Devastation_DT",
    version = "12.0.2",
    author = "RotaAssist Team",
    lastUpdated = "2026-02-26"
}

function DT:Evaluate(features)
    local bestSpell = 357209 -- Fallback: Living Flame
    local confidence = 0.85

    if features.buff_dragonrage_active then
        if features.cooldown_357208_ready and (not features.debuff_fire_breath_active or features.debuff_fire_breath_remains < 3) then
            bestSpell = 357208 -- Fire Breath (Extend)
            confidence = 0.95
        elseif features.cooldown_359073_ready then
            bestSpell = 359073 -- Eternity Surge (Extend)
            confidence = 0.92
        elseif features.resource >= 3 then
            bestSpell = 356995 -- Disintegrate
            confidence = 0.88
        elseif features.moving then
            bestSpell = 362969 -- Azure Strike
            confidence = 0.85
        else
            bestSpell = 357209 -- Living Flame
            confidence = 0.85
        end
    else
        if features.cooldown_375087_ready then
            bestSpell = 375087 -- Dragonrage
            confidence = 0.95
        elseif features.buff_tip_the_scales_active and features.cooldown_359073_ready then
            bestSpell = 359073 -- Eternity Surge (Instant)
            confidence = 0.95
        elseif features.cooldown_357208_ready and not features.debuff_fire_breath_active then
            bestSpell = 357208 -- Fire Breath
            confidence = 0.90
        elseif features.cooldown_359073_ready then
            bestSpell = 359073 -- Eternity Surge
            confidence = 0.88
        elseif features.resource >= 3 then
            bestSpell = 356995 -- Disintegrate
            confidence = 0.88
        elseif features.moving then
            bestSpell = 362969 -- Azure Strike
            confidence = 0.85
        else
            bestSpell = 357209 -- Living Flame
            confidence = 0.82
        end
    end

    if features.enemies_in_range >= 3 then
        if features.cooldown_375087_ready then
            bestSpell = 375087 -- Dragonrage
            confidence = 0.95
        elseif features.cooldown_357208_ready then
            bestSpell = 357208 -- Fire Breath (Max Rank)
            confidence = 0.92
        elseif features.cooldown_359073_ready then
            bestSpell = 359073 -- Eternity Surge
            confidence = 0.90
        elseif features.cooldown_357210_ready then
            bestSpell = 357210 -- Deep Breath
            confidence = 0.88
        elseif features.resource >= 1 then
            bestSpell = 357211 -- Pyre (replaces Disintegrate)
            confidence = 0.85
        else
            bestSpell = 362969 -- Azure Strike
            confidence = 0.82
        end
    end

    return bestSpell, confidence
end

RA.DecisionTrees[1467] = DT
