-- test: additive symbolic consensus contract; no existing assertions changed.
local h=require("tests.helpers")
describe("independent symbolic consensus",function()
    local C
    before_each(function()
        local RA,ns=h.loadAddon()
        assert(h.loadAddonFile("addon/Engine/IndependentDecision.lua","RotaAssist",ns))
        assert(h.loadAddonFile("addon/Engine/IndependentConsensus.lua","RotaAssist",ns))
        C=RA:GetModule("IndependentConsensus"); C:OnInitialize()
    end)
    local function r(id,conditions,form) return {spellID=id,conditions=conditions or {},form=form} end
    local function p(rules) return {schema="rotaassist.independent-policy.v1",rules=rules} end
    local function s(facts) return {facts=facts or {},known={[1]=true,[2]=true},ready={[1]=true,[2]=true}} end
    it("proves complementary conditions choose the same action",function()
        local result=C:Evaluate(p({r(1,{{"fury","<",40}}),r(1,{{"fury",">=",40}}),r(2)}),s())
        assert.equals("decided",result.status); assert.equals(1,result.spellID)
        assert.is_true(result.exhaustive)
    end)
    it("does not discard equality endpoints or a possible wait",function()
        local rules={r(1,{{"fury","<",40}}),r(1,{{"fury",">",40}}),r(2)}
        assert.equals("ambiguous",C:Evaluate(p(rules),s()).status)
        rules[3]=nil
        assert.equals("ambiguous",C:Evaluate(p(rules),s()).status)
        rules[3]=r(1,{{"fury","==",40}})
        assert.equals(1,C:Evaluate(p(rules),s()).spellID)
        assert.equals("ambiguous",C:Evaluate(p({r(1,{{"fury","==",0}}),
            r(1,{{"fury","<",0}}),r(2)}),s()).status)
    end)
    it("keeps repeated predicate correlations and excludes contradictions",function()
        local policy=p({r(2,{{"fury",">",50},{"fury","<=",50}}),r(1)})
        assert.equals(1,C:Evaluate(policy,s()).spellID)
        local snapshot=s(); snapshot.bounds={fury={min=0,max=35}}
        assert.equals(1,C:Evaluate(p({r(2,{{"fury",">",35}}),r(1)}),snapshot).spellID)
        snapshot.bounds.fury={min=40,max=50}
        assert.equals(1,C:Evaluate(p({r(1,{{"fury","==",40}}),r(2,{{"fury","<",40}}),
            r(1,{{"fury",">",40}})}),snapshot).spellID)
    end)
    it("keeps unknown readiness and learning as alternative worlds",function()
        local snapshot=s(); snapshot.ready[1]=nil
        assert.equals("ambiguous",C:Evaluate(p({r(1),r(2)}),snapshot).status)
        snapshot.ready[1]=true; snapshot.known[1]=nil
        assert.equals("ambiguous",C:Evaluate(p({r(1),r(2)}),snapshot).status)
    end)
    it("correlates form but not two different spells' charges",function()
        assert.equals(1,C:Evaluate(p({r(1,{},"meta"),r(1,{},"normal"),r(2)}),s()).spellID)
        local policy=p({r(1,{{"charges",">=",1}}),r(2,{{"charges","<",1}}),r(1)})
        assert.equals("ambiguous",C:Evaluate(policy,s()).status)
        assert.equals("ambiguous",C:Evaluate(p({r(1,{{"charges",">=",1}}),
            r(2,{{"charges",">=",1}}),r(1)}),s()).status)
    end)
    it("fails closed on budget exhaustion and catches policy edits",function()
        local policy=p({r(1,{{"fury","<",40}}),r(1,{{"fury",">=",40}}),r(2)})
        local result=C:Evaluate(policy,s(),1)
        assert.equals("budget_exceeded",result.status); assert.is_nil(result.spellID)
        policy.rules[1].conditions[1][2]="!="
        assert.equals("invalid_condition",C:Evaluate(policy,s()).status)
        assert.equals("invalid_snapshot",C:Evaluate(p({r(1)}),{facts=3}).status)
    end)
    it("does not compare protected or nonfinite facts",function()
        local secret=setmetatable({},{__lt=function() error("secret comparison") end})
        issecretvalue=function(value) return rawequal(value,secret) end
        local policy=p({r(1,{{"fury",">=",40}}),r(2)})
        assert.equals("ambiguous",C:Evaluate(policy,s({fury=secret})).status)
        assert.equals("ambiguous",C:Evaluate(policy,s({fury=math.huge})).status)
        local snapshot=s(); snapshot.bounds={fury={min=secret,max=secret}}
        assert.equals("ambiguous",C:Evaluate(policy,snapshot).status)
    end)
    it("rebuilds domains and leaves the caller snapshot intact",function()
        local policy=p({r(1,{{"fury","<",40}}),r(2)})
        local snapshot=s({fury=10})
        assert.equals(1,C:Evaluate(policy,snapshot).spellID)
        assert.equals(10,snapshot.facts.fury)
        snapshot.facts.fury=nil
        assert.equals("ambiguous",C:Evaluate(policy,snapshot).status)
        assert.is_nil(snapshot.facts.fury)
    end)
end)
