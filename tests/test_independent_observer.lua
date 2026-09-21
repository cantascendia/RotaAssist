-- test: additive observation boundary and reset coverage (Test-Lock scenario 3).
local helpers=require("tests.helpers")
describe("independent observer",function()
    local RA, O
    local function state()
        return {targetValid=true,resourceKnown=true,resource=70,targetCount=3,targetCountKnown=false,
            spellRange={[1]=true,[2]=true},charges={},windows={},windowUnknown={essence_break=true}}
    end
    before_each(function()
        local ns
        RA,ns=helpers.loadAddon()
        RA:RegisterModule("SpecDetector",{GetCurrentSpec=function() return {specID=577} end})
        RA:RegisterModule("APLEngine",{GetProfileName=function() return "fel_scarred" end})
        assert(helpers.loadAddonFile("addon/Engine/IndependentDecision.lua","RotaAssist",ns))
        assert(helpers.loadAddonFile("addon/Engine/IndependentObserver.lua","RotaAssist",ns))
        O=RA:GetModule("IndependentObserver")
        RA.IndependentPolicy={schema="rotaassist.independent-policy.v1",specID=577,heroProfile="fel_scarred",
            rules={{spellID=1,conditions={{"active_enemies",">=",3}}},{spellID=2,conditions={}}}}
        RA.GetSpellCooldownSafe=function() return 0 end
        IsPlayerSpell=function() return true end
        C_Spell.IsSpellUsable=function() return true end
    end)
    it("can decide independently with a sufficient public range lower bound",function()
        local r=O:Observe(state())
        assert.equals("decided",r.status)
        assert.equals(1,r.spellID)
        assert.equals("observation_only",r.mode)
        assert.is_false(r.performanceQualified)
    end)
    it("never treats lower-bound population as exact",function()
        RA.IndependentPolicy.rules[1].conditions[1][2]="=="
        local r=O:Observe(state())
        assert.equals("ambiguous",r.status)
        assert.is_nil(r.spellID)
    end)
    it("does not invent simulator virtual flags or copy inferred resource",function()
        RA.IndependentPolicy.rules[1].conditions={{"action.death_sweep.demonsurge_available",">",0}}
        assert.equals("ambiguous",O:Observe(state()).status)
        RA.IndependentPolicy.rules[1].conditions={{"fury",">",40}}
        local s=state(); s.resourceKnown=false
        assert.equals("ambiguous",O:Observe(s).status)
    end)
    it("secret or missing spell usability stays unknown",function()
        local secret={}
        issecretvalue=function(v) return rawequal(v,secret) end
        C_Spell.IsSpellUsable=function() return secret end
        assert.equals("ambiguous",O:Observe(state()).status)
        C_Spell.IsSpellUsable=nil
        assert.equals("ambiguous",O:Observe(state()).status)
    end)
    it("readable cooldown and range failures rule out an action",function()
        RA.GetSpellCooldownSafe=function(_,id) if id==1 then return 5 end return 0 end
        assert.equals(2,O:Observe(state()).spellID)
        RA.GetSpellCooldownSafe=function() return 0 end
        local s=state(); s.spellRange[1]=false
        assert.equals(2,O:Observe(s).spellID)
    end)
    it("clears stale decisions for unknown target or unsupported profile",function()
        assert.equals(1,O:Observe(state()).spellID)
        local s=state(); s.targetValid=nil
        assert.equals("target_unknown",O:Observe(s).status)
        assert.is_nil(O:GetStatus().spellID)
        RA.IndependentPolicy.heroProfile="aldrachi"
        assert.equals("unavailable",O:Observe(state()).status)
        O:OnDisable()
        assert.is_nil(O:GetStatus().spellID)
    end)
end)
