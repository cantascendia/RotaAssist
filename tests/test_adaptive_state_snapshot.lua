-- test: only observed public power, cooldowns, charges and GCD enter APL simulation.
local helpers = require("tests.helpers")

describe("adaptive queue state snapshot", function()
    local originalPower, originalCooldown, originalCharges, originalSecret, originalSecrets

    setup(function()
        helpers.ensureMockLoaded()
        originalPower = UnitPower
        originalCooldown = C_Spell.GetSpellCooldown
        originalCharges = C_Spell.GetSpellCharges
        originalSecret = issecretvalue
        originalSecrets = C_Secrets
    end)

    teardown(function()
        _G.UnitPower = originalPower
        C_Spell.GetSpellCooldown = originalCooldown
        C_Spell.GetSpellCharges = originalCharges
        _G.issecretvalue = originalSecret
        _G.C_Secrets = originalSecrets
    end)

    local function buildQueue(rules)
        local RA, ns = helpers.loadAddon()
        helpers.loadRegistry(ns)
        RA.db = { profile = { display = { showOutOfCombat = true } } }
        RA.WhitelistSpells = { [111] = { cdSeconds = 10 }, [222] = { cdSeconds = 10 } }
        local snapshots = {}
        RA:RegisterModule("APLEngine", {
            HasAPL = function() return true end,
            PredictNext = function(_, _, state)
                snapshots[#snapshots + 1] = state
                return {}
            end,
            IsMetaActive = function() return false end,
            GetCurrentAPL = function() return { rules = rules or {} } end,
            EvaluateCondition = function(_, _, _, state)
                snapshots.blindSpot = state
                return true
            end,
        })
        RA:RegisterModule("CooldownOverlay", {
            GetCooldownStates = function()
                return { [111] = { ready = true, remaining = 0 } }
            end,
        })
        helpers.loadAddonFile("addon/Engine/SmartQueueManager.lua", "RotaAssist", ns)
        local SQM = RA:GetModule("SmartQueueManager")
        SQM:OnInitialize()
        SQM:OnEnable()
        return SQM, snapshots
    end

    it("passes observable power, cooldown, recharge and GCD to the simulator", function()
        _G.UnitPower = function() return 42 end
        _G.C_Secrets = { ShouldUnitPowerBeSecret = function() return false end }
        C_Spell.GetSpellCooldown = function(id)
            if id == 61304 then return { startTime = 999, duration = 1 } end
            return { startTime = 0, duration = 0 }
        end
        C_Spell.GetSpellCharges = function(id)
            if id == 222 then
                return { currentCharges = 1, maxCharges = 2,
                    cooldownStartTime = 998, cooldownDuration = 10, chargeModRate = 2 }
            end
            return { currentCharges = 1, maxCharges = 1,
                cooldownStartTime = 0, cooldownDuration = 0 }
        end
        local SQM, snapshots = buildQueue()
        SQM._AssembleQueue()
        local state = snapshots[1]
        assert.equals(42, state.resource)
        assert.is_true(state.resourceKnown)
        assert.equals(0, state.cooldowns[111])
        assert.is_nil(state.cooldownUnknown[111])
        assert.equals(1, state.gcdDuration)
        assert.equals(1, state.charges[222])
        assert.equals(2, state.chargeRecharges[222].max)
        assert.equals(8, state.chargeRecharges[222].remaining)
        assert.equals(10, state.chargeRecharges[222].duration)
    end)

    it("keeps secret power and cooldown unknown despite overlay ready inference", function()
        _G.issecretvalue = function(v) return v == "SECRET" end
        _G.C_Secrets = { ShouldUnitPowerBeSecret = function() return true end }
        _G.UnitPower = function() error("secret predicate should skip UnitPower") end
        C_Spell.GetSpellCooldown = function(id)
            return { startTime = "SECRET", duration = 10 }
        end
        C_Spell.GetSpellCharges = function(id)
            if id == 222 then
                return { currentCharges = "SECRET", maxCharges = 2,
                    cooldownStartTime = 998, cooldownDuration = 10 }
            end
            return nil
        end
        local SQM, snapshots = buildQueue({ { spellID = 111, condition = "always" } })
        SQM._AssembleQueue()
        local state = snapshots[1]
        assert.is_nil(state.resource)
        assert.is_false(state.resourceKnown)
        assert.is_nil(state.cooldowns[111])
        assert.is_true(state.cooldownUnknown[111])
        assert.is_nil(state.charges[222])
        assert.is_nil(state.chargeRecharges[222])
        assert.is_nil(snapshots.blindSpot.resource)
        assert.is_false(snapshots.blindSpot.resourceKnown)
        assert.is_true(snapshots.blindSpot.cooldownUnknown[111])
        assert.is_nil(SQM:GetFinalQueue().main)
    end)

    it("refreshes charge and power snapshots without stale values after API errors", function()
        _G.C_Secrets = nil
        local power = 65
        local chargeCount = 1
        local cooldownFails = false
        _G.UnitPower = function()
            if power == nil then error("unreadable power") end
            return power
        end
        C_Spell.GetSpellCooldown = function(id)
            if cooldownFails then error("unreadable cooldown") end
            return { startTime = 0, duration = 0 }
        end
        C_Spell.GetSpellCharges = function(id)
            if id ~= 222 then return nil end
            return { currentCharges = chargeCount, maxCharges = 2,
                cooldownStartTime = 998, cooldownDuration = 10, modRate = "SECRET" }
        end
        _G.issecretvalue = function(v) return v == "SECRET" end
        local SQM, snapshots = buildQueue()
        SQM._AssembleQueue()
        assert.equals(65, snapshots[1].resource)
        assert.equals(1, snapshots[1].charges[222])
        assert.is_nil(snapshots[1].chargeRecharges[222])

        power = nil
        chargeCount = 0
        cooldownFails = true
        SQM._AssembleQueue()
        local refreshed = snapshots[2]
        assert.is_nil(refreshed.resource)
        assert.is_false(refreshed.resourceKnown)
        assert.equals(0, refreshed.charges[222])
        assert.is_nil(refreshed.cooldowns[111])
        assert.is_true(refreshed.cooldownUnknown[111])
    end)
end)
