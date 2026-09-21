-- test: additive wiring and unqualified-policy isolation (Test-Lock scenario 3).
local helpers=require("tests.helpers")
describe("independent queue observation",function()
    it("observes current state, preserves reference head, and clears stale diagnostics",function()
        local RA,ns=helpers.loadAddon()
        helpers.loadRegistry(ns)
        RA.db={profile={display={showOutOfCombat=true}}}
        local target={supported=true,targetValid=true,nearbyEnemies=3,countComplete=false,
            spellRange={[162794]=true},windows={},windowUnknown={essence_break=true},windowRemains={}}
        RA:RegisterModule("TargetContext",{IsActive=function() return true end, GetSnapshot=function() return target end})
        RA:RegisterModule("AssistedCombatBridge",{GetCurrentRecommendation=function() return {spellID=162794} end,
            GetRotationSpells=function() return {162794,232893} end})
        RA:RegisterModule("APLEngine",{HasAPL=function() return true end,IsMetaActive=function() return false end,
            GetCurrentAPL=function() return nil end,
            PredictNext=function() return {} end})
        local observed,diagnostic
        RA:RegisterModule("IndependentObserver",{
            Reset=function() diagnostic=nil end,
            Observe=function(_,s) observed=s; diagnostic={status="decided",spellID=232893,mode="observation_only"} end,
            GetStatus=function() return diagnostic end,
        })
        assert(helpers.loadAddonFile("addon/Engine/SmartQueueManager.lua","RotaAssist",ns))
        local sqm=RA:GetModule("SmartQueueManager")
        sqm:OnInitialize(); sqm:OnEnable(); sqm._AssembleQueue()
        assert.is_not_nil(observed)
        assert.equals(3,observed.targetCount)
        assert.equals(232893,sqm:GetIndependentStatus().spellID)
        assert.equals(162794,sqm:GetFinalQueue().main.spellID)
        target.targetValid=false
        sqm._AssembleQueue()
        assert.is_nil(sqm:GetIndependentStatus())
        assert.is_nil(sqm:GetFinalQueue().main)
        sqm:OnDisable()
    end)
end)
