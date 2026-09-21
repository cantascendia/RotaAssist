-- test: additive public-resource inequality contract (Test-Lock scenario 3).
local helpers=require("tests.helpers")
describe("public resource evidence",function()
    local E, costs, usable, insufficient, secret
    local rules={{spellID=1},{spellID=2}}
    local function cost(min,total)
        return {type=17,minCost=min,cost=total or min,costPercent=0,costPerSec=0,requiredAuraID=0,hasRequiredAura=false}
    end
    before_each(function()
        local RA,ns=helpers.loadAddon()
        assert(helpers.loadAddonFile("addon/Engine/ResourceEvidence.lua","RotaAssist",ns))
        E=RA:GetModule("ResourceEvidence")
        secret=setmetatable({},{__lt=function() error("secret") end,__le=function() error("secret") end})
        issecretvalue=function(v) return rawequal(v,secret) end
        IsPlayerSpell=function() return true end
        costs={[1]={cost(30)},[2]={cost(50)}}
        usable={[1]=true,[2]=false}; insufficient={[1]=false,[2]=true}
        C_Spell.GetSpellPowerCost=function(id) return costs[id] end
        C_Spell.IsSpellUsable=function(id) return usable[id],insufficient[id] end
    end)
    it("infers an interval without reading UnitPower",function()
        UnitPower=function() error("must not read hidden resource") end
        local r=E:Observe(rules,17)
        assert.equals(30,r.min); assert.equals(50,r.max)
        assert.equals(2,r.observations); assert.is_false(r.inconsistent)
    end)
    it("uses mandatory minimum instead of optional full cost",function()
        costs[1]={cost(20,60)}
        assert.equals(20,E:Observe(rules,17).min)
    end)
    it("does not infer from free, percentage, drain or multiple-resource costs",function()
        for _,items in ipairs({{cost(0)}, {cost(20),cost(5)}, {cost(20)}}) do
            costs[1]=items
            if #items==1 and items[1].minCost==20 then items[1].type=0 end
            assert.equals(0,E:Observe({rules[1]},17).observations)
        end
        for _,field in ipairs({"costPercent","costPerSec"}) do
            costs[1]={cost(20)}; costs[1][1][field]=1
            assert.equals(0,E:Observe({rules[1]},17).observations)
        end
    end)
    it("requires complete public cost metadata and applicability",function()
        for _,field in ipairs({"type","minCost","cost","costPercent","costPerSec","requiredAuraID"}) do
            costs[1]={cost(20)}; costs[1][1][field]=secret
            assert.equals(0,E:Observe({rules[1]},17).observations)
        end
        costs[1]={cost(20)}; costs[1][1].requiredAuraID=123; costs[1][1].hasRequiredAura=secret
        assert.equals(0,E:Observe({rules[1]},17).observations)
        costs[1][1].hasRequiredAura=false
        assert.equals(0,E:Observe({rules[1]},17).observations)
        costs[1][1].hasRequiredAura=true
        assert.equals(20,E:Observe({rules[1]},17).min)
    end)
    it("ignores unknown usability, unlearned spells and API errors",function()
        usable[1]=secret
        assert.equals(0,E:Observe({rules[1]},17).observations)
        usable[1]=true; insufficient[1]=secret
        assert.equals(0,E:Observe({rules[1]},17).observations)
        IsPlayerSpell=function() return false end
        assert.equals(0,E:Observe(rules,17).observations)
        IsPlayerSpell=function() return true end
        C_Spell.GetSpellPowerCost=function() error("restricted") end
        assert.equals(0,E:Observe(rules,17).observations)
    end)
    it("rejects contradictory observations, including strict-endpoint equality",function()
        costs[2]={cost(30)}
        local r=E:Observe(rules,17)
        assert.is_true(r.inconsistent); assert.equals(0,r.observations); assert.is_nil(r.max)
        insufficient[1]=true
        assert.is_true(E:Observe({rules[1]},17).inconsistent)
    end)
    it("clears all previous bounds after the next observation and disable",function()
        assert.equals(30,E:Observe(rules,17).min)
        local r=E:Observe({},17)
        assert.equals(0,r.min); assert.is_nil(r.max); assert.equals(0,r.observations)
        E:OnDisable(); assert.equals(0,r.observations)
    end)
    it("every generated true resource is contained in the inferred interval",function()
        for actual=0,120 do
            usable[1]=actual>=30; insufficient[1]=not usable[1]
            usable[2]=actual>=50; insufficient[2]=not usable[2]
            local r=E:Observe(rules,17)
            assert.is_true(actual>=r.min)
            assert.is_true(r.max==nil or actual<r.max)
            assert.is_false(r.inconsistent)
        end
    end)
end)
