-- test: hero selection, real aura reads, proc identity, range and queue integration.
local h=require("tests.helpers")
describe("aldrachi independent path",function()
    local RA,ns,O,build,ranks,proc,secret,target,seed
    local function state() return {targetValid=true,spellRange={},windows={},windowUnknown={essence_break=true}} end
    before_each(function()
        RA,ns=h.loadAddon(); h.loadRegistry(ns)
        secret={}; issecretvalue=function(v) return rawequal(v,secret) end
        GetTime=function() return 10 end; proc=true
        ranks={[442290]=1,[452402]=0}; build={talentsComplete=true,specID=577,generation=1}
        RA:RegisterModule("CharacterState",{GetSnapshot=function() return build end,GetTalentRank=function(_,id) return ranks[id] end})
        RA:RegisterModule("SpecDetector",{GetCurrentSpec=function() return {specID=577} end})
        RA:RegisterModule("APLEngine",{HasAPL=function() return true end,IsMetaActive=function() return false end,
            GetProfileName=function() return "default" end,GetCurrentAPL=function() return nil end,
            PredictNext=function(_,head) seed=head; return {} end})
        target={supported=true,targetValid=true,nearbyEnemies=1,countComplete=false,
            spellRange={},windows={},windowUnknown={essence_break=true},windowRemains={}}
        RA:RegisterModule("TargetContext",{IsActive=function() return true end,GetSnapshot=function() return target end,
            GetSpellRange=function() return true end})
        RA.IndependentPolicy={schema="rotaassist.independent-policy.v1",specID=577,heroProfile="fel_scarred",
            policySha256="fel",rules={{spellID=162243,conditions={}}}}
        RA.IndependentPolicies={aldrachi_reaver={schema="rotaassist.independent-policy.v1",specID=577,
            heroProfile="aldrachi_reaver",policySha256="aldrachi",rules={
                {spellID=442294,conditions={{"buff.reavers_glaive.up",">",0}}},{spellID=162794,conditions={}}}}}
        C_Secrets={ShouldAurasBeSecret=function() return false end,ShouldSpellAuraBeSecret=function() return false end}
        UnitExists=function() return true end; UnitIsVisible=function() return true end
        C_UnitAuras.GetPlayerAuraBySpellID=function(id)
            if id==444686 and proc then return {spellId=id,expirationTime=60} end
        end
        IsPlayerSpell=function(id) return id~=442294 end
        C_Spell.GetOverrideSpell=function(id) if id==185123 and proc then return 442294 end; return id end
        C_Spell.IsSpellUsable=function() return true end
        RA.GetSpellCooldownSafe=function() return 0,true,0,0 end
        for _,file in ipairs({"Core/EventHandler.lua","Engine/PublicAuraFacts.lua","Engine/IndependentDecision.lua","Engine/IndependentObserver.lua"}) do
            assert(h.loadAddonFile("addon/"..file,"RotaAssist",ns))
        end
        O=RA:GetModule("IndependentObserver")
    end)
    it("uses selected hero talents despite the shared default APL label",function()
        local result=O:Observe(state()); assert.equals(442294,result.spellID)
        assert.equals("aldrachi_reaver",result.heroProfile); assert.equals("aldrachi",result.policySha256)
        assert.is_false(result.performanceQualified)
    end)
    it("changes policies with the build and clears unknown or contradictory selection",function()
        O:Observe(state()); ranks[442290]=0; ranks[452402]=1
        local result=O:Observe(state()); assert.equals(162243,result.spellID); assert.equals("fel_scarred",result.heroProfile)
        ranks[442290]=1; assert.equals("conflicting_hero_talents",O:Observe(state()).status); assert.is_nil(O:GetStatus().spellID)
        build.talentsComplete=false; assert.equals("build_unknown",O:Observe(state()).status)
        build.talentsComplete=true; ranks[442290]=0; ranks[452402]=0
        assert.equals("hero_unknown",O:Observe(state()).status)
    end)
    it("does not infer hero identity from missing or secret talent ranks",function()
        ranks[442290]=secret; assert.equals("hero_unknown",O:Observe(state()).status)
        ranks[442290]=nil; assert.equals("hero_unknown",O:Observe(state()).status)
    end)
    it("does not let another known hero mask incomplete hero evidence",function()
        ranks[442290]=secret; ranks[452402]=1
        assert.equals("hero_unknown",O:Observe(state()).status)
        ranks[442290]=.5; assert.equals("hero_unknown",O:Observe(state()).status)
    end)
    it("queries current range for an action absent from the old APL snapshot",function()
        assert.is_nil(state().spellRange[442294]); assert.equals(442294,O:Observe(state()).spellID)
        RA:GetModule("TargetContext").GetSpellRange=function(_,id) return id~=442294 end
        assert.equals(162794,O:Observe(state()).spellID)
    end)
    it("does not recommend an expired proc or treat restricted aura state as absent",function()
        proc=false; assert.equals(162794,O:Observe(state()).spellID)
        proc=true; C_UnitAuras.GetPlayerAuraBySpellID=function(id) if id==444686 then return secret end end
        assert.equals("ambiguous",O:Observe(state()).status); assert.is_nil(O:GetStatus().spellID)
    end)
    it("keeps restricted override identity unknown even when the aura is visible",function()
        C_Spell.GetOverrideSpell=function() return secret end
        assert.equals("ambiguous",O:Observe(state()).status)
    end)
    it("accepts the proc through the real final queue filters and seeds prediction",function()
        RA.db={profile={display={showOutOfCombat=true},smartQueue={independentExperimental=true,
            blizzardWeight=1,aplWeight=.6,aiWeight=.4,cdWeight=.5,defWeight=.8}}}
        RA.SpecEnhancements={[577]={resource={powerType=17}}}
        UnitChannelInfo=function() return nil end
        RA:RegisterModule("AssistedCombatBridge",{GetCurrentRecommendation=function() return {spellID=370965} end,
            GetRotationSpells=function() return {370965} end})
        assert(h.loadAddonFile("addon/Engine/SmartQueueManager.lua","RotaAssist",ns))
        local queue=RA:GetModule("SmartQueueManager"); queue:OnInitialize(); queue:OnEnable(); queue._AssembleQueue()
        assert.equals(442294,queue:GetFinalQueue().main.spellID); assert.equals(442294,seed)
        proc=false; queue._AssembleQueue(); assert.equals(162794,queue:GetFinalQueue().main.spellID)
        queue:OnDisable()
    end)
    it("retains a native proc recommendation with independent mode disabled",function()
        RA.db={profile={display={showOutOfCombat=true},smartQueue={independentExperimental=false,
            blizzardWeight=1,aplWeight=.6,aiWeight=.4,cdWeight=.5,defWeight=.8}}}
        RA.SpecEnhancements={[577]={resource={powerType=17}}}
        UnitChannelInfo=function() return nil end
        RA:RegisterModule("AssistedCombatBridge",{GetCurrentRecommendation=function() return {spellID=442294} end,
            GetRotationSpells=function() return {442294} end})
        assert(h.loadAddonFile("addon/Engine/SmartQueueManager.lua","RotaAssist",ns))
        local queue=RA:GetModule("SmartQueueManager"); queue:OnInitialize(); queue:OnEnable(); queue._AssembleQueue()
        assert.equals(442294,queue:GetFinalQueue().main.spellID)
        proc=false; queue._AssembleQueue()
        local main=queue:GetFinalQueue().main
        assert.is_true(main==nil or main.spellID~=442294)
        queue:OnDisable()
    end)
    it("loads the shipped Aldrachi policy and recommends its live proc",function()
        assert(h.loadAddonFile("addon/Data/IndependentPolicy.lua","RotaAssist",ns))
        assert(h.loadAddonFile("addon/Data/IndependentAldrachi.lua","RotaAssist",ns))
        RA.GetSpellCooldownSafe=function(_,id) return id==442294 and 0 or 20,true,0,0 end
        local result=O:Observe(state())
        assert.equals(442294,result.spellID)
        assert.equals(RA.IndependentPolicies.aldrachi_reaver.policySha256,result.policySha256)
        assert.equals("aldrachi_reaver",result.heroProfile)
    end)
end)
