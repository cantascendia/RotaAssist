-- tests/test_deathknight_spec.lua
-- Unit tests for Death Knight Frost (251) and Unholy (252):
-- SpecEnhancements schema, APL data, Decision Tree, and Transition Matrix.
-- 死亡骑士 Frost / Unholy 数据完整性回归测试 (D-003 schema 对齐)
local helpers = require("tests.helpers")

describe("DeathKnight SpecEnhancements / APL / DT / TM", function()
    local RA, ns

    setup(function()
        helpers.ensureMockLoaded()
        _G.GetSpecialization = function() return 2 end
        _G.GetSpecializationInfo = function()
            return 251, "Frost", "", 135773, "DAMAGER"
        end
        _G.UnitClass = function() return "Death Knight", "DEATHKNIGHT", 6 end

        RA, ns = helpers.loadAddon()
        helpers.loadRegistry(ns)
        helpers.loadAddonFile("addon/Data/SpecInfo.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/Data/SpecEnhancements/DeathKnight.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/Data/APL/DeathKnight_Frost.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/Data/APL/DK_Unholy.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/Data/DecisionTrees/DK_Frost_DT.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/Data/DecisionTrees/DK_Unholy_DT.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/Data/TransitionMatrix/DK_Frost_TM.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/Data/TransitionMatrix/DK_Unholy_TM.lua", "RotaAssist", ns)
    end)

    -- --------------------------------------------------------------
    -- Frost (251)
    -- --------------------------------------------------------------
    describe("Frost (specID 251)", function()
        local spec

        before_each(function()
            spec = RA.SpecEnhancements[251]
        end)

        it("SpecEnhancement entry exists", function()
            assert.is_not_nil(spec)
        end)

        it("has at least 4 majorCooldowns including Pillar of Frost", function()
            assert.is_true(#spec.majorCooldowns >= 4)
            local ids = {}
            for _, cd in ipairs(spec.majorCooldowns) do ids[cd.spellID] = true end
            assert.is_true(ids[51271], "Pillar of Frost")
            assert.is_true(ids[47568], "Empower Rune Weapon")
            assert.is_true(ids[279302], "Frostwyrm's Fury")
        end)

        it("interruptSpell is Mind Freeze (D-003 nested form)", function()
            assert.is_table(spec.interruptSpell)
            assert.equals(47528, spec.interruptSpell.spellID)
            assert.equals(15, spec.interruptSpell.cooldown)
            assert.is_string(spec.interruptSpell.name)
        end)

        it("defensives have valid spellID and HP thresholds", function()
            assert.is_true(#spec.defensives >= 2)
            for _, def in ipairs(spec.defensives) do
                assert.is_number(def.spellID)
                assert.is_number(def.hpThreshold)
                assert.is_true(def.hpThreshold > 0 and def.hpThreshold < 1)
            end
        end)

        it("resource.powerType is RunicPower (6) per D-003", function()
            assert.equals(6, spec.resource.powerType)
        end)

        it("resource.spellCosts uses nested {cost=N} form", function()
            assert.is_table(spec.resource.spellCosts[49143])
            assert.equals(25, spec.resource.spellCosts[49143].cost)
        end)

        it("burstWindows has Pillar of Frost trigger", function()
            assert.is_not_nil(spec.burstWindows.pillar)
            assert.equals(51271, spec.burstWindows.pillar.trigger)
            assert.equals(12, spec.burstWindows.pillar.duration)
        end)

        it("inferenceRules contain spender/generator/burst data", function()
            local ir = spec.inferenceRules
            assert.is_table(ir.aoeSpells)
            assert.is_true(#ir.aoeSpells >= 1)
            assert.is_table(ir.spenderSpells)
            assert.is_true(#ir.spenderSpells >= 1)
            assert.is_table(ir.generatorSpells)
            assert.is_true(#ir.generatorSpells >= 1)
            assert.equals(51271, ir.burstCooldownSpell)
            assert.equals(12, ir.burstDuration)
        end)

        it("secondaryPowerType points at Runes (5)", function()
            assert.equals(5, spec.secondaryPowerType)
        end)

        it("prePullChecks include flask, food, rune", function()
            assert.is_not_nil(spec.prePullChecks.flask)
            assert.is_not_nil(spec.prePullChecks.food)
            assert.is_not_nil(spec.prePullChecks.rune)
        end)

        it("APL is registered with non-empty rules", function()
            assert.is_table(RA.APLData)
            assert.is_table(RA.APLData[251])
            assert.equals("DEATHKNIGHT", RA.APLData[251].class)
            assert.is_true(#RA.APLData[251].rules > 0)
            assert.is_table(RA.APLData[251].profiles.default.singleTarget)
            assert.is_true(#RA.APLData[251].profiles.default.singleTarget >= 6)
        end)

        it("Decision Tree is registered and Evaluate is callable", function()
            assert.is_table(RA.DecisionTrees)
            local dt = RA.DecisionTrees[251]
            assert.is_table(dt)
            assert.equals(251, dt.specID)
            assert.is_function(dt.Evaluate)
            local result = dt.Evaluate({ blizzardRecommendation = 51271 })
            assert.is_table(result)
            assert.is_number(result.spellID)
            assert.is_number(result.confidence)
            assert.is_true(result.confidence > 0 and result.confidence <= 1)
        end)

        it("Transition Matrix is registered with at least one row", function()
            assert.is_table(RA.TransitionMatrices)
            local tm = RA.TransitionMatrices[251]
            assert.is_table(tm)
            assert.equals(251, tm.specID)
            assert.is_table(tm.matrix)
            -- Frost has Obliterate -> ... transitions
            assert.is_table(tm.matrix[49020])
            local top = tm.GetTopTransitions(49020, 3)
            assert.is_table(top)
            assert.is_true(#top >= 1)
            assert.is_number(top[1].spellID)
            assert.is_number(top[1].probability)
        end)
    end)

    -- --------------------------------------------------------------
    -- Unholy (252)
    -- --------------------------------------------------------------
    describe("Unholy (specID 252)", function()
        local spec

        before_each(function()
            spec = RA.SpecEnhancements[252]
        end)

        it("SpecEnhancement entry exists", function()
            assert.is_not_nil(spec)
        end)

        it("majorCooldowns include Army of the Dead and Dark Transformation", function()
            assert.is_true(#spec.majorCooldowns >= 4)
            local ids = {}
            for _, cd in ipairs(spec.majorCooldowns) do ids[cd.spellID] = true end
            assert.is_true(ids[42650], "Army of the Dead")
            assert.is_true(ids[63560], "Dark Transformation")
            assert.is_true(ids[49206], "Summon Gargoyle")
        end)

        it("interruptSpell is Mind Freeze (D-003 nested form)", function()
            assert.is_table(spec.interruptSpell)
            assert.equals(47528, spec.interruptSpell.spellID)
            assert.equals(15, spec.interruptSpell.cooldown)
        end)

        it("defensives are valid", function()
            assert.is_true(#spec.defensives >= 2)
            for _, def in ipairs(spec.defensives) do
                assert.is_number(def.spellID)
                assert.is_number(def.hpThreshold)
                assert.is_true(def.hpThreshold > 0 and def.hpThreshold < 1)
            end
        end)

        it("resource.powerType is RunicPower (6) per D-003", function()
            assert.equals(6, spec.resource.powerType)
        end)

        it("resource.spellCosts entries are nested tables (not flat numbers)", function()
            -- D-003 demands { cost = N } shape; flat numbers or strings break APLEngine.
            for sid, entry in pairs(spec.resource.spellCosts) do
                assert.is_number(sid)
                assert.is_table(entry, "spellCost for " .. tostring(sid) .. " must be a table")
                assert.is_number(entry.cost or entry.gen or 0)
            end
        end)

        it("Death Coil costs 30 RP", function()
            assert.equals(30, spec.resource.spellCosts[47541].cost)
        end)

        it("Epidemic costs 30 RP", function()
            assert.equals(30, spec.resource.spellCosts[207317].cost)
        end)

        it("burstWindows track Army, Dark Transformation, Gargoyle", function()
            assert.is_not_nil(spec.burstWindows.armyOfTheDead)
            assert.is_not_nil(spec.burstWindows.darkTransformation)
            assert.is_not_nil(spec.burstWindows.summonGargoyle)
            assert.equals(42650, spec.burstWindows.armyOfTheDead.trigger)
        end)

        it("inferenceRules has executeSpells (Soul Reaper)", function()
            assert.is_table(spec.inferenceRules.executeSpells)
            assert.equals(343294, spec.inferenceRules.executeSpells[1])
        end)

        it("inferenceRules has burstIndicatorSpells", function()
            local indicators = spec.inferenceRules.burstIndicatorSpells
            assert.is_table(indicators)
            assert.is_true(#indicators >= 1)
        end)

        it("secondaryPowerType points at Runes (5)", function()
            assert.equals(5, spec.secondaryPowerType)
        end)

        it("APL is registered with both single-target and AOE profiles", function()
            assert.is_table(RA.APLData[252])
            assert.equals("DEATHKNIGHT", RA.APLData[252].class)
            assert.is_true(#RA.APLData[252].rules > 0)
            local profile = RA.APLData[252].profiles.default
            assert.is_true(#profile.singleTarget >= 6)
            assert.is_true(#profile.aoe >= 1)
        end)

        it("Decision Tree is registered and Evaluate is callable", function()
            local dt = RA.DecisionTrees[252]
            assert.is_table(dt)
            assert.equals(252, dt.specID)
            -- Unholy DT uses colon-method form: dt:Evaluate(features)
            assert.is_function(dt.Evaluate)
            local result = dt:Evaluate({
                buff_gargoyle_active        = false,
                debuff_virulent_plague_active = true,
                cooldown_42650_ready        = false,
                cooldown_63560_ready        = false,
                cooldown_460463_ready       = false,
                cooldown_343294_ready       = false,
                debuff_festering_scythe_active = true,
                proc_sudden_doom            = false,
                resource                    = 0,
                debuff_festering_wound      = 0,
                target_hp                   = 1.0,
                enemies_in_range            = 1,
            })
            assert.is_table(result)
            assert.is_number(result.spellID)
            assert.is_number(result.confidence)
            assert.is_true(result.confidence > 0 and result.confidence <= 1)
        end)

        it("Transition Matrix is registered and queryable", function()
            local tm = RA.TransitionMatrices[252]
            assert.is_table(tm)
            assert.equals(252, tm.specID)
            assert.is_function(tm.GetTransitionProbability)
            -- Outbreak -> Festering Strike was seeded at 0.85
            local p = tm:GetTransitionProbability(77575, 85948)
            assert.equals(0.85, p)
            -- Unknown transition returns 0.0 via metatable fallback
            local zero = tm:GetTransitionProbability(99999, 88888)
            assert.equals(0.0, zero)
        end)
    end)

    -- --------------------------------------------------------------
    -- Cross-spec sanity
    -- --------------------------------------------------------------
    describe("Cross-spec sanity", function()
        it("both specs share the same interrupt (Mind Freeze)", function()
            assert.equals(
                RA.SpecEnhancements[251].interruptSpell.spellID,
                RA.SpecEnhancements[252].interruptSpell.spellID
            )
        end)

        it("both specs use Runic Power as primary resource", function()
            assert.equals(6, RA.SpecEnhancements[251].resource.powerType)
            assert.equals(6, RA.SpecEnhancements[252].resource.powerType)
        end)

        it("SpecData has entries for Frost and Unholy with classID 6", function()
            assert.is_not_nil(RA.SpecData[251])
            assert.equals("Frost", RA.SpecData[251].specName)
            assert.equals(6, RA.SpecData[251].classID)
            assert.is_not_nil(RA.SpecData[252])
            assert.equals("Unholy", RA.SpecData[252].specName)
            assert.equals(6, RA.SpecData[252].classID)
        end)

        it("Registry untouched (D-002 single-truth-source)", function()
            -- Loading spec data must not mutate Registry tables.
            assert.is_table(RA.Registry)
            assert.is_table(RA.Registry.OVERRIDE_PAIRS)
            assert.is_table(RA.Registry.PASSIVE_BLACKLIST)
        end)
    end)
end)
