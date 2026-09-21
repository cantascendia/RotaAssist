-- test: pinned Midnight Havoc source corrections affect the loaded simulation.
local helpers = require("tests.helpers")

describe("Havoc source-backed model", function()
    local RA, APL, havoc

    setup(function()
        local ns
        RA, ns = helpers.loadAddon()
        helpers.loadRegistry(ns)
        helpers.loadAddonFile("addon/Data/WhitelistSpells.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/Data/SpecEnhancements/DemonHunter.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/Data/APL/DemonHunter_Havoc.lua", "RotaAssist", ns)
        helpers.loadAddonFile("addon/Engine/APLEngine.lua", "RotaAssist", ns)
        APL = RA:GetModule("APLEngine")
        havoc = RA.APLData[577]
    end)

    it("simulates observed generators at 25 and 15 Fury", function()
        APL:SetAPL(577, havoc, 12)
        local state = { resource = 30, cooldowns = {}, windows = {} }
        APL:SimulateSpellCast(state, 162243)
        assert.equals(55, state.resource)
        APL:SimulateSpellCast(state, 232893)
        assert.equals(70, state.resource)
    end)

    it("uses the corrected fallback cooldowns when simulating casts", function()
        APL:SetAPL(577, havoc, 12)
        local state = { resource = 90, cooldowns = {}, windows = {} }
        APL:SimulateSpellCast(state, 198013)
        assert.equals(30, state.cooldowns[198013])
        APL:SimulateSpellCast(state, 191427)
        assert.equals(120, state.cooldowns[191427])
        APL:SimulateSpellCast(state, 232893)
        assert.equals(12, state.cooldowns[232893])
    end)

    it("never recommends Glaive Tempest as a cast even if an APL rule names it", function()
        assert.is_false(RA:IsSpellRecommendable(342817))
        assert.is_nil(RA.WhitelistSpells[342817])
        for _, profile in pairs(havoc.profiles) do
            for _, list in ipairs({ profile.singleTarget, profile.aoe, profile.opener }) do
                if list then
                    for _, entry in ipairs(list) do
                        assert.not_equals(342817, entry.spellID)
                    end
                end
            end
        end
        APL:SetAPL(577, { rules = {
            { spellID = 342817, condition = "always" },
            { spellID = 162243, condition = "always" },
        } }, 12)
        local result = APL:PredictNext(nil, {
            resource = 30, resourceKnown = true,
            cooldowns = { [342817] = 0, [162243] = 0 },
            targetCount = 3,
        }, 1)
        assert.equals(162243, result[1].spellID)
    end)
end)
