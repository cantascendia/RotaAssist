-- Public character context, rebuilt on configuration events, never every frame.
-- 公开角色配置按事件重建；未提交/不完整的读取不当作有效 build。
local _,NS=...
local RA=NS.RA
local Character={}
RA:RegisterModule("CharacterState",Character)
local snapshot={spellIDs={},definitionIDs={},names={},ranks={},rankAmbiguous={},equipment={},stats={},spells={}}
local tokens,seenNodes,spellSet={},{},{}
local generation=0
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function number(v)
    if public(v) and type(v)=="number" and v==v and math.abs(v)<math.huge then return v end
end
local function integer(v)
    local n=number(v); if n and n>=0 and n%1==0 then return n end
end
local function tableValue(v) if public(v) and type(v)=="table" then return v end end
local function stringValue(v) if public(v) and type(v)=="string" then return v end end
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b,c=pcall(fn,...)
    if ok then return a,b,c end
end
local function boolean(fn,...)
    local v=call(fn,...); if public(v) and type(v)=="boolean" then return v end
end
local function publish()
    local events=RA:GetModule("EventHandler")
    if events then events:Fire("ROTAASSIST_CHARACTER_CHANGED",generation,snapshot.talentsComplete) end
end
function Character:Invalidate(reason)
    generation=generation+1
    snapshot.generation,snapshot.reason=generation,reason or "invalidated"
    snapshot.talentsComplete,snapshot.equipmentComplete=false,false
    snapshot.talentKey,snapshot.equipmentKey,snapshot.importString=nil,nil,nil
    snapshot.specID,snapshot.heroID,snapshot.configID=nil,nil,nil
    snapshot.nodeCount,snapshot.selectedCount=0,0
    snapshot.statsComplete,snapshot.statsObservedAt=false,nil
    for _,key in ipairs({"spellIDs","definitionIDs","names","ranks","rankAmbiguous","equipment","stats","spells"}) do wipe(snapshot[key]) end
    publish()
