-- test: additive independent policy determinacy contract (Test-Lock scenario 3).
local helpers = require("tests.helpers")
describe("independent decision", function()
    local D
    before_each(function()
        local RA, ns = helpers.loadAddon()
        assert(helpers.loadAddonFile("addon/Engine/IndependentDecision.lua", "RotaAssist", ns))
        D = RA:GetModule("IndependentDecision")
    end)
    local function policy(rules)
        return { schema = "rotaassist.independent-policy.v1", rules = rules }
    end
    local function rule(id, conditions, form)
        return { spellID = id, conditions = conditions or {}, form = form }
    end
    local function snapshot(facts)
        return { facts = facts or {}, known = { [1] = true, [2] = true }, ready = { [1] = true, [2] = true } }
    end
    it("decides from facts without an official recommendation", function()
        local s = snapshot({ fury = 65 })
        s.blizzardSpellID = 2
        local r = D:Evaluate(policy({ rule(1, {{"fury", ">=", 40}}), rule(2) }), s)
        assert.equals("decided", r.status)
        assert.equals(1, r.spellID)
    end)
    it("unknown earlier condition blocks a different later action", function()
        local r = D:Evaluate(policy({ rule(1, {{"fury", ">=", 40}}), rule(2) }), snapshot())
        assert.equals("ambiguous", r.status)
        assert.is_nil(r.spellID)
        assert.equals("fury", r.missing[1])
    end)
    it("an unconditional repeat can establish the same action", function()
        local r = D:Evaluate(policy({ rule(1, {{"fury", ">=", 40}}), rule(1) }), snapshot())
        assert.equals("decided", r.status)
        assert.equals(1, r.spellID)
    end)
    it("false AND unknown cannot block a later action or pollute diagnostics", function()
        local r = D:Evaluate(policy({ rule(1, {{"fury", ">=", 40}, {"window", ">", 0}}), rule(2) }), snapshot({window=0}))
        assert.equals(2, r.spellID)
        assert.equals(0, #r.missing)
    end)
    it("unlearned or unready actions are skipped but unknown readiness is not", function()
        local p = policy({rule(1), rule(2)})
        for _, key in ipairs({"known", "ready"}) do
            local s = snapshot()
            s[key][1] = false
            assert.equals(2, D:Evaluate(p, s).spellID)
            s[key][1] = nil
            assert.equals("ambiguous", D:Evaluate(p, s).status)
        end
    end)
    it("unreadable and nonfinite facts never prove a condition", function()
        local secret = setmetatable({}, {__lt=function() error("secret compare") end})
        issecretvalue = function(v) return rawequal(v, secret) end
        local p = policy({rule(1, {{"fury", ">=", 40}}), rule(2)})
        for _, value in ipairs({secret, 0/0, math.huge, -math.huge, "70"}) do
            assert.equals("ambiguous", D:Evaluate(p, snapshot({fury=value})).status)
        end
    end)
    it("form and charge predicates require public facts", function()
        local p = policy({rule(1, {{"charges", ">=", 2}}, "meta"), rule(2)})
        local s = snapshot({["buff.metamorphosis.up"]=true})
        assert.equals("ambiguous", D:Evaluate(p, s).status)
        s.charges = {[1]=2}
        assert.equals(1, D:Evaluate(p, s).spellID)
        s.facts["buff.metamorphosis.up"] = false
        assert.equals(2, D:Evaluate(p, s).spellID)
    end)
    it("distinguishes definite wait from unresolved possible action", function()
        local p = policy({rule(1, {{"fury", ">=", 40}})})
        assert.equals("wait", D:Evaluate(p, snapshot({fury=0})).status)
        assert.equals("ambiguous", D:Evaluate(p, snapshot()).status)
    end)
    it("rejects malformed and subsequently edited policies", function()
        local p = policy({rule(1)})
        assert.equals("decided", D:Evaluate(p, snapshot()).status)
        p.rules[1].spellID = true
        assert.equals("invalid_rule", D:Evaluate(p, snapshot()).status)
        assert.equals("invalid_policy", D:Evaluate(nil, snapshot()).status)
        p.rules[1] = rule(1, {{"fury", ">", true}})
        assert.equals("invalid_condition", D:Evaluate(p, snapshot()).status)
        assert.equals("invalid_snapshot", D:Evaluate(policy({rule(1)}), {facts=4}).status)
    end)
    it("every decided partial observation agrees with every hidden completion", function()
        -- Exhaust all combinations of three boolean observations, including nil.
        -- 穷举缺失事实的所有补全：已确定建议必须在每种补全中保持相同。
        local p = policy({rule(1, {{"a", ">", 0}, {"b", ">", 0}}), rule(2, {{"c", ">", 0}}), rule(1)})
        local values = {false, true, "unknown"}
        for _, a in ipairs(values) do for _, b in ipairs(values) do for _, c in ipairs(values) do
            local facts = {}
            for key, value in pairs({a=a,b=b,c=c}) do if value ~= "unknown" then facts[key]=value end end
            local r = D:Evaluate(p, snapshot(facts))
            local selected = r.status == "decided" and r.spellID or nil
            if selected then
                for mask=0,7 do
                    local full = {}
                    for i,key in ipairs({"a","b","c"}) do
                        full[key] = facts[key]
                        if full[key] == nil then full[key] = math.floor(mask/2^(i-1))%2 == 1 end
                    end
                    local expected = (full.a and full.b) and 1 or (full.c and 2 or 1)
                    assert.equals(expected, selected)
                end
            end
        end end end
    end)
end)
