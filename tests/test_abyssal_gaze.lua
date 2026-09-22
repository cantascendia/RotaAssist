-- test: an actual enhanced Eye Beam cast must not be treated as a new skill.
local h=require("tests.helpers")
describe("abyssal gaze burst integration",function()
    local RA,ns,T,ranks,active,secret
    before_each(function()
        RA,ns=h.loadAddon(); h.loadRegistry(ns); active=true; secret={}
        issecretvalue=function(v) return rawequal(v,secret) end
        IsPlayerSpell=function(id) return id~=452497 end
        C_Spell.GetOverrideSpell=function(id) if id==198013 and active then return 452497 end; return id end
        C_Spell.IsSpellUsable=function() return true end
        RA.GetSpellCooldownSafe=function() return 0,true,0,0 end
        ranks={[213410]=1,[388112]=1}
        RA:RegisterModule("CharacterState",{GetSnapshot=function() return {talentsComplete=true,specID=577} end,
            GetTalentRank=function(_,id) return ranks[id] end})
        assert(h.loadAddonFile("addon/Engine/TalentTransitions.lua","RotaAssist",ns)); T=RA:GetModule("TalentTransitions")
    end)
    it("accepts the currently confirmed replacement and rejects it after expiry",function()
        assert.is_true(RA:IsPlayerSpellKnownSafe(452497)); assert.is_true(RA:IsSpellRecommendable(452497))
        active=false; assert.is_false(RA:IsPlayerSpellKnownSafe(452497))
        assert.is_false(RA:IsSpellRecommendable(452497))
    end)
    it("keeps restricted replacement identity unknown",function()
        C_Spell.GetOverrideSpell=function() return secret end
        assert.is_nil(RA:IsPlayerSpellKnownSafe(452497)); assert.is_false(RA:IsSpellRecommendable(452497))
    end)
    it("applies selected Demonic to the enhanced cast and preserves uncertainty",function()
        local s={cooldowns={},inMeta=true,inMetaKnown=true,metaRemains=3}
        assert.is_true(T:Apply(s,577,452497)); assert.equals(8,s.metaRemains)
        assert.is_true(s.metaExpiryUncertain)
        ranks[213410]=0; s={cooldowns={},inMeta=false,inMetaKnown=true}
        assert.is_true(T:Apply(s,577,452497)); assert.is_false(s.inMeta)
        ranks[213410]=secret; s={cooldowns={},inMeta=false,inMetaKnown=true}
        T:Apply(s,577,452497); assert.is_false(s.inMetaKnown)
    end)
    it("resets both Eye Beam cooldown identities after selected Chaotic Transformation",function()
        local s={cooldowns={[198013]=20,[452497]=20}}
        T:Apply(s,577,191427); assert.equals(0,s.cooldowns[198013]); assert.equals(0,s.cooldowns[452497])
    end)
    it("soft-blocks both identities when a just-cast replacement only has base metadata",function()
        RA:RegisterModule("SpecDetector",{GetCurrentSpec=function() return {specID=577} end})
        -- Native recommendations are intentionally exempt from the soft-block.
        -- Exercise the predicted candidate path, keeping the assertion unchanged.
        RA:RegisterModule("AssistedCombatBridge",{GetCurrentRecommendation=function() return nil end,
            GetRotationSpells=function() return {198013} end})
        RA:RegisterModule("APLEngine",{HasAPL=function() return true end,IsMetaActive=function() return false end,
            GetCurrentAPL=function() return nil end,
            PredictNext=function() return {{spellID=452497,confidence=1}} end})
        RA.WhitelistSpells={[198013]={cdSeconds=30}}
        RA.db={profile={display={showOutOfCombat=true},smartQueue={blizzardWeight=1,aplWeight=.6,aiWeight=.4,cdWeight=.5,defWeight=.8}}}
        for _,file in ipairs({"Core/EventHandler.lua","Engine/SmartQueueManager.lua"}) do
            assert(h.loadAddonFile("addon/"..file,"RotaAssist",ns))
        end
        local q=RA:GetModule("SmartQueueManager"); q:OnInitialize(); q:OnEnable(); q._AssembleQueue()
        assert.equals(452497,q:GetFinalQueue().main.spellID)
        RA:GetModule("EventHandler"):Fire("ROTAASSIST_SPELLCAST_SUCCEEDED","player","gaze-1",452497)
        assert.is_nil(q:GetFinalQueue().main)
        RA:GetModule("EventHandler"):Fire("ROTAASSIST_CD_UPDATED")
        assert.equals(452497,q:GetFinalQueue().main.spellID); q:OnDisable()
    end)
end)