end
local function collectTalents()
    local traits,classes=C_Traits,C_ClassTalents
    if not traits or not classes then return "api_unavailable" end
    local specIndex=integer(call(GetSpecialization))
    if not specIndex then return "specialization_unknown" end
    snapshot.specID=integer(call(GetSpecializationInfo,specIndex))
    local config=integer(call(classes.GetActiveConfigID))
    if not config or not snapshot.specID then return "configuration_unknown" end
    snapshot.configID=config
    if boolean(traits.ConfigHasStagedChanges,config)~=false then return "staged_changes" end
    local info=tableValue(call(traits.GetConfigInfo,config))
    local trees=info and tableValue(info.treeIDs)
    if not trees or #trees==0 then return "tree_unknown" end
    wipe(tokens); wipe(seenNodes)
    local hero=call(classes.GetActiveHeroTalentSpec)
    snapshot.heroID=integer(hero)
    for _,tree in ipairs(trees) do
        local treeID=integer(tree)
        if not treeID then return "tree_unknown" end
        local nodes=tableValue(call(traits.GetTreeNodes,treeID))
        if not nodes or #nodes==0 then return "nodes_unknown" end
        for _,rawID in ipairs(nodes) do
            local id=integer(rawID)
            if not id or seenNodes[id] then return "node_identity_unknown" end
            seenNodes[id]=true; snapshot.nodeCount=snapshot.nodeCount+1
            if snapshot.nodeCount>1024 then return "node_limit" end
            local node=tableValue(call(traits.GetNodeInfo,config,id))
            local rank=node and integer(node.activeRank)
            local entries=node and tableValue(node.entryIDs)
            if not rank or not entries or #entries==0 then return "node_unknown" end
            local subtree=number(node.subTreeID)
            if not public(node.subTreeID) or (subtree and boolean(function() return node.subTreeActive end)==nil) then return "subtree_unknown" end
            if subtree and node.subTreeActive==false then rank=0 end
            local active=tableValue(node.activeEntry)
            local activeID=active and integer(active.entryID)
            if rank>0 and (not activeID or integer(active.rank)~=rank) then return "selected_entry_unknown" end
            local found=rank==0
            for _,rawEntry in ipairs(entries) do
                local entryID=integer(rawEntry)
                if not entryID then return "entry_unknown" end
                local entry=tableValue(call(traits.GetEntryInfo,config,entryID))
                if not entry or not public(entry.definitionID) or not public(entry.subTreeID) then return "entry_unknown" end
                local definition=integer(entry.definitionID)
                local spell
                if definition then
                    local data=tableValue(call(traits.GetDefinitionInfo,definition))
                    if not data or not public(data.spellID) then return "definition_unknown" end
                    spell=integer(data.spellID)
                    if spell then snapshot.ranks[spell]=snapshot.ranks[spell] or 0 end
                elseif not integer(entry.subTreeID) then return "definition_unknown" end
                if rank>0 and entryID==activeID then
                    found=true; snapshot.selectedCount=snapshot.selectedCount+1
                    tokens[#tokens+1]=string.format("%d:%d:%d",id,entryID,rank)
                    if definition then snapshot.definitionIDs[definition]=true end
                    if spell then
                        if snapshot.spellIDs[spell] then snapshot.rankAmbiguous[spell]=true end
                        snapshot.ranks[spell]=rank
                        snapshot.spellIDs[spell]=true
                    end
                end
            end
            if not found then return "selected_entry_missing" end
        end
    end
    local imported=stringValue(call(traits.GenerateImportString,config))
    if integer(call(classes.GetActiveConfigID))~=config
       or boolean(traits.ConfigHasStagedChanges,config)~=false
       or integer(call(GetSpecialization))~=specIndex
       or integer(call(GetSpecializationInfo,specIndex))~=snapshot.specID then return "configuration_changed" end
    table.sort(tokens)
    snapshot.talentKey=string.format("%d|%s|",snapshot.specID,tostring(snapshot.heroID or "?"))..table.concat(tokens,";")
    if imported and #imported<=4096 and imported:match("^[A-Za-z0-9+/=]+$") then snapshot.importString=imported end
    snapshot.talentsComplete=true
    return "ready"
end
local function collectEquipment()
    wipe(tokens)
    local complete=type(GetInventoryItemID)=="function" and type(GetInventoryItemLink)=="function"
    for slot=1,19 do
        local ok,id=false,nil
        if type(GetInventoryItemID)=="function" then ok,id=pcall(GetInventoryItemID,"player",slot) end
        if not ok or not public(id) then complete=false
        elseif id==nil then tokens[#tokens+1]=slot..":empty"
        elseif integer(id) and id>0 then
            local link=stringValue(call(GetInventoryItemLink,"player",slot))
            local token=link and link:match("|H(item:[^|]+)|h")
            snapshot.equipment[slot]={itemID=id,token=token}
            if token then tokens[#tokens+1]=slot..":"..token else complete=false end
        else complete=false end
    end
    snapshot.equipmentComplete=complete
    if complete then snapshot.equipmentKey=table.concat(tokens,";") end
end
local function collectStats()
    local stats=snapshot.stats
    wipe(stats)
    stats.haste=number(call(GetHaste)); stats.crit=number(call(GetCritChance))
    stats.mastery=number(call(GetMasteryEffect))
    local base,positive,negative=call(UnitAttackPower,"player")
    base,positive,negative=number(base),number(positive),number(negative)
    if base and positive and negative then stats.attackPower=base+positive+negative end
    local versatilityRating=integer(CR_VERSATILITY_DAMAGE_DONE)
    if versatilityRating then stats.versatility=number(call(GetCombatRatingBonus,versatilityRating)) end
    snapshot.statsComplete=stats.haste~=nil and stats.crit~=nil and stats.mastery~=nil
        and stats.attackPower~=nil and stats.versatility~=nil
    snapshot.statsRevision=(snapshot.statsRevision or 0)+1
    snapshot.statsObservedAt=number(call(GetTime))
end
local function collectSpells()
    wipe(spellSet)
    for id in pairs(snapshot.spellIDs) do spellSet[id]=true end
    local policy=RA.IndependentPolicy
    if policy and policy.specID==snapshot.specID then for _,rule in ipairs(policy.rules) do spellSet[rule.spellID]=true end end
    local enh=RA.SpecEnhancements and RA.SpecEnhancements[snapshot.specID]
    if enh and enh.resource and enh.resource.spellCosts then for id in pairs(enh.resource.spellCosts) do spellSet[id]=true end end
    for id in pairs(spellSet) do
        local data=tableValue(call(C_Spell and C_Spell.GetSpellInfo,id))
        local observed={known=boolean(IsPlayerSpell,id)}
        if data then
            observed.resolvedSpellID=integer(data.spellID)
            observed.castTimeMS=number(data.castTime)
            observed.minRange,observed.maxRange=number(data.minRange),number(data.maxRange)
        end
        -- Base cooldown is not a promise about talent/buff-adjusted cooldown.
        -- 基础冷却不代表天赋/光环修正后的实际冷却。
        observed.baseCooldownMS=number(call(GetSpellBaseCooldown,id))
        local evidence=RA:GetModule("ResourceEvidence")
        if evidence and enh and enh.resource then
            observed.minimumResourceCost=evidence:GetMinimumCost(id,enh.resource.powerType or enh.resource.type)
        end
        observed.observedAt=number(call(GetTime))
        snapshot.spells[id]=observed
    end
end
function Character:Refresh()
    self:Invalidate("refreshing")
    snapshot.reason=collectTalents()
    if snapshot.talentsComplete then collectEquipment(); collectStats(); collectSpells() end
    publish()
    return snapshot
end
function Character:GetSnapshot() return snapshot end
function Character:GetTalentRank(spellID)
    if snapshot.talentsComplete and not snapshot.rankAmbiguous[spellID] then return snapshot.ranks[spellID] end
end
function Character:PrintSummary()
    local s=self:Refresh()
    local L=RA.L
    if not s.talentsComplete then RA:Print(L["BUILD_UNKNOWN"]); return end
    local gearCount,spellCount=0,0
    for _ in pairs(s.equipment) do gearCount=gearCount+1 end
    for _ in pairs(s.spells) do spellCount=spellCount+1 end
    RA:Print(string.format(L["BUILD_STATUS"],s.specID,s.configID,tostring(s.heroID or "?"),s.selectedCount,s.nodeCount))
    RA:Print(string.format(L["BUILD_METADATA"],gearCount,s.equipmentComplete and L["BUILD_READY"] or L["BUILD_UNKNOWN"],spellCount))
    RA:Print(string.format(L["BUILD_STATS"],tostring(s.stats.attackPower or "?"),tostring(s.stats.haste or "?"),
        tostring(s.stats.crit or "?"),tostring(s.stats.mastery or "?")))
    if s.importString then RA:Print(string.format(L["BUILD_IMPORT"],s.importString)) end
    RA:Print(L["BUILD_LIMITS"])
end
function Character:OnInitialize() self:Invalidate("unavailable") end
function Character:OnEnable()
    local events=RA:GetModule("EventHandler")
    if events then
        for _,name in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_SPECIALIZATION_CHANGED","TRAIT_CONFIG_UPDATED",
            "PLAYER_TALENT_UPDATE","PLAYER_EQUIPMENT_CHANGED","SPELLS_CHANGED","PLAYER_REGEN_ENABLED"}) do
            events:Subscribe(name,"CharacterState",function() self:Refresh() end)
        end
        -- Dynamic attributes do not require rescanning the entire talent tree.
        -- 动态属性单独刷新，避免为每次属性变化重扫天赋树。
        for _,name in ipairs({"UNIT_STATS","UNIT_ATTACK_POWER","UNIT_SPELL_HASTE"}) do
            events:Subscribe(name,"CharacterState",function(_,unit)
                if public(unit) and unit=="player" then collectStats() end
            end)
        end
        events:Subscribe("COMBAT_RATING_UPDATE","CharacterState",collectStats)
    end
    self:Refresh()
end
function Character:OnDisable()
    local events=RA:GetModule("EventHandler")
    if events then events:UnsubscribeAll("CharacterState") end
    self:Invalidate("disabled")
end
