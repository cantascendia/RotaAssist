-- test: real player aura facts reach the independent policy evaluator.
local helpers=require("tests.helpers")
describe("public aura observer integration",function()
    it("uses observed presence, proven absence and restricted unknown distinctly",function()
        local RA,ns=helpers.loadAddon(); helpers.loadRegistry(ns)
        RA:RegisterModule("SpecDetector",{GetCurrentSpec=function() return {specID=577} end})
        RA:RegisterModule("APLEngine",{GetProfileName=function() return "fel_scarred" end})
        RA.IndependentPolicy={schema="rotaassist.independent-policy.v1",specID=577,heroProfile="fel_scarred",
            rules={{spellID=1,conditions={{"buff.initiative.up",">",0}}},{spellID=2,conditions={}}}}
        for _,file in ipairs({"IndependentDecision","PublicAuraFacts","IndependentObserver"}) do
            assert(helpers.loadAddonFile("addon/Engine/"..file..".lua","RotaAssist",ns))
        end
        local observed=true
        C_UnitAuras={GetPlayerAuraBySpellID=function(id)
            if observed and id==391215 then return {spellId=id,expirationTime=GetTime()+10} end
        end}
        C_Secrets={ShouldAurasBeSecret=function() return false end,ShouldSpellAuraBeSecret=function() return false end}
        UnitExists=function() return true end; UnitIsVisible=function() return true end
        IsPlayerSpell=function() return true end
        C_Spell.IsSpellUsable=function() return true,false end
        RA.GetSpellCooldownSafe=function() return 0 end
        local state={targetValid=true,spellRange={[1]=true,[2]=true}}
        local observer=RA:GetModule("IndependentObserver")
        assert.equals(1,observer:Observe(state).spellID)
        observed=false
        assert.equals(2,observer:Observe(state).spellID)
        C_Secrets.ShouldAurasBeSecret=function() return true end
        assert.equals("ambiguous",observer:Observe(state).status)
    end)
end)
