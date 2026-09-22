-- test: optimized data is selected only for the proven current hero/spec.
local h=require("tests.helpers")
describe("adaptive policy selection",function()
    local RA,ns,O,rank
    before_each(function()
        RA,ns=h.loadAddon(); h.loadRegistry(ns); rank={[452402]=1,[442290]=0}
        RA:RegisterModule("SpecDetector",{GetCurrentSpec=function() return {specID=577} end})
        RA:RegisterModule("CharacterState",{GetSnapshot=function() return {specID=577,talentsComplete=true} end,
            GetTalentRank=function(_,id) return rank[id] end})
        RA:RegisterModule("APLEngine",{GetProfileName=function() return "default" end})
        RA.IndependentPolicy={schema="rotaassist.independent-policy.v1",specID=577,heroProfile="fel_scarred",
            policySha256="prior",rules={{spellID=162794,conditions={}}}}
        RA.IndependentPolicies={}
        RA.IndependentAdaptivePolicies={fel_scarred={schema="rotaassist.independent-policy.v1",specID=577,
            heroProfile="fel_scarred",policySha256="adaptive",rules={{spellID=258920,conditions={{"active_enemies",">=",2}}},
                {spellID=162794,conditions={}}}}}
        IsPlayerSpell=function() return true end; C_Spell.IsSpellUsable=function() return true end
        RA.GetSpellCooldownSafe=function() return 0,true,0,0 end
        for _,file in ipairs({"IndependentDecision","IndependentConsensus","IndependentObserver"}) do
            assert(h.loadAddonFile("addon/Engine/"..file..".lua","RotaAssist",ns))
        end
        O=RA:GetModule("IndependentObserver")
    end)
    local function state(count,exact)
        return {targetValid=true,targetCount=count,targetCountKnown=exact,spellRange={[258920]=true,[162794]=true}}
    end
    it("selects optimized data and reacts to a proven multi-target lower bound",function()
        local r=O:Observe(state(2,false)); assert.equals("adaptive",r.policySha256); assert.equals(258920,r.spellID)
        r=O:Observe(state(1,true)); assert.equals(162794,r.spellID)
    end)
    it("does not mistake one visible enemy for an exact single-target fight",function()
        local r=O:Observe(state(1,false)); assert.equals("ambiguous",r.status); assert.is_nil(r.spellID)
    end)
    it("keeps previous data available when no adaptive hero policy is installed",function()
        RA.IndependentAdaptivePolicies=nil
        local r=O:Observe(state(5,true)); assert.equals("prior",r.policySha256); assert.equals(162794,r.spellID)
    end)
    it("rejects a wrong-hero or wrong-spec optimized policy",function()
        RA.IndependentAdaptivePolicies.fel_scarred.heroProfile="aldrachi_reaver"
        assert.equals("policy_identity_mismatch",O:Observe(state(5,true)).status)
        RA.IndependentAdaptivePolicies.fel_scarred.heroProfile="fel_scarred"
        RA.IndependentAdaptivePolicies.fel_scarred.specID=581
        assert.equals("policy_identity_mismatch",O:Observe(state(5,true)).status)
    end)
    it("cannot preserve an earlier hero choice after the build changes",function()
        O:Observe(state(5,true)); rank[452402]=0; rank[442290]=1
        local r=O:Observe(state(5,true)); assert.equals("unavailable",r.status); assert.is_nil(r.spellID)
    end)
end)
