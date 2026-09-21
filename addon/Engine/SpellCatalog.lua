-- Automatic, spec-independent active spellbook catalog. No per-frame scans.
-- 自动发现当前专精的主动技能；职业无关，按事件重建。
local _,NS=...
local RA=NS.RA
local Catalog={}
RA:RegisterModule("SpellCatalog",Catalog)
local snapshot={spells={},complete=false,revision=0}
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function integer(v)
    if public(v) and type(v)=="number" and v>=0 and v<math.huge and v%1==0 then return v end
end
local function tableValue(v) if public(v) and type(v)=="table" then return v end end
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...); if ok then return v end
end
local function flag(v) if public(v) and type(v)=="boolean" then return v end end
local function scan()
    local api=C_SpellBook
    local bank=Enum and Enum.SpellBookSpellBank and integer(Enum.SpellBookSpellBank.Player)
    local spellType=Enum and Enum.SpellBookItemType and integer(Enum.SpellBookItemType.Spell)
    if not api or not bank or not spellType then return "api_unavailable" end
    local count=integer(call(api.GetNumSpellBookSkillLines))
    if not count or count==0 or count>32 then return "skill_lines_unknown" end
    local visited=0
    for line=1,count do
        local info=tableValue(call(api.GetSpellBookSkillLineInfo,line))
        local offset=info and integer(info.itemIndexOffset)
        local slots=info and integer(info.numSpellBookItems)
        if not offset or not slots or offset+slots>2048 then return "slots_unknown" end
        for slot=offset+1,offset+slots do
            visited=visited+1
            if visited>2048 then return "scan_limit" end
            local item=tableValue(call(api.GetSpellBookItemInfo,slot,bank))
            if not item then return "item_unknown" end
            local kind=integer(item.itemType)
            if not kind then return "item_unknown" end
            if kind==spellType then
                local passive,offSpec=flag(item.isPassive),flag(item.isOffSpec)
                if passive==nil or offSpec==nil then return "item_unknown" end
                if not passive and not offSpec then
                    local id,base=integer(item.spellID),integer(item.actionID)
                    if not id or id==0 or not base then return "spell_unknown" end
                    local learned=flag(call(IsPlayerSpell,id))
                    if learned~=true and base~=id and flag(call(IsPlayerSpell,base))==true then learned=true end
                    if learned==nil then return "learned_unknown" end
                    if learned then snapshot.spells[id]={spellID=id,baseSpellID=base} end
                end
            end
        end
    end
    snapshot.complete=true
    return "ready"
end
function Catalog:Refresh()
    wipe(snapshot.spells)
    snapshot.revision=snapshot.revision+1; snapshot.complete=false
    snapshot.reason=scan()
    local events=RA:GetModule("EventHandler")
    if events then events:Fire("ROTAASSIST_SPELL_CATALOG_CHANGED",snapshot.revision) end
    return snapshot
end
function Catalog:GetSnapshot() return snapshot end
function Catalog:OnInitialize() wipe(snapshot.spells); snapshot.complete=false end
function Catalog:OnEnable()
    local events=RA:GetModule("EventHandler")
    if events then
        for _,name in ipairs({"SPELLS_CHANGED","PLAYER_ENTERING_WORLD","PLAYER_SPECIALIZATION_CHANGED",
            "TRAIT_CONFIG_UPDATED","PLAYER_TALENT_UPDATE"}) do
            events:Subscribe(name,"SpellCatalog",function() self:Refresh() end)
        end
    end
    self:Refresh()
end
function Catalog:OnDisable()
    local events=RA:GetModule("EventHandler")
    if events then events:UnsubscribeAll("SpellCatalog") end
    wipe(snapshot.spells); snapshot.complete=false; snapshot.reason="disabled"
end
