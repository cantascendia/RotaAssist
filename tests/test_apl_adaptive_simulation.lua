-- test: additive forward-simulation invariants for the APL predictor.
local helpers = require("tests.helpers")

describe("APL bounded forward simulation", function()
    local RA, APL

    before_each(function()
        local ns
        RA, ns = helpers.loadAddon()
        helpers.loadRegistry(ns)
        helpers.loadAddonFile("addon/Engine/APLEngine.lua", "RotaAssist", ns)
        APL = RA:GetModule("APLEngine")
        RA.WhitelistSpells = {}
        RA.SpecEnhancements = {}
    end)

    it("does not mutate caller defaults, cooldowns, charges, or windows", function()
        APL:SetAPL(9901, { rules = {
            { spellID = 99011, priority = 1, condition = "always" },
        } }, 12)
        local state = {
            cooldowns = { [99011] = 0 },
            charges = { [99011] = 1 },
            windows = { essence_break = true },
        }
        local result = APL:PredictNext(258860, state, 2)
        assert.is_true(#result >= 1)
        assert.is_nil(state.resource)
        assert.is_nil(state.inMeta)
        assert.is_nil(state.targetCount)
        assert.is_nil(state.combatDuration)
        assert.equals(0, state.cooldowns[99011])
        assert.equals(1, state.charges[99011])
        assert.is_true(state.windows.essence_break)
    end)

    it("advances the current head before evaluating first predicted cooldown", function()
        APL:SetAPL(9902, { rules = {
            { spellID = 99021, priority = 1, condition = "cd_ready" },
            { spellID = 99022, priority = 2, condition = "always" },
        } }, 12)

        -- Property-style grid around the assumed 1.5 s action horizon.
        for tenths = 0, 30 do
            local cooldown = tenths / 10
            local prediction = APL:PredictNext(99020, {
                resource = 50,
                cooldowns = { [99021] = cooldown },
                combatDuration = 7,
            }, 1)
            local expected = cooldown <= 1.5 and 99021 or 99022
            assert.equals(expected, prediction[1].spellID)
        end
    end)

    it("uses a supplied public GCD horizon across cooldown boundaries", function()
        APL:SetAPL(9912, { rules = {
            { spellID = 99121, priority = 1, condition = "cd_ready" },
            { spellID = 99122, priority = 2, condition = "always" },
        } }, 12)
        for _, gcd in ipairs({ 0.75, 1, 1.5 }) do
            for tenths = 0, 20 do
                local cooldown = tenths / 10
                local result = APL:PredictNext(99120, {
                    cooldowns = { [99121] = cooldown },
                    gcdDuration = gcd, combatDuration = 8,
                }, 1)
                assert.equals(cooldown <= gcd and 99121 or 99122, result[1].spellID)
            end
        end
    end)

    it("uses a longer public base cast time for the predicted horizon", function()
        APL:SetAPL(9913, { rules = {
            { spellID = 99131, priority = 1, condition = "cd_ready" },
            { spellID = 99132, priority = 2, condition = "always" },
        } }, 12)
        local getSpellInfo = C_Spell.GetSpellInfo
        C_Spell.GetSpellInfo = function(spellID)
            local info = getSpellInfo(spellID)
            if spellID == 99130 then info.castTime = 2000 end
            return info
        end
        local result = APL:PredictNext(99130, {
            cooldowns = { [99131] = 1.8 },
            gcdDuration = 1, combatDuration = 8,
        }, 1)
        C_Spell.GetSpellInfo = getSpellInfo
        assert.equals(99131, result[1].spellID)
    end)

    it("cannot cast a consumed single charge again before a known recharge", function()
        RA.WhitelistSpells[99031] = { cdSeconds = 4.5 }
        APL:SetAPL(9903, { rules = {
            { spellID = 99031, priority = 1, condition = "always" },
            { spellID = 99032, priority = 2, condition = "always" },
        } }, 12)
        local prediction = APL:PredictNext(nil, {
            resource = 50,
            cooldowns = { [99031] = 0 },
            charges = { [99031] = 1 },
            combatDuration = 8,
        }, 3)
        assert.equals(99031, prediction[1].spellID)
        assert.equals(99032, prediction[2].spellID)
        for i = 2, #prediction do
            assert.is_false(prediction[i].spellID == 99031)
        end
    end)

    it("allows two known charges but not a third while recharge is unavailable", function()
        RA.WhitelistSpells[99041] = { cdSeconds = 4.5 }
        APL:SetAPL(9904, { rules = {
            { spellID = 99041, priority = 1, condition = "cd_ready" },
            { spellID = 99042, priority = 2, condition = "always" },
        } }, 12)
        local prediction = APL:PredictNext(nil, {
            resource = 50,
            cooldowns = { [99041] = 0 },
            charges = { [99041] = 2 },
            combatDuration = 8,
        }, 3)
        assert.equals(99041, prediction[1].spellID)
        assert.equals(99041, prediction[2].spellID)
        assert.equals(99042, prediction[3].spellID)
    end)

    it("does not emit an opener action still on cooldown or jump to its successor", function()
        APL:SetAPL(9905, { profiles = { default = {
            opener = {
                { spellID = 99051, step = 1, cdSeconds = 30 },
                { spellID = 99052, step = 2, cdSeconds = 30 },
            },
            singleTarget = {
                { spellID = 99053, priority = 1, condition = "always" },
            },
        } } }, 12)
        local prediction = APL:PredictNext(nil, {
            resource = 50,
            cooldowns = { [99051] = 20 },
            combatDuration = 0,
        }, 2)
        assert.equals(99053, prediction[1].spellID)
        for i = 1, #prediction do
            assert.is_false(prediction[i].spellID == 99051)
            assert.is_false(prediction[i].spellID == 99052)
        end
    end)

    it("does not emit an opener spender when known resource is insufficient", function()
        RA.SpecEnhancements[9906] = { resource = { spellCosts = {
            [99061] = { cost = 40 },
        } } }
        APL:SetAPL(9906, { profiles = { default = {
            opener = {
                { spellID = 99061, step = 1 },
                { spellID = 99062, step = 2 },
            },
            singleTarget = {
                { spellID = 99063, priority = 1, condition = "always" },
            },
        } } }, 12)
        local prediction = APL:PredictNext(nil, {
            resource = 20,
            cooldowns = {},
            combatDuration = 0,
        }, 2)
        assert.equals(99063, prediction[1].spellID)
    end)

    it("keeps secret resource unknown and rejects declared spenders", function()
        RA.SpecEnhancements[9907] = { resource = { spellCosts = {
            [99071] = { cost = 30 },
            [99072] = { gen = 20 },
        } } }
        APL:SetAPL(9907, { rules = {
            { spellID = 99071, priority = 1, condition = "cd_ready" },
            { spellID = 99072, priority = 2, condition = "always" },
            { spellID = 99073, priority = 3, condition = "estimated_resource<=20" },
        } }, 12)
        local state = { resource = 0, resourceKnown = false, combatDuration = 8 }
        local result = APL:PredictNext(nil, state, 2)
        assert.equals(99072, result[1].spellID)
        assert.equals(99072, result[2].spellID)
        assert.equals(0, state.resource)
    end)

    it("does not trust a numeric resource when provenance says unknown", function()
        RA.SpecEnhancements[9915] = { resource = { spellCosts = {
            [99151] = { cost = 30 },
        } } }
        APL:SetAPL(9915, { rules = {
            { spellID = 99151, priority = 1, condition = "always" },
            { spellID = 99152, priority = 2, condition = "always" },
        } }, 12)
        local result = APL:PredictNext(nil, {
            resource = 50, resourceKnown = false, combatDuration = 8,
        }, 1)
        assert.equals(99152, result[1].spellID)
    end)

    it("does not treat an explicitly unknown cooldown as ready", function()
        APL:SetAPL(9908, { rules = {
            { spellID = 99081, priority = 1, condition = "always" },
            { spellID = 99082, priority = 2, condition = "always" },
        } }, 12)
        local state = {
            cooldowns = {}, cooldownUnknown = { [99081] = true },
            combatDuration = 8,
        }
        local result = APL:PredictNext(nil, state, 1)
        assert.equals(99082, result[1].spellID)
        assert.is_true(state.cooldownUnknown[99081])
    end)

    it("allows a known charge to override unknown cooldown provenance", function()
        APL:SetAPL(9909, { rules = {
            { spellID = 99091, priority = 1, condition = "cd_ready" },
            { spellID = 99092, priority = 2, condition = "always" },
        } }, 12)
        local result = APL:PredictNext(nil, {
            cooldownUnknown = { [99091] = true },
            charges = { [99091] = 1 }, combatDuration = 8,
        }, 2)
        assert.equals(99091, result[1].spellID)
        assert.equals(99092, result[2].spellID)
    end)

    it("restores known charges only after their public recharge horizon", function()
        APL:SetAPL(9910, { rules = {
            { spellID = 99101, priority = 1, condition = "cd_ready" },
            { spellID = 99102, priority = 2, condition = "always" },
        } }, 12)
        local state = {
            charges = { [99101] = 0 },
            chargeRecharges = { [99101] = { current = 0, max = 1, remaining = 2, duration = 4 } },
            combatDuration = 8,
        }
        local result = APL:PredictNext(99100, state, 1)
        assert.equals(99102, result[1].spellID)
        local later = APL:PredictNext(99100, {
            charges = { [99101] = 0 },
            chargeRecharges = { [99101] = { current = 0, max = 1, remaining = 1, duration = 4 } },
            combatDuration = 8,
        }, 1)
        assert.equals(99101, later[1].spellID)
        assert.equals(0, state.charges[99101])
        assert.equals(2, state.chargeRecharges[99101].remaining)
    end)

    it("inherits cost metadata for an override spell", function()
        RA.SpecEnhancements[9911] = { resource = { spellCosts = {
            [162794] = { cost = 40 },
        } } }
        APL:SetAPL(9911, { rules = {
            { spellID = 201427, priority = 1, condition = "always" },
            { spellID = 99111, priority = 2, condition = "always" },
        } }, 12)
        local unknown = APL:PredictNext(nil, { resourceKnown = false, combatDuration = 8 }, 1)
        assert.equals(99111, unknown[1].spellID)
        local insufficient = APL:PredictNext(nil, { resource = 20, combatDuration = 8 }, 1)
        assert.equals(99111, insufficient[1].spellID)
        local enough = APL:PredictNext(nil, { resource = 50, combatDuration = 8 }, 1)
        assert.equals(201427, enough[1].spellID)
    end)

    it("honors an observable false meta state over stale cached state", function()
        APL:SetAPL(9914, { rules = {
            { spellID = 99141, priority = 1, condition = "in_meta" },
            { spellID = 99142, priority = 2, condition = "not_in_meta" },
        } }, 12)
        APL:SetMetaState(true)
        local result = APL:PredictNext(nil, {
            inMeta = false, combatDuration = 8,
        }, 1)
        assert.equals(99142, result[1].spellID)
    end)
end)
