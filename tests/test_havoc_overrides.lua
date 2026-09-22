-- test: active proc replacements must survive the real recommendation filters.
local h=require("tests.helpers")
describe("havoc active replacement evidence",function()
    local RA,ns,active,secret
    before_each(function()
        RA,ns=h.loadAddon(); h.loadRegistry(ns); active=442294; secret={}
        issecretvalue=function(v) return rawequal(v,secret) end
        IsPlayerSpell=function(id) return id==185123 or id==162794 end
        C_Spell.GetOverrideSpell=function(id) if id==185123 then return active end; return id end
        C_Spell.IsSpellUsable=function() return true end
    end)
    it("accepts a public active replacement of a learned base",function()
        assert.is_true(RA:IsPlayerSpellKnownSafe(442294)); assert.is_true(RA:IsSpellRecommendable(442294))
    end)
    it("rejects the same replacement once the proc has ended",function()
        active=185123; assert.is_false(RA:IsPlayerSpellKnownSafe(442294)); assert.is_false(RA:IsSpellRecommendable(442294))
    end)
    it("does not use a stale spellbook or static pair as proc proof",function()
        RA:RegisterModule("SpellCatalog",{GetSnapshot=function() return {spells={[442294]={baseSpellID=185123}}} end})
        active=185123; assert.is_false(RA:IsPlayerSpellKnownSafe(442294))
        IsPlayerSpell=function() return false end; active=442294; assert.is_false(RA:IsPlayerSpellKnownSafe(442294))
    end)
    it("preserves unknown restricted learning and replacement identity",function()
        active=secret; assert.is_nil(RA:IsPlayerSpellKnownSafe(442294))
        local resolved,changed=RA:ResolveSpellOverride(185123); assert.equals(185123,resolved); assert.is_false(changed)
        IsPlayerSpell=function() return secret end; assert.is_nil(RA:IsPlayerSpellKnownSafe(442294))
        assert.is_false(RA:IsSpellRecommendable(442294)); assert.is_false(RA:IsSpellRecommendable(secret))
    end)
    it("uses the same evidence for learned transformed spenders",function()
        C_Spell.GetOverrideSpell=function(id) return id==162794 and 201427 or id end
        assert.is_true(RA:IsPlayerSpellKnownSafe(201427)); assert.is_true(RA:IsSpellRecommendable(201427))
        C_Spell.GetOverrideSpell=function(id) return id end
        assert.is_false(RA:IsPlayerSpellKnownSafe(201427))
    end)
    it("treats API failure as unknown rather than a usable proc",function()
        C_Spell.GetOverrideSpell=function() error("unavailable") end
        assert.is_nil(RA:IsPlayerSpellKnownSafe(442294)); assert.is_false(RA:IsSpellRecommendable(442294))
        C_Spell.GetOverrideSpell=nil; assert.is_nil(RA:IsPlayerSpellKnownSafe(442294))
    end)
    it("keeps the real melee probe working after changing to Annihilation",function()
        RA:RegisterModule("SpecDetector",{GetCurrentSpec=function() return {specID=577} end})
        C_Spell.GetOverrideSpell=function(id) return id==162794 and 201427 or id end
        C_Spell.IsSpellInRange=function() return true end
        UnitExists=function(u) return u=="target" or u=="nameplate1" end
        UnitCanAttack=function() return true end; UnitIsDead=function() return false end
        UnitAffectingCombat=function() return true end; UnitGUID=function(u) return u end
        UnitIsUnit=function(a,b) return a==b end
        assert(h.loadAddonFile("addon/Engine/TargetContext.lua","RotaAssist",ns))
        local target=RA:GetModule("TargetContext"); target:OnInitialize(); target:OnEnable()
        local snapshot=target:GetSnapshot(); assert.equals(201427,snapshot.probeSpellID)
        assert.equals(2,snapshot.nearbyEnemies); target:OnDisable()
    end)
    it("uses a confirmed replacement for Fury lower-bound evidence",function()
        C_Spell.GetOverrideSpell=function(id) return id==162794 and 201427 or id end
        C_Spell.GetSpellPowerCost=function() return {{type=17,minCost=40,cost=40,costPercent=0,costPerSec=0,requiredAuraID=0}} end
        C_Spell.IsSpellUsable=function() return true,false end
        assert(h.loadAddonFile("addon/Engine/ResourceEvidence.lua","RotaAssist",ns))
        local evidence=RA:GetModule("ResourceEvidence"):Observe({{spellID=201427}},17)
        assert.equals(40,evidence.min); assert.equals(1,evidence.observations)
    end)
end)
