-- test: end-to-end public alternatives and explicit independent head selection.
local helpers=require("tests.helpers")
describe("public-signal independent queue",function()
    local RA,ns,Q,O,events,target,seed,secret
    before_each(function()
        RA,ns=helpers.loadAddon(); helpers.loadRegistry(ns)
        RA.L=setmetatable({},{__index=function(_,key) return key end})
        RA.db={profile={display={showOutOfCombat=true},smartQueue={independentExperimental=true,
            blizzardWeight=1,aplWeight=0.6,aiWeight=0.4,cdWeight=0.5,defWeight=0.8}}}
        RA.SpecEnhancements={[577]={resource={powerType=17}}}
        if not string.trim then string.trim=function(s) return s:match("^%s*(.-)%s*$") end end
        secret={}; issecretvalue=function(v) return rawequal(v,secret) end
        UnitPower=function() return secret end
        UnitChannelInfo=function() return nil end
        C_Spell.GetSpellPowerCost=function(id)
            if id==162794 then return {{type=17,minCost=40,cost=40,costPercent=0,costPerSec=0,requiredAuraID=0,hasRequiredAura=false}} end
            return {}
        end
        C_Spell.IsSpellUsable=function(id) return id~=162794,id==162794 end
        RA.GetSpellCooldownSafe=function() return 0,true,0,0 end
        IsPlayerSpell=function() return true end
        target={supported=true,targetValid=true,nearbyEnemies=1,countComplete=false,
            spellRange=setmetatable({},{__index=function() return true end}),
            windows={},windowUnknown={essence_break=true},windowRemains={}}
        RA:RegisterModule("TargetContext",{IsActive=function() return true end,GetSnapshot=function() return target end})
        RA:RegisterModule("SpecDetector",{GetCurrentSpec=function() return {specID=577} end})
        RA:RegisterModule("AssistedCombatBridge",{GetCurrentRecommendation=function() return {spellID=370965} end,
            GetRotationSpells=function() return {370965,232893} end})
        RA:RegisterModule("APLEngine",{HasAPL=function() return true end,IsMetaActive=function() return false end,
            GetProfileName=function() return "fel_scarred" end,GetCurrentAPL=function() return nil end,
            PredictNext=function(_,head) seed=head; return {{spellID=162243,confidence=0.5}} end})
        for _,file in ipairs({"Core/EventHandler.lua","Data/IndependentPolicy.lua","Engine/IndependentDecision.lua",
            "Engine/ResourceEvidence.lua","Engine/IndependentObserver.lua","Engine/SmartQueueManager.lua"}) do
            assert(helpers.loadAddonFile("addon/"..file,"RotaAssist",ns))
        end
        Q=RA:GetModule("SmartQueueManager"); O=RA:GetModule("IndependentObserver"); events=RA:GetModule("EventHandler")
        Q:OnInitialize(); Q:OnEnable()
    end)
    after_each(function() Q:OnDisable() end)
    it("replaces a different valid reference using resource inequalities and reseeds the tail",function()
        Q._AssembleQueue()
        assert.equals(232893,Q:GetFinalQueue().main.spellID)
        assert.equals("INDEPENDENT",Q:GetFinalQueue().main.source)
        assert.equals(232893,seed)
        assert.equals(370965,O:GetStatus().referenceSpellID)
        assert.equals(40,O:GetStatus().resourceEvidence.max)
        assert.equals(162243,Q:GetFinalQueue().next[1].spellID)
    end)
    it("keeps the reference when bounds are unavailable or mode is disabled",function()
        C_Spell.GetSpellPowerCost=function() return secret end
        Q._AssembleQueue()
        assert.equals(370965,Q:GetFinalQueue().main.spellID)
        assert.equals(370965,seed)
        RA.db.profile.smartQueue.independentExperimental=false
        Q._AssembleQueue()
        assert.equals(370965,Q:GetFinalQueue().main.spellID)
    end)
    it("does not replace the head during a channel",function()
        UnitChannelInfo=function() return "channel" end
        Q._AssembleQueue()
        assert.equals(370965,Q:GetFinalQueue().main.spellID)
    end)
    it("clears old head immediately when switched off or target becomes invalid",function()
        Q._AssembleQueue(); assert.equals(232893,Q:GetFinalQueue().main.spellID)
        RA:SlashCommand("independent off")
        assert.is_false(RA.db.profile.smartQueue.independentExperimental)
        assert.is_nil(Q:GetFinalQueue().main)
        Q._AssembleQueue(); assert.equals(370965,Q:GetFinalQueue().main.spellID)
        RA:SlashCommand("independent on")
        assert.is_true(RA.db.profile.smartQueue.independentExperimental)
        Q._AssembleQueue(); assert.equals(232893,Q:GetFinalQueue().main.spellID)
        target.targetValid=false; events:Fire("ROTAASSIST_TARGET_CONTEXT_CHANGED")
        assert.is_nil(Q:GetFinalQueue().main)
        Q._AssembleQueue(); assert.is_nil(Q:GetFinalQueue().main)
    end)
    it("does not enable research mode on a malformed command",function()
        RA.db.profile.smartQueue.independentExperimental=false
        RA:SlashCommand("independent maybe")
        assert.is_false(RA.db.profile.smartQueue.independentExperimental)
    end)
end)
