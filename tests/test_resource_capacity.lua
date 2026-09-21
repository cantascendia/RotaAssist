-- test: additive public resource-cap coverage (Test-Lock scenario ③).
local helpers = require("tests.helpers")

describe("public primary-resource capacity", function()
    local originalPower, originalPowerMax, originalSecret, originalSecrets

    setup(function()
        helpers.ensureMockLoaded()
        originalPower = UnitPower
        originalPowerMax = UnitPowerMax
        originalSecret = issecretvalue
        originalSecrets = C_Secrets
    end)

    teardown(function()
        _G.UnitPower = originalPower
        _G.UnitPowerMax = originalPowerMax
        _G.issecretvalue = originalSecret
        _G.C_Secrets = originalSecrets
    end)

    local function captureQueueState()
        local RA, ns = helpers.loadAddon()
        helpers.loadRegistry(ns)
        RA.db = { profile = { display = { showOutOfCombat = true } } }
        RA.WhitelistSpells = {}
        RA.SpecEnhancements = {}
        local seen
        RA:RegisterModule("APLEngine", {
            HasAPL = function() return true end,
            PredictNext = function(_, _, state) seen = state; return {} end,
            IsMetaActive = function() return false end,
            GetCurrentAPL = function() return { rules = {} } end,
        })
        helpers.loadAddonFile("addon/Engine/SmartQueueManager.lua", "RotaAssist", ns)
        local SQM = RA:GetModule("SmartQueueManager")
        SQM:OnInitialize()
        SQM:OnEnable()
        SQM._AssembleQueue()
        return seen
    end

    it("passes observed public maximum of 170 with public power", function()
        _G.UnitPower = function() return 150 end
        _G.UnitPowerMax = function() return 170 end
        _G.C_Secrets = {
            ShouldUnitPowerBeSecret = function() return false end,
            ShouldUnitPowerMaxBeSecret = function() return false end,
        }
        local state = captureQueueState()
        assert.equals(150, state.resource)
        assert.equals(170, state.resourceMax)
    end)

    it("never queries policy-secret maximum", function()
        _G.UnitPower = function() return 50 end
        _G.UnitPowerMax = function() error("must not query secret maximum") end
        _G.C_Secrets = {
            ShouldUnitPowerBeSecret = function() return false end,
            ShouldUnitPowerMaxBeSecret = function() return true end,
        }
        assert.is_nil(captureQueueState().resourceMax)
    end)

    it("rejects secret, invalid, and stale maximum values", function()
        _G.issecretvalue = function(v) return v == "SECRET" end
        _G.UnitPower = function() return 150 end
        _G.C_Secrets = nil
        for _, value in ipairs({ "SECRET", 0, 120, 0/0, math.huge }) do
            _G.UnitPowerMax = function() return value end
            assert.is_nil(captureQueueState().resourceMax)
        end
    end)

    it("generates toward public 170 cap without modifying caller state", function()
        local RA, ns = helpers.loadAddon()
        helpers.loadRegistry(ns)
        helpers.loadAddonFile("addon/Engine/APLEngine.lua", "RotaAssist", ns)
        local APL = RA:GetModule("APLEngine")
        RA.WhitelistSpells = {}
        RA.SpecEnhancements = { [9901] = { resource = {
            maxBase = 120,
            spellCosts = { [99011] = { gen = 30 } },
        } } }
        APL:SetAPL(9901, { rules = {
            { spellID = 99012, priority = 1, condition = "estimated_resource>=165" },
            { spellID = 99013, priority = 2, condition = "always" },
        } }, 12)
        local state = { resource = 150, resourceMax = 170, combatDuration = 8 }
        local prediction = APL:PredictNext(99011, state, 1)
        assert.equals(99012, prediction[1].spellID)
        assert.equals(150, state.resource)
        assert.equals(170, state.resourceMax)

        local simState = { resource = 160, resourceMax = 170,
            cooldowns = {}, charges = {}, windows = {} }
        APL:SimulateSpellCast(simState, 99011)
        assert.equals(170, simState.resource)

        -- Property-style grid: valid public capacity never reduces a reading
        -- above the old static 120 cap, and never forecasts above 170.
        for power = 121, 169 do
            local sample = { resource = power, resourceMax = 170,
                cooldowns = {}, charges = {}, windows = {} }
            APL:SimulateSpellCast(sample, 99011)
            assert.equals(math.min(170, power + 30), sample.resource)
        end

        -- Secret and stale caps fall back to a conservative static estimate,
        -- without lowering an already public 150 Fury observation.
        for _, cap in ipairs({ "SECRET", 120, 0/0, math.huge }) do
            local sample = { resource = 150, resourceMax = cap,
                cooldowns = {}, charges = {}, windows = {} }
            APL:SimulateSpellCast(sample, 99011)
            assert.equals(150, sample.resource)
        end
    end)
end)
