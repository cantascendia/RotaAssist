-- test: additive automatic spell discovery across specs, no user export.
local h=require("tests.helpers")
describe("runtime spell catalog",function()
    local RA,ns,C,items,events,secret
    before_each(function()
        RA,ns=h.loadAddon(); h.loadRegistry(ns)
        secret={}; issecretvalue=function(v) return rawequal(v,secret) end
        Enum.SpellBookSpellBank={Player=0}; Enum.SpellBookItemType={Spell=1}
        items={
            {itemType=1,actionID=100,spellID=101,isPassive=false,isOffSpec=false},
            {itemType=1,actionID=102,spellID=102,isPassive=true,isOffSpec=false},
            {itemType=1,actionID=103,spellID=103,isPassive=false,isOffSpec=true},
            {itemType=1,actionID=104,spellID=104,isPassive=false,isOffSpec=false},
            {itemType=2,actionID=105},
        }
        IsPlayerSpell=function(id) return id~=104 end
        C_SpellBook={GetNumSpellBookSkillLines=function() return 1 end,
            GetSpellBookSkillLineInfo=function() return {itemIndexOffset=0,numSpellBookItems=#items} end,
            GetSpellBookItemInfo=function(slot,bank) assert.equals(0,bank); return items[slot] end}
        assert(h.loadAddonFile("addon/Core/EventHandler.lua","RotaAssist",ns))
        assert(h.loadAddonFile("addon/Engine/SpellCatalog.lua","RotaAssist",ns))
        C=RA:GetModule("SpellCatalog"); events=RA:GetModule("EventHandler")
        C:OnInitialize(); C:OnEnable()
    end)
    after_each(function() C:OnDisable() end)
    it("discovers learned override IDs and excludes off-spec passive future and flyout entries",function()
        local s=C:GetSnapshot(); assert.is_true(s.complete)
        assert.equals(100,s.spells[101].baseSpellID)
        for _,id in ipairs({100,102,103,104,105}) do assert.is_nil(s.spells[id]) end
    end)
    it("clears stale spells immediately on specialization and talent changes",function()
        items={{itemType=1,actionID=200,spellID=200,isPassive=false,isOffSpec=false}}
        events:Fire("PLAYER_SPECIALIZATION_CHANGED","player")
        assert.is_nil(C:GetSnapshot().spells[101]); assert.is_not_nil(C:GetSnapshot().spells[200])
        items={}; events:Fire("SPELLS_CHANGED"); assert.is_nil(C:GetSnapshot().spells[200])
    end)
    it("retains a current override when the base spell establishes learning",function()
        IsPlayerSpell=function(id) return id==100 end
        C:Refresh(); assert.is_not_nil(C:GetSnapshot().spells[101])
    end)
    it("feeds discovered spells into real character metadata",function()
        GetSpecialization=function() return 1 end
        GetSpecializationInfo=function() return 63 end
        C_ClassTalents={GetActiveConfigID=function() return 1 end}
        C_Traits={ConfigHasStagedChanges=function() return false end,
            GetConfigInfo=function() return {treeIDs={1}} end,GetTreeNodes=function() return {1} end,
            GetNodeInfo=function() return {activeRank=1,activeEntry={entryID=2,rank=1},entryIDs={2}} end,
            GetEntryInfo=function() return {definitionID=3} end,GetDefinitionInfo=function() return {spellID=4} end}
        C_Spell.GetSpellInfo=function(id) return {spellID=id,castTime=1500,maxRange=40,minRange=0} end
        assert(h.loadAddonFile("addon/Engine/CharacterState.lua","RotaAssist",ns))
        local character=RA:GetModule("CharacterState"); character:OnInitialize()
        local s=character:Refresh()
        assert.is_true(s.talentsComplete); assert.is_true(s.spellbookComplete)
        assert.equals(40,s.spells[101].maxRange)
        character:Invalidate(); assert.is_false(character:GetSnapshot().spellbookComplete)
    end)
    it("guards secret fields and unavailable APIs without retaining a previous full catalog",function()
        items[1].spellID=secret; C:Refresh()
        assert.is_false(C:GetSnapshot().complete); assert.is_nil(C:GetSnapshot().spells[101])
        C_SpellBook.GetNumSpellBookSkillLines=function() error("restricted") end
        assert.is_false(C:Refresh().complete)
    end)
    it("bounds hostile or corrupt spellbook sizes",function()
        local calls=0
        C_SpellBook.GetSpellBookSkillLineInfo=function() return {itemIndexOffset=0,numSpellBookItems=2049} end
        C_SpellBook.GetSpellBookItemInfo=function() calls=calls+1 end
        assert.is_false(C:Refresh().complete); assert.equals(0,calls)
    end)
    it("does not rescan every read and unsubscribes on disable",function()
        local revision=C:GetSnapshot().revision
        C:GetSnapshot(); C:GetSnapshot(); assert.equals(revision,C:GetSnapshot().revision)
        C:OnDisable(); events:Fire("SPELLS_CHANGED"); assert.equals(revision,C:GetSnapshot().revision)
    end)
end)
