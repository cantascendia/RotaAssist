-- test: area applicability uses a current-target witness, not nil-as-in-range.
local h=require("tests.helpers")
describe("havoc action range evidence",function()
    local RA,ns,T,native,hasRange,melee,secret,spec,valid,time,handler
    before_each(function()
        RA,ns=h.loadAddon(); h.loadRegistry(ns)
        native=nil; hasRange=false; melee=true; secret={}; spec=577; valid=true; time=10
        issecretvalue=function(v) return rawequal(v,secret) end
        GetTime=function() return time end
        IsPlayerSpell=function() return true end
        C_Spell.GetOverrideSpell=function(id) return id end
        C_Spell.SpellHasRange=function() return hasRange end
        C_Spell.IsSpellInRange=function(id) if id==162794 then return melee end; return native end
        UnitExists=function(u) return u=="target" and valid end
        UnitCanAttack=function() return true end; UnitIsDead=function() return false end
        UnitGUID=function(u) return u end; UnitIsUnit=function(a,b) return a==b end
        RA:RegisterModule("SpecDetector",{GetCurrentSpec=function() return {specID=spec} end})
        assert(h.loadAddonFile("addon/Core/EventHandler.lua","RotaAssist",ns))
        handler=RA:GetModule("EventHandler")
        assert(h.loadAddonFile("addon/Engine/TargetContext.lua","RotaAssist",ns))
        T=RA:GetModule("TargetContext"); T:OnInitialize(); T:OnEnable()
    end)
    it("proves radial applicability without inventing native range",function()
        for _,id in ipairs({258920,188499,210152}) do
            local value,source=T:GetActionRange(id)
            assert.is_true(value); assert.equals("current_target_melee_witness",source)
            assert.is_nil(T:GetSpellRange(id))
        end
    end)
    it("preserves authoritative native range results",function()
        native=false; assert.is_false(T:GetActionRange(258920))
        native=true; T:Invalidate(false); local value,source=T:GetActionRange(258920)
        assert.is_true(value); assert.equals("native_spell_range",source)
    end)
    it("does not apply radial evidence to cones, ground or mobility actions",function()
        for _,id in ipairs({198013,258860,191427,198793,195072,442294}) do assert.is_nil(T:GetActionRange(id)) end
    end)
    it("requires a public no-range declaration and public positive melee proof",function()
        for _,v in ipairs({true,secret}) do hasRange=v; assert.is_nil(T:GetActionRange(258920)) end
        hasRange=nil; assert.is_nil(T:GetActionRange(258920))
        hasRange=false; melee=false; T:Invalidate(false); assert.is_nil(T:GetActionRange(258920))
        melee=secret; T:Invalidate(false); assert.is_nil(T:GetActionRange(258920))
        melee=nil; T:Invalidate(false); assert.is_nil(T:GetActionRange(258920))
    end)
    it("invalidates the proof on target switch, loss and specialization changes",function()
        assert.is_true(T:GetActionRange(258920)); melee=false
        handler:Fire("PLAYER_TARGET_CHANGED"); assert.is_nil(T:GetActionRange(258920))
        melee=true; valid=false; handler:Fire("PLAYER_TARGET_CHANGED"); assert.is_nil(T:GetActionRange(258920))
        valid=true; spec=581; T:Invalidate(true); assert.is_nil(T:GetActionRange(258920))
    end)
    it("does not manufacture eligibility when APIs fail or module is disabled",function()
        C_Spell.SpellHasRange=function() error("restricted") end
        assert.is_nil(T:GetActionRange(258920)); assert.is_nil(T:GetActionRange(secret))
        C_Spell.SpellHasRange=nil; assert.is_nil(T:GetActionRange(258920))
        C_Spell.SpellHasRange=function() return false end
        T:OnDisable(); assert.is_nil(T:GetActionRange(258920))
    end)
    it("feeds the real independent observer without changing generic range counts",function()
        RA.IndependentPolicy={schema="rotaassist.independent-policy.v1",heroProfile="fel_scarred",specID=577,
            rules={{spellID=258920,conditions={}}}}
        RA:RegisterModule("APLEngine",{GetProfileName=function() return "fel_scarred" end})
        RA.GetSpellCooldownSafe=function() return 0,true,0,0 end
        C_Spell.IsSpellUsable=function() return true end
        assert(h.loadAddonFile("addon/Engine/IndependentDecision.lua","RotaAssist",ns))
        assert(h.loadAddonFile("addon/Engine/IndependentObserver.lua","RotaAssist",ns))
        local O=RA:GetModule("IndependentObserver"); local result=O:Observe(T:GetSnapshot())
        assert.equals(258920,result.spellID)
        assert.equals("current_target_melee_witness",result.rangeEvidence[258920])
        melee=false; handler:Fire("PLAYER_TARGET_CHANGED")
        assert.equals("ambiguous",O:Observe(T:GetSnapshot()).status); assert.is_nil(O:GetStatus().spellID)
    end)
    it("takes the area witness through the real main queue and withdraws on target loss",function()
        local seed
        RA.IndependentPolicy={schema="rotaassist.independent-policy.v1",heroProfile="fel_scarred",specID=577,
            rules={{spellID=258920,conditions={}}}}
        RA:RegisterModule("APLEngine",{GetProfileName=function() return "fel_scarred" end,
            HasAPL=function() return true end,IsMetaActive=function() return false end,
            GetCurrentAPL=function() return nil end,
            PredictNext=function(_,id) seed=id; return {} end})
        RA:RegisterModule("AssistedCombatBridge",{GetCurrentRecommendation=function() return {spellID=162794} end,
            GetRotationSpells=function() return {162794} end})
        RA.db={profile={display={showOutOfCombat=true},smartQueue={independentExperimental=true,
            blizzardWeight=1,aplWeight=.6,aiWeight=.4,cdWeight=.5,defWeight=.8}}}
        RA.SpecEnhancements={[577]={resource={powerType=17}}}
        RA.GetSpellCooldownSafe=function() return 0,true,0,0 end
        C_Spell.IsSpellUsable=function() return true end; UnitChannelInfo=function() return nil end
        for _,name in ipairs({"IndependentDecision","IndependentObserver","SmartQueueManager"}) do
            assert(h.loadAddonFile("addon/Engine/"..name..".lua","RotaAssist",ns))
        end
        local queue=RA:GetModule("SmartQueueManager"); queue:OnInitialize(); queue:OnEnable(); queue._AssembleQueue()
        assert.equals(258920,queue:GetFinalQueue().main.spellID); assert.equals(258920,seed)
        valid=false; handler:Fire("PLAYER_TARGET_CHANGED"); queue._AssembleQueue()
        assert.is_nil(queue:GetFinalQueue().main); queue:OnDisable()
    end)
end)
