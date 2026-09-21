-- test: character invalidation clears displayed actions and stale observer state.
local h=require("tests.helpers")
describe("character queue invalidation",function()
    it("clears current and predicted actions synchronously",function()
        local RA,ns=h.loadAddon(); h.loadRegistry(ns)
        RA.db={profile={display={showOutOfCombat=true}}}
        RA:RegisterModule("AssistedCombatBridge",{GetCurrentRecommendation=function() return {spellID=162794} end,
            GetRotationSpells=function() return {162794,232893} end})
        RA:RegisterModule("APLEngine",{HasAPL=function() return true end,IsMetaActive=function() return false end,
            GetCurrentAPL=function() return nil end,PredictNext=function() return {} end})
        local diagnostic
        RA:RegisterModule("IndependentObserver",{Reset=function() diagnostic=nil end,
            Observe=function() diagnostic={status="decided",spellID=232893} end,
            GetStatus=function() return diagnostic end})
        assert(h.loadAddonFile("addon/Core/EventHandler.lua","RotaAssist",ns))
        assert(h.loadAddonFile("addon/Engine/SmartQueueManager.lua","RotaAssist",ns))
        local Q=RA:GetModule("SmartQueueManager"); Q:OnInitialize(); Q:OnEnable(); Q._AssembleQueue()
        assert.is_not_nil(Q:GetFinalQueue().main)
        RA:GetModule("EventHandler"):Fire("ROTAASSIST_CHARACTER_CHANGED",1,false)
        assert.is_nil(Q:GetFinalQueue().main); assert.equals(0,#Q:GetFinalQueue().next)
        assert.is_nil(Q:GetIndependentStatus()); Q:OnDisable()
    end)
end)
