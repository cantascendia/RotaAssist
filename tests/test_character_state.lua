-- test: additive character snapshot contract, including staged-edit/race boundaries.
local h=require("tests.helpers")
describe("character state",function()
    local RA,C,ns,nodes,staged,configID
    before_each(function()
        RA,ns=h.loadAddon(); configID=7; staged=false
        GetSpecialization=function() return 1 end
        GetSpecializationInfo=function() return 577 end
        nodes={10,20}
        C_ClassTalents={GetActiveConfigID=function() return configID end,GetActiveHeroTalentSpec=function() return 99 end}
        C_Traits={ConfigHasStagedChanges=function() return staged end,
            GetConfigInfo=function() return {treeIDs={1}} end,
            GetTreeNodes=function() return nodes end,
            GetNodeInfo=function(_,id)
                if id==10 then return {activeRank=2,activeEntry={entryID=100,rank=2},entryIDs={100,101}} end
                return {activeRank=1,activeEntry={entryID=200,rank=1},entryIDs={200}}
            end,
            GetEntryInfo=function(_,id) return id==200 and {subTreeID=99} or {definitionID=id+1000} end,
            GetDefinitionInfo=function(id) return {spellID=id+10000} end,
            GenerateImportString=function() return "ABC123==" end}
        GetInventoryItemID=function(_,slot) return slot==16 and 500 or nil end
        GetInventoryItemLink=function(_,slot) return slot==16 and "|cffaabbcc|Hitem:500:12:3|h[localized name]|h|r" or nil end
        GetHaste=function() return 17 end; GetCritChance=function() return 20 end
        GetMasteryEffect=function() return 25 end
        UnitAttackPower=function() return 100,20,-5 end
        IsPlayerSpell=function() return true end
        C_Spell.GetSpellInfo=function(id) return {spellID=id,castTime=1500,minRange=0,maxRange=40} end
        assert(h.loadAddonFile("addon/Engine/CharacterState.lua","RotaAssist",ns))
        C=RA:GetModule("CharacterState"); C:OnInitialize()
    end)
    it("captures only selected ranks and handles hero selection without a definition",function()
        local s=C:Refresh()
        assert.is_true(s.talentsComplete); assert.equals(577,s.specID); assert.equals(99,s.heroID)
        assert.equals(2,C:GetTalentRank(11100)); assert.equals(0,C:GetTalentRank(11101))
        assert.is_nil(C:GetTalentRank(99999)); assert.is_true(s.spellIDs[11100]); assert.is_nil(s.spellIDs[11101])
        assert.equals("ABC123==",s.importString); assert.equals(115,s.stats.attackPower)
        assert.equals("item:500:12:3",s.equipment[16].token); assert.is_true(s.equipmentComplete)
        assert.equals(1500,s.spells[11100].castTimeMS)
    end)
    it("does not publish pending edits or retain the previous build",function()
        C:Refresh(); staged=true
        local s=C:Refresh()
        assert.is_false(s.talentsComplete); assert.is_nil(s.talentKey); assert.is_nil(C:GetTalentRank(11100))
        assert.equals("staged_changes",s.reason)
    end)
    it("rejects configuration changes during the scan",function()
        C_Traits.GetDefinitionInfo=function(id) configID=8; return {spellID=id+10000} end
        assert.is_false(C:Refresh().talentsComplete)
        assert.equals("configuration_changed",C:GetSnapshot().reason)
    end)
    it("retains unknown instead of empty gear and missing stats",function()
        GetInventoryItemLink=function() return nil end
        GetHaste=function() error("unavailable") end
        local s=C:Refresh()
        assert.is_false(s.equipmentComplete); assert.is_nil(s.equipmentKey)
        assert.is_nil(s.stats.haste); assert.is_true(s.talentsComplete)
    end)
    it("guards protected nodes and invalidates synchronously",function()
        local secret=setmetatable({},{__lt=function() error("secret comparison") end})
        issecretvalue=function(v) return rawequal(v,secret) end
        C_Traits.GetNodeInfo=function() return secret end
        assert.is_false(C:Refresh().talentsComplete)
        C_Traits.GetNodeInfo=function() return {activeRank=secret} end
        assert.is_false(C:Refresh().talentsComplete)
        C:Invalidate("test")
        assert.is_false(C:GetSnapshot().talentsComplete)
    end)
    it("build identity is stable across node order but sensitive to ranks and gear modifiers",function()
        local original=C:Refresh().talentKey
        nodes={20,10}; assert.equals(original,C:Refresh().talentKey)
        local gear=C:GetSnapshot().equipmentKey
        GetInventoryItemLink=function(_,slot) return slot==16 and "|Hitem:500:99:3|h[other language]|h" or nil end
        assert.is_true(C:Refresh().equipmentKey~=gear)
        C_Traits.GetNodeInfo=function(_,id)
            if id==10 then return {activeRank=1,activeEntry={entryID=100,rank=1},entryIDs={100,101}} end
            return {activeRank=1,activeEntry={entryID=200,rank=1},entryIDs={200}}
        end
        assert.is_true(C:Refresh().talentKey~=original)
    end)
    it("refreshes the actual APL profile and clears it on invalidation",function()
        assert(h.loadAddonFile("addon/Core/EventHandler.lua","RotaAssist",ns))
        assert(h.loadAddonFile("addon/Engine/APLEngine.lua","RotaAssist",ns))
        local APL=RA:GetModule("APLEngine"); APL:OnEnable()
        C:Refresh()
        APL:SetAPL(577,{profiles={default={},fel_scarred={signatureTalentSpellIDs={11100}}}},12)
        assert.equals("fel_scarred",APL:GetProfileName())
        C:Invalidate("equipment_changed")
        assert.equals("default",APL:GetProfileName())
        C:Refresh(); assert.equals("fel_scarred",APL:GetProfileName())
        APL:OnDisable()
    end)
    it("uses talent ranks in independent decisions and blocks an unknown build",function()
        C:Refresh()
        RA.IndependentPolicy={schema="rotaassist.independent-policy.v1",specID=577,heroProfile="fel_scarred",rules={
            {spellID=1,conditions={{"talent.11100.rank",">=",2}}},{spellID=2,conditions={}}}}
        RA:RegisterModule("SpecDetector",{GetCurrentSpec=function() return {specID=577} end})
        RA:RegisterModule("APLEngine",{GetProfileName=function() return "fel_scarred" end})
        RA.GetSpellCooldownSafe=function() return 0 end
        C_Spell.IsSpellUsable=function() return true end
        assert(h.loadAddonFile("addon/Engine/IndependentDecision.lua","RotaAssist",ns))
        assert(h.loadAddonFile("addon/Engine/IndependentObserver.lua","RotaAssist",ns))
        local O=RA:GetModule("IndependentObserver")
        local state={targetValid=true,spellRange={[1]=true,[2]=true}}
        assert.equals(1,O:Observe(state).spellID)
        C:Invalidate("test")
        assert.equals("build_unknown",O:Observe(state).status); assert.is_nil(O:GetStatus().spellID)
    end)
    it("refreshes on configuration events and stops callbacks when disabled",function()
        assert(h.loadAddonFile("addon/Core/EventHandler.lua","RotaAssist",ns))
        local events=RA:GetModule("EventHandler")
        C:OnEnable(); local generation=C:GetSnapshot().generation
        events:Fire("PLAYER_EQUIPMENT_CHANGED",16)
        assert.is_true(C:GetSnapshot().generation>generation)
        C:OnDisable(); generation=C:GetSnapshot().generation
        events:Fire("PLAYER_EQUIPMENT_CHANGED",16)
        assert.equals(generation,C:GetSnapshot().generation)
    end)
    it("updates dynamic attributes without rescanning talents and clears unreadable old stats",function()
        assert(h.loadAddonFile("addon/Core/EventHandler.lua","RotaAssist",ns))
        local events=RA:GetModule("EventHandler")
        C:OnEnable(); local generation=C:GetSnapshot().generation
        GetHaste=function() return 30 end
        events:Fire("UNIT_SPELL_HASTE","player")
        assert.equals(30,C:GetSnapshot().stats.haste)
        assert.equals(generation,C:GetSnapshot().generation)
        UnitAttackPower=function() error("restricted") end
        events:Fire("UNIT_ATTACK_POWER","player")
        assert.is_nil(C:GetSnapshot().stats.attackPower)
        C:OnDisable()
    end)
end)
