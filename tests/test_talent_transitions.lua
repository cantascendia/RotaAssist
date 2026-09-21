-- test: additive Test-Lock scenario 3; real APL integration plus transition contracts.
local h=require("tests.helpers")
describe("talent transitions",function()
    local RA,ns,T,APL,ranks,build
    local function state()
        return {cooldowns={[198013]=25,[188499]=7,[210152]=7,[370965]=50},
            cooldownUnknown={},inMeta=false,inMetaKnown=true,resource=100,windows={},
            windowUnknown={},windowRemains={},windowSteps={}}
    end
    before_each(function()
        RA,ns=h.loadAddon(); h.loadRegistry(ns)
        ranks={[213410]=1,[388112]=1}; build={talentsComplete=true,specID=577}
        RA:RegisterModule("CharacterState",{GetSnapshot=function() return build end,
            GetTalentRank=function(_,id) return ranks[id] end})
        assert(h.loadAddonFile("addon/Engine/TalentTransitions.lua","RotaAssist",ns))
        assert(h.loadAddonFile("addon/Engine/APLEngine.lua","RotaAssist",ns))
        T=RA:GetModule("TalentTransitions"); APL=RA:GetModule("APLEngine")
        RA.WhitelistSpells={[198013]={cdSeconds=30},[191427]={cdSeconds=120}}
        APL:SetAPL(577,{rules={}},12)
    end)
    it("extends Demonic by a lower bound without shortening an existing window",function()
        local s=state(); s.inMeta=true; s.metaRemains=11
        APL:SimulateSpellCast(s,198013)
        assert.equals(16,s.metaRemains); assert.is_true(s.inMetaKnown)
        assert.equals(16,s.windowRemains.demonic); assert.is_true(s.metaExpiryUncertain)
    end)
    it("does not create Demonic when it is unselected",function()
        ranks[213410]=0; local s=state(); APL:SimulateSpellCast(s,198013)
        assert.is_false(s.inMeta); assert.is_true(s.inMetaKnown); assert.is_nil(s.windows.demonic)
    end)
    it("retains unknown talent state instead of selecting or rejecting Demonic",function()
        build.talentsComplete=false; local s=state(); APL:SimulateSpellCast(s,198013)
        assert.is_false(s.inMetaKnown); assert.is_true(s.windowUnknown.demonic)
        assert.is_false(APL:EvaluateCondition("not_in_meta",1,s))
        assert.is_false(APL:EvaluateCondition("in_meta",1,s))
    end)
    it("preserves proven form when an extension talent is unreadable",function()
        ranks[213410]=nil; local s=state(); s.inMeta=true; s.metaRemains=9
        T:Apply(s,577,198013); assert.is_true(s.inMetaKnown); assert.equals(9,s.metaRemains)
        assert.is_true(s.metaExpiryUncertain)
    end)
    it("resets both shared forms and clears unknown CDs only with Chaotic Transformation",function()
        local s=state(); s.cooldownUnknown[198013]=true
        APL:SimulateSpellCast(s,191427)
        for _,id in ipairs({198013,188499,210152}) do
            assert.equals(0,s.cooldowns[id]); assert.is_nil(s.cooldownUnknown[id])
        end
        assert.equals(50,s.cooldowns[370965]); assert.equals(120,s.cooldowns[191427])
        assert.equals(20,s.metaRemains); assert.is_false(s.metaExpiryUncertain)
        ranks[388112]=0; s=state(); APL:SimulateSpellCast(s,191427)
        assert.equals(25,s.cooldowns[198013]); assert.equals(7,s.cooldowns[210152])
    end)
    it("invalidates uncertain reset results but preserves already ready cooldowns",function()
        ranks[388112]=nil; local s=state(); s.cooldowns[188499]=0
        T:Apply(s,577,191427)
        assert.is_nil(s.cooldowns[198013]); assert.is_true(s.cooldownUnknown[198013])
        assert.equals(0,s.cooldowns[188499]); assert.is_nil(s.cooldownUnknown[188499])
    end)
    it("extends manual Meta and keeps an unknown prior duration uncertain",function()
        local s=state(); s.inMeta=true; s.metaRemains=6
        T:Apply(s,577,191427); assert.equals(26,s.metaRemains)
        s=state(); s.inMetaKnown=false; T:Apply(s,577,191427)
        assert.equals(20,s.metaRemains); assert.is_true(s.metaExpiryUncertain)
    end)
    it("does not alter other specializations",function()
        local s=state(); assert.is_false(T:Apply(s,581,191427))
        assert.equals(25,s.cooldowns[198013]); assert.is_false(s.inMeta)
    end)
    it("changes actual predicted next action with the reset talent",function()
        IsPlayerSpell=function() return true end
        APL:SetAPL(577,{rules={{spellID=198013,priority=1,condition="cd_ready"},
            {spellID=232893,priority=2,condition="always"}}},12)
        local s=state(); s.combatDuration=20
        assert.equals(198013,APL:PredictNext(191427,s,1)[1].spellID)
        ranks[388112]=0
        assert.equals(232893,APL:PredictNext(191427,s,1)[1].spellID)
        assert.equals(25,s.cooldowns[198013]); assert.is_false(s.inMeta)
    end)
    it("expires the Demonic lower bound to unknown rather than normal form",function()
        IsPlayerSpell=function() return true end
        C_Spell.GetSpellInfo=function(id) return {spellID=id,castTime=0} end
        APL:SetAPL(577,{rules={{spellID=232893,priority=1,condition="in_meta"},
            {spellID=162243,priority=2,condition="not_in_meta"}}},12)
        local s=state(); s.combatDuration=20
        local p=APL:PredictNext(198013,s,8)
        assert.equals(3,#p)
        for _,prediction in ipairs(p) do assert.equals(232893,prediction.spellID) end
    end)
    it("gates live cast estimates and clears them on build change",function()
        assert(h.loadAddonFile("addon/Core/EventHandler.lua","RotaAssist",ns)); APL:OnEnable()
        C_Timer.After=function() end
        ranks[213410]=0; APL:SetMetaStateFromCast(198013); assert.is_false(APL:IsMetaActive())
        ranks[213410]=nil; APL:SetMetaStateFromCast(198013); assert.is_false(APL:IsMetaActive())
        ranks[213410]=1; APL:SetMetaStateFromCast(198013); assert.is_true(APL:IsMetaActive())
        RA:GetModule("EventHandler"):Fire("ROTAASSIST_CHARACTER_CHANGED")
        assert.is_false(APL:IsMetaActive()); APL:OnDisable()
    end)
end)
