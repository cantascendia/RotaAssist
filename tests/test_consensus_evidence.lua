-- test: interval witnesses explain policy disagreement without claiming DPS.
local h=require("tests.helpers")
describe("consensus evidence",function()
    local RA,C,D,ns
    local p={schema="rotaassist.independent-policy.v1",rules={
        {spellID=1,conditions={{"fury",">=",40}}},{spellID=2,conditions={}}}}
    local function s() return {known={[1]=true,[2]=true},ready={[1]=true,[2]=true},facts={}} end
    before_each(function()
        RA,ns=h.loadAddon()
        for _,name in ipairs({"IndependentDecision","IndependentConsensus"}) do
            assert(h.loadAddonFile("addon/Engine/"..name..".lua","RotaAssist",ns))
        end
        C=RA:GetModule("IndependentConsensus"); D=RA:GetModule("IndependentDecision")
    end)
    it("returns two different feasible outcomes with their interval boxes",function()
        local r=C:Evaluate(p,s())
        assert.equals("ambiguous",r.status); assert.equals(2,#r.counterexamples)
        assert.is_false(r.maximumDPSProven); assert.equals("supplied_policy_only",r.proofScope)
        local found={}
        for _,w in ipairs(r.counterexamples) do
            found[w.action]=true
            for i=1,w.count do
                local b=w.bounds[i]
                if b.key=="fury" then
                    if w.action==1 then assert.equals(40,b.min); assert.is_false(b.minOpen)
                    else assert.equals(40,b.max); assert.is_true(b.maxOpen) end
                end
            end
        end
        assert.is_true(found[1]); assert.is_true(found[2])
    end)
    it("includes waiting as a distinct witness",function()
        local only={schema=p.schema,rules={p.rules[1]}}
        local r=C:Evaluate(only,s()); assert.equals(2,#r.counterexamples)
        local found=false; for _,w in ipairs(r.counterexamples) do if w.action==0 then found=true end end
        assert.is_true(found)
    end)
    it("does not call stable policy choice damage optimality",function()
        local snapshot=s(); snapshot.facts.fury=70
        local r=C:Evaluate(p,snapshot)
        assert.is_true(r.policyInvariant); assert.is_false(r.maximumDPSProven)
        assert.equals(0,#r.counterexamples)
    end)
    it("clears certificates on invalid input, missing evaluator and disable",function()
        C:Evaluate(p,s()); local r=C:Evaluate(p,s(),1)
        assert.is_false(r.policyInvariant); assert.equals(0,#r.counterexamples)
        r=C:Evaluate({},s()); assert.equals(0,#r.counterexamples); assert.is_false(r.policyInvariant)
        C:Evaluate(p,s()); RA.modules.IndependentDecision=nil
        r=C:Evaluate(p,s()); assert.equals(0,#r.counterexamples); assert.is_false(r.policyInvariant)
        C:OnDisable(); assert.is_false(r.policyInvariant)
    end)
    it("passes scoped witnesses through the real observer diagnostics",function()
        RA.IndependentPolicy={schema=p.schema,rules=p.rules,specID=577,heroProfile="fel_scarred"}
        RA:RegisterModule("SpecDetector",{GetCurrentSpec=function() return {specID=577} end})
        RA:RegisterModule("APLEngine",{GetProfileName=function() return "fel_scarred" end})
        RA.GetSpellCooldownSafe=function() return 0 end
        IsPlayerSpell=function() return true end; C_Spell.IsSpellUsable=function() return true end
        assert(h.loadAddonFile("addon/Engine/IndependentObserver.lua","RotaAssist",ns))
        local observer=RA:GetModule("IndependentObserver")
        local r=observer:Observe({targetValid=true,spellRange={[1]=true,[2]=true}})
        assert.equals(2,#r.counterexamples); assert.is_false(r.policyInvariant)
        assert.is_false(r.maximumDPSProven); assert.equals("supplied_policy_only",r.proofScope)
        observer:Reset(); assert.is_nil(observer:GetStatus().counterexamples)
    end)
end)
