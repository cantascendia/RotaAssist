-- test: production observer uses consensus without changing opt-in boundaries.
local h=require("tests.helpers")
describe("consensus observer integration",function()
    it("promotes a proven consensus only through the experimental opt-in",function()
        local RA,ns=h.loadAddon()
        RA.IndependentPolicy={schema="rotaassist.independent-policy.v1",specID=577,heroProfile="fel_scarred",rules={
            {spellID=1,conditions={{"fury","<",40}}},
            {spellID=1,conditions={{"fury",">=",40}}},
            {spellID=2,conditions={}},
        }}
        RA:RegisterModule("SpecDetector",{GetCurrentSpec=function() return {specID=577} end})
        RA:RegisterModule("APLEngine",{GetProfileName=function() return "fel_scarred" end})
        RA.GetSpellCooldownSafe=function() return 0 end
        IsPlayerSpell=function() return true end
        C_Spell.IsSpellUsable=function() return true end
        UnitChannelInfo=function() return nil end
        for _,name in ipairs({"IndependentDecision","IndependentConsensus","IndependentObserver"}) do
            assert(h.loadAddonFile("addon/Engine/"..name..".lua","RotaAssist",ns))
        end
        local O=RA:GetModule("IndependentObserver")
        local status=O:Observe({targetValid=true,spellRange={[1]=true,[2]=true}})
        assert.equals("decided",status.status); assert.equals(1,status.spellID)
        assert.is_true(status.consensusExhaustive); assert.is_true(status.consensusNodes>0)
        RA.db={profile={smartQueue={independentExperimental=false}}}
        assert.is_nil(O:GetExperimentalHead(2))
        RA.db.profile.smartQueue.independentExperimental=true
        assert.equals(1,O:GetExperimentalHead(2)); assert.equals(2,status.referenceSpellID)
    end)
end)
