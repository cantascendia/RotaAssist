-- test: additive aura absence and public-field validation contract.
local helpers=require("tests.helpers")
describe("public aura facts",function()
    local A,aura,secret
    before_each(function()
        local RA,ns=helpers.loadAddon()
        assert(helpers.loadAddonFile("addon/Engine/PublicAuraFacts.lua","RotaAssist",ns))
        A=RA:GetModule("PublicAuraFacts")
        secret={}; issecretvalue=function(v) return rawequal(v,secret) end
        aura=nil
        C_UnitAuras={GetPlayerAuraBySpellID=function() return aura end}
        C_Secrets={ShouldAurasBeSecret=function() return false end,ShouldSpellAuraBeSecret=function() return false end}
        UnitExists=function() return true end; UnitIsVisible=function() return true end
    end)
    it("recognizes absence only with public unrestricted predicates and visible player",function()
        assert.is_false(A:ReadPlayer(123,10))
        C_Secrets.ShouldSpellAuraBeSecret=function() return true end
        assert.is_nil(A:ReadPlayer(123,10))
        C_Secrets.ShouldSpellAuraBeSecret=function() return false end
        UnitIsVisible=function() return false end
        assert.is_nil(A:ReadPlayer(123,10))
    end)
    it("handles active, expired and permanent public aura records",function()
        aura={spellId=123,expirationTime=14}
        local up,remains=A:ReadPlayer(123,10)
        assert.is_true(up); assert.equals(4,remains)
        assert.is_false(A:ReadPlayer(123,15))
        aura.expirationTime=0
        assert.is_true(A:ReadPlayer(123,10))
    end)
    it("keeps nil, secret, malformed and failed reads unknown",function()
        C_Secrets.ShouldAurasBeSecret=function() return secret end
        assert.is_nil(A:ReadPlayer(123,10))
        for _,bad in ipairs({secret,{spellId=secret,expirationTime=10},
            {spellId=123,expirationTime=secret},{spellId=123,expirationTime=0/0},
            {spellId=124,expirationTime=14}}) do
            aura=bad; assert.is_nil(A:ReadPlayer(123,10))
        end
        C_UnitAuras.GetPlayerAuraBySpellID=function() error("restricted") end
        assert.is_nil(A:ReadPlayer(123,10))
    end)
end)
