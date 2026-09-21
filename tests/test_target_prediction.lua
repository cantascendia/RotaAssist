-- test: additive prediction behavior for target-specific observations.
local helpers = require("tests.helpers")
describe("target-aware prediction", function()
    local RA, APL
    before_each(function()
        local ns
        RA, ns = helpers.loadAddon()
        helpers.loadRegistry(ns)
        assert(helpers.loadAddonFile("addon/Engine/APLEngine.lua", "RotaAssist", ns))
        APL = RA:GetModule("APLEngine")
        RA.WhitelistSpells = {}
        RA.SpecEnhancements = {}
    end)
    local function useRules(rules)
        APL:SetAPL(9901, { rules = rules }, 12)
    end
    it("rejects out-of-range action and accepts a ranged alternative", function()
        useRules({ { spellID = 99011, condition = "always" }, { spellID = 99012, condition = "always" } })
        local s = { spellRange = { [99011] = false, [99012] = true }, combatDuration = 10 }
        local p = APL:PredictNext(nil, s, 1)
        assert.equals(99012, p[1].spellID)
        assert.is_false(s.spellRange[99011])
    end)
    it("does not interpret unknown target count as exactly one", function()
        useRules({ { spellID = 99011, condition = "target_count==1" }, { spellID = 99012, condition = "always" } })
        assert.equals(99012, APL:PredictNext(nil, { targetCount = 1, targetCountKnown = false }, 1)[1].spellID)
        useRules({ { spellID = 99011, condition = "target_count>=3" }, { spellID = 99012, condition = "always" } })
        assert.equals(99011, APL:PredictNext(nil, { targetCount = 3, targetCountKnown = false }, 1)[1].spellID)
    end)
    it("unknown target debuff cannot satisfy either presence or absence", function()
        useRules({ { spellID = 99011, condition = "window:essence_break" },
            { spellID = 99012, condition = "not_window:essence_break" },
            { spellID = 99013, condition = "always" } })
        assert.equals(99013, APL:PredictNext(nil, { windowUnknown = { essence_break = true } }, 1)[1].spellID)
    end)
    it("expires observed debuff before the next action rather than using two fixed steps", function()
        useRules({ { spellID = 99011, condition = "window:essence_break" },
            { spellID = 99012, condition = "always" } })
        local s = { windows = { essence_break = true }, windowRemains = { essence_break = 0.2 } }
        assert.equals(99012, APL:PredictNext(99010, s, 1)[1].spellID)
        assert.equals(0.2, s.windowRemains.essence_break)
        s.windowRemains.essence_break = 5
        assert.equals(99011, APL:PredictNext(99010, s, 1)[1].spellID)
    end)
    it("expires observed player form before recommending form-dependent action", function()
        useRules({ { spellID = 99011, condition = "in_meta" }, { spellID = 99012, condition = "always" } })
        assert.equals(99012, APL:PredictNext(99010, { inMeta = true, metaRemains = 0.1 }, 1)[1].spellID)
    end)
    it("invalid target produces no offensive predictions", function()
        useRules({ { spellID = 99011, condition = "always" } })
        assert.equals(0, #APL:PredictNext(nil, { targetValid = false }, 3))
    end)
    it("unknown form does not prove either presence or absence", function()
        useRules({ { spellID = 99011, condition = "in_meta" },
            { spellID = 99012, condition = "not_in_meta" },
            { spellID = 99013, condition = "always" } })
        for _, estimated in ipairs({ false, true }) do
            assert.equals(99013, APL:PredictNext(nil, { inMeta = estimated, inMetaKnown = false }, 1)[1].spellID)
        end
    end)
end)
