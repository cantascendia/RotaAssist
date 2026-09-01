-- tests/test_apl_spell_validation.lua
-- Negative-path coverage for APLEngine's unknown-spellID defense (D-015).
-- APLEngine 未知 spellID 防御的负路径测试（D-015）。
--
-- Why a dedicated file / 为什么单开一个文件:
--   tests/mock_wow_api.lua:130 makes C_Spell.GetSpellInfo return a table for
--   EVERY id, so the whole existing suite exercises only the happy path. These
--   tests temporarily swap in a GetSpellInfo that returns nil for chosen ids —
--   the only way to prove that unresolvable rules are recorded AND disabled.
--   Every swap is restored, mirroring tests/test_sqm_integration.lua:52-61.
--   mock 的 C_Spell.GetSpellInfo 对任意 ID 都返回表，现有测试因此只覆盖正路径。
--   这里临时换成对指定 ID 返回 nil 的实现，才能验证"记录 + 禁用"两件事都发生。
--   每次替换后都还原，沿用 tests/test_sqm_integration.lua:52-61 的模式。
--
-- Test-Lock note (铁律 #14): this file only ADDS coverage for a scenario that
-- had none. No existing assertion is modified — legitimate scenario 3.
local helpers = require("tests.helpers")

-- spellIDs the fake client does not know about. Chosen well outside the ranges
-- used by the real data files so nothing else can collide with them.
-- 假客户端不认识的 spellID，取值远离真实数据文件用到的区间，避免碰撞。
local GHOST_A = 99900001
local GHOST_B = 99900002
local GHOST_C = 99900003
local REAL_A  = 162243  -- Demon's Bite
local REAL_B  = 162794  -- Chaos Strike

describe("APLEngine unknown spellID defense (D-015)", function()
    local RA, ns, APL

    --- Run `fn` with C_Spell.GetSpellInfo returning nil for `missing` ids.
    --- 在 C_Spell.GetSpellInfo 对 `missing` 中的 ID 返回 nil 的情况下执行 fn。
    ---@param missing table<number, boolean>
    ---@param fn function
    local function withMissingSpells(missing, fn)
        local orig = C_Spell.GetSpellInfo
        C_Spell.GetSpellInfo = function(spellID)
            if missing[spellID] then return nil end
            return { name = "MockSpell" .. tostring(spellID), castTime = 0 }
        end
        local ok, err = pcall(fn)
        C_Spell.GetSpellInfo = orig
        if not ok then error(err, 0) end
    end

    --- Collect the diagnostics recorded for one specID.
    --- 取出某个专精的诊断条目。
    ---@param specID number
    ---@return table[]
    local function entriesForSpec(specID)
        local out = {}
        for i = 1, #APL.unknownSpells do
            local e = APL.unknownSpells[i]
            if e.specID == specID then out[#out + 1] = e end
        end
        return out
    end

    --- Does this prediction array contain `spellID`?
    ---@param predictions table[]
    ---@param spellID number
    ---@return boolean
    local function predicts(predictions, spellID)
        for i = 1, #predictions do
            if predictions[i].spellID == spellID then return true end
        end
        return false
    end

    setup(function()
        RA, ns = helpers.loadAddon()
        helpers.loadRegistry(ns)
        helpers.loadAddonFile("addon/Engine/APLEngine.lua", "RotaAssist", ns)
        APL = RA:GetModule("APLEngine")
    end)

    -- ================================================================
    -- Diagnostics table
    -- ================================================================
    describe("diagnostics table", function()
        it("exposes APLEngine.unknownSpells", function()
            assert.is_table(APL.unknownSpells)
        end)

        it("records nothing while every spellID resolves", function()
            -- specID 9100: default mock resolves everything.
            local before = #APL.unknownSpells
            APL:SetAPL(9100, { rules = {
                { spellID = REAL_A, condition = "always", priority = 1 },
                { spellID = REAL_B, condition = "always", priority = 2 },
            } }, 12)
            assert.equals(before, #APL.unknownSpells)
        end)
    end)

    -- ================================================================
    -- Flat rule list: unresolvable rules are removed at load time
    -- ================================================================
    describe("flat rule list pruning", function()
        local aplData

        setup(function()
            aplData = { rules = {
                { spellID = REAL_A,  condition = "always", priority = 1, note = "keep me" },
                { spellID = GHOST_A, condition = "always", priority = 2, note = "ghost rule" },
                { spellID = REAL_B,  condition = "always", priority = 3 },
            } }
            withMissingSpells({ [GHOST_A] = true }, function()
                APL:SetAPL(9101, aplData, 12)
            end)
        end)

        it("removes the rule whose spellID does not resolve", function()
            assert.equals(2, #aplData.rules)
        end)

        it("keeps the rules whose spellIDs do resolve", function()
            assert.equals(REAL_A, aplData.rules[1].spellID)
            assert.equals(REAL_B, aplData.rules[2].spellID)
        end)

        it("records one diagnostic entry for the missing spellID", function()
            local entries = entriesForSpec(9101)
            assert.equals(1, #entries)
            assert.equals(GHOST_A, entries[1].spellID)
        end)

        it("records specID, note and pruned disposition", function()
            local e = entriesForSpec(9101)[1]
            assert.equals(9101, e.specID)
            assert.equals("ghost rule", e.note)
            assert.is_true(e.pruned)
        end)

        it("never predicts the removed spell", function()
            local predictions = APL:PredictNext(nil, { resource = 100, cooldowns = {} }, 3)
            assert.is_false(predicts(predictions, GHOST_A))
        end)
    end)

    -- ================================================================
    -- Profile action lists (singleTarget / aoe) and the step-indexed opener
    -- ================================================================
    describe("profile pruning", function()
        local aplData

        setup(function()
            aplData = {
                profiles = {
                    default = {
                        singleTarget = {
                            { spellID = GHOST_B, condition = "always", priority = 1, note = "ghost ST" },
                            { spellID = REAL_A,  condition = "always", priority = 2 },
                        },
                        aoe = {
                            { spellID = GHOST_B, condition = "always", priority = 1 },
                            { spellID = REAL_B,  condition = "always", priority = 2 },
                        },
                        opener = {
                            { spellID = GHOST_C, step = 1, note = "ghost opener" },
                            { spellID = REAL_A,  step = 2 },
                        },
                    },
                },
            }
            withMissingSpells({ [GHOST_B] = true, [GHOST_C] = true }, function()
                APL:SetAPL(9102, aplData, 12)
            end)
        end)

        it("prunes singleTarget", function()
            assert.equals(1, #aplData.profiles.default.singleTarget)
            assert.equals(REAL_A, aplData.profiles.default.singleTarget[1].spellID)
        end)

        it("prunes aoe", function()
            assert.equals(1, #aplData.profiles.default.aoe)
            assert.equals(REAL_B, aplData.profiles.default.aoe[1].spellID)
        end)

        it("de-duplicates one spellID appearing in several lists", function()
            local hits = 0
            for _, e in ipairs(entriesForSpec(9102)) do
                if e.spellID == GHOST_B then hits = hits + 1 end
            end
            assert.equals(1, hits)
        end)

        it("counts every rule the missing spellID appeared in", function()
            for _, e in ipairs(entriesForSpec(9102)) do
                if e.spellID == GHOST_B then
                    assert.equals(2, e.count)
                end
            end
        end)

        it("flags but does NOT delete step-indexed opener entries", function()
            -- Deleting would desynchronise entry.step from the array index.
            -- 删除会让 entry.step 与数组下标错位。
            assert.equals(2, #aplData.profiles.default.opener)
            for _, e in ipairs(entriesForSpec(9102)) do
                if e.spellID == GHOST_C then
                    assert.is_false(e.pruned)
                end
            end
        end)

        it("skips the flagged opener entry at prediction time", function()
            local predictions = APL:PredictNext(nil,
                { resource = 100, cooldowns = {}, combatDuration = 0 }, 3)
            assert.is_false(predicts(predictions, GHOST_C))
        end)

        it("still predicts the resolvable opener entry", function()
            local predictions = APL:PredictNext(nil,
                { resource = 100, cooldowns = {}, combatDuration = 0 }, 3)
            assert.is_true(predicts(predictions, REAL_A))
        end)
    end)

    -- ================================================================
    -- Degrade-open behaviour and reporting
    -- ================================================================
    describe("undecidable checks degrade open", function()
        it("keeps every rule when C_Spell.GetSpellInfo errors", function()
            local orig = C_Spell.GetSpellInfo
            C_Spell.GetSpellInfo = function() error("simulated API failure") end
            local aplData = { rules = {
                { spellID = GHOST_A, condition = "always", priority = 1 },
            } }
            local ok, err = pcall(function() APL:SetAPL(9103, aplData, 12) end)
            C_Spell.GetSpellInfo = orig
            assert.is_true(ok, tostring(err))
            assert.equals(1, #aplData.rules)
        end)
    end)

    describe("aplcheck report", function()
        it("prints without erroring while diagnostics exist", function()
            assert.is_true(#APL.unknownSpells > 0)
            assert.has_no.errors(function()
                APL:PrintConditionReport()
            end)
        end)
    end)

    -- ================================================================
    -- Mock restoration
    -- ================================================================
    describe("mock hygiene", function()
        it("leaves C_Spell.GetSpellInfo resolving every id again", function()
            assert.is_table(C_Spell.GetSpellInfo(GHOST_A))
            assert.is_table(C_Spell.GetSpellInfo(REAL_A))
        end)
    end)
end)
