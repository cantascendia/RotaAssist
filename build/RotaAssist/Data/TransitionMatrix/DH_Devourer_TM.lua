--- RotaAssist Markov Transition Matrix: DemonHunter Devourer (specID 1480)
--- Hand-crafted default based on early Devourer rotation guides.
-- 吞噬者默认马尔可夫矩阵 / Devourer default Markov matrix
--
-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  ⚠  EVERY spellID IN THIS MATRIX IS UNVERIFIED (D-015)           ║
-- ║  ⚠  本矩阵中的每一个 spellID 都尚未真机验证（D-015）              ║
-- ╚══════════════════════════════════════════════════════════════════╝
--   Both the row keys and the column keys come from early 12.0 datamining,
--   not from a live client. Treat the whole table as provisional.
--   行键与列键都来自 12.0 早期数据挖掘而非真机，整张表都是临时值。
--
--   RUNTIME DEFENSE / 运行时防御:
--     Markov output is not trusted on its own. Everything NeuralPredictor
--     produces from this matrix passes through SmartQueueManager's final
--     gate (Engine/SmartQueueManager.lua:774-778 → RA:IsSpellRecommendable,
--     Core/Init.lua:272-300), which drops any spell IsPlayerSpell() says the
--     player does not have. A wrong ID silently disappears from the queue.
--     马尔可夫输出不被单独信任。NeuralPredictor 基于本矩阵产出的推荐都要过
--     SmartQueueManager 的最终闸门（SmartQueueManager.lua:774-778 →
--     RA:IsSpellRecommendable，Init.lua:272-300），其中的 IsPlayerSpell()
--     检查会剔除玩家没有的技能。错误的 ID 会静默从队列中消失。
--
--   TO AUDIT / 如何自查:  in-game `/ra aplcheck` reports unresolvable
--     spellIDs found in the APL; cross-check this matrix against the same
--     Wowhead / `/dump C_Spell.GetSpellInfo(SPELLID)` results.
--     游戏内 `/ra aplcheck` 会报告 APL 中解析失败的 spellID；本矩阵请用同样的
--     Wowhead / `/dump C_Spell.GetSpellInfo(SPELLID)` 结果交叉核对。

local _, NS = ...
local RA = NS.RA
local TM = {}

TM.specID = 1480
TM.generatedDate = "2026-02-25"

TM.matrix = {
    [442501] = {  -- Consume
        [442515] = 0.30,  -- -> Reap
        [442507] = 0.20,  -- -> Void Ray
        [442510] = 0.18,  -- -> Collapsing Star
        [258920] = 0.12,  -- -> Immolation Aura
        [442501] = 0.10,  -- -> Consume
        [442525] = 0.10,  -- -> Soul Immolation
    },
    [442515] = {  -- Reap
        [442501] = 0.30,  -- -> Consume
        [442507] = 0.25,  -- -> Void Ray
        [442510] = 0.15,  -- -> Collapsing Star
        [258920] = 0.12,  -- -> Immolation Aura
        [442525] = 0.10,  -- -> Soul Immolation
        [442515] = 0.08,  -- -> Reap
    },
    [442507] = {  -- Void Ray
        [442501] = 0.30,  -- -> Consume
        [442515] = 0.25,  -- -> Reap
        [442510] = 0.15,  -- -> Collapsing Star
        [258920] = 0.12,  -- -> Immolation Aura
        [442507] = 0.10,  -- -> Void Ray
        [442525] = 0.08,  -- -> Soul Immolation
    },
    [442510] = {  -- Collapsing Star
        [442501] = 0.35,  -- -> Consume
        [442515] = 0.20,  -- -> Reap
        [442507] = 0.15,  -- -> Void Ray
        [258920] = 0.12,  -- -> Immolation Aura
        [442525] = 0.10,  -- -> Soul Immolation
        [442510] = 0.08,  -- -> Collapsing Star
    },
    [258920] = {  -- Immolation Aura
        [442501] = 0.30,  -- -> Consume
        [442515] = 0.25,  -- -> Reap
        [442507] = 0.15,  -- -> Void Ray
        [442510] = 0.12,  -- -> Collapsing Star
        [442525] = 0.10,  -- -> Soul Immolation
        [258920] = 0.08,  -- -> Immolation Aura
    },
    [442508] = {  -- Void Metamorphosis
        [442507] = 0.30,  -- -> Void Ray
        [442510] = 0.25,  -- -> Collapsing Star
        [442525] = 0.20,  -- -> Soul Immolation
        [442501] = 0.15,  -- -> Consume
        [258920] = 0.10,  -- -> Immolation Aura
    },
    [442525] = {  -- Soul Immolation
        [442501] = 0.30,  -- -> Consume
        [442515] = 0.25,  -- -> Reap
        [442507] = 0.15,  -- -> Void Ray
        [442510] = 0.12,  -- -> Collapsing Star
        [258920] = 0.10,  -- -> Immolation Aura
        [442525] = 0.08,  -- -> Soul Immolation
    },
    [442520] = {  -- Voidblade
        [442501] = 0.30,  -- -> Consume
        [442507] = 0.25,  -- -> Void Ray
        [442515] = 0.15,  -- -> Reap
        [442510] = 0.12,  -- -> Collapsing Star
        [258920] = 0.10,  -- -> Immolation Aura
        [442525] = 0.08,  -- -> Soul Immolation
    },
}

--- Get top N most probable next spells.
--- @param fromSpellID number
--- @param topN number
--- @return table
function TM.GetTopTransitions(fromSpellID, topN)
    topN = topN or 3
    local row = TM.matrix[fromSpellID]
    if not row then return {} end
    local result = {}
    for sid, prob in pairs(row) do
        result[#result + 1] = {spellID = sid, probability = prob}
    end
    table.sort(result, function(a, b) return a.probability > b.probability end)
    local top = {}
    for i = 1, math.min(topN, #result) do top[i] = result[i] end
    return top
end

RA.TransitionMatrices = RA.TransitionMatrices or {}
RA.TransitionMatrices[1480] = TM
