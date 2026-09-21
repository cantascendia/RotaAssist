-- Bounded, event-derived Demonsurge model, confirmed against public Meta state.
-- 施法事件推导恶魔涌动；读取时仍须公开变身光环确认，不伪装成光环观测。
local _,NS=...
local RA=NS.RA
local Tracker={}
RA:RegisterModule("HavocSurgeTracker",Tracker)
local values,expires,guids={}, {}, {}
local enabled,lastTime,buildGeneration,buildKey=false,nil,nil,nil
local guidIndex=0
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function number(v)
    if public(v) and type(v)=="number" and v==v and math.abs(v)<math.huge then return v end
end
local function clear() wipe(values); wipe(expires) end
local function clock()
    local ok,v=pcall(GetTime)
    local now=ok and number(v)
    if not now then clear(); return nil end
    if lastTime and now<lastTime then clear() end
    lastTime=now
    return now
end
local function talent(id)
    local character=RA:GetModule("CharacterState")
    local config=RA.Registry.HAVOC_SURGE
    local build=character and character:GetSnapshot()
    if not build or not build.talentsComplete or build.specID~=config.specID then clear(); return nil end
    if buildGeneration~=build.generation or buildKey~=build.talentKey then
        clear(); buildGeneration,buildKey=build.generation,build.talentKey
    end
    local rank=number(character:GetTalentRank(id))
    if rank and rank>=0 and rank%1==0 then return rank end
end
function Tracker:Reset()
    clear(); wipe(guids); guidIndex=0
    lastTime,buildGeneration,buildKey=nil,nil,nil
end
function Tracker:OnCast(unit,guid,spellID)
    if not enabled then return end
    if not public(unit) then clear(); return end
    if unit~="player" then return end
    local id=number(spellID)
    if not id or id<=0 or id%1~=0 or not public(guid) or type(guid)~="string" or guid=="" then clear(); return end
    for i=1,#guids do if guids[i]==guid then return end end
    guidIndex=guidIndex%32+1; guids[guidIndex]=guid
    local now=clock(); if not now then return end
    local c=RA.Registry.HAVOC_SURGE
    local selected=talent(c.talent)
    if not selected or selected==0 then clear(); return end
    if id==c.metamorphosis then
        for i=1,#c.facts do values[i]=1; expires[i]=now+c.manualMinimum end
    elseif id==c.eyeBeam or id==c.abyssalGaze then
        local demonic=talent(c.demonicTalent)
        if demonic==nil then clear(); return end
        if demonic==0 then return end
        -- Extend only still-valid knowledge; an expired history stays unknown.
        -- 只延长尚未失效的证据，不复活过期的强化记录。
        for i=1,#c.facts do
            if expires[i] and expires[i]>now then expires[i]=expires[i]+c.demonicMinimum end
        end
        for i=1,2 do values[i]=1; expires[i]=now+c.demonicMinimum end
    else
        local index=c.consumers[id]
        if index and expires[index] and expires[index]>now then values[index]=0 end
    end
end
function Tracker:Populate(facts)
    local c=RA.Registry.HAVOC_SURGE
    -- Callers reuse buffers; always erase our own prior contribution first.
    -- 调用方可复用缓冲区；先清除本模块上一次提供的值。
    for _,key in ipairs(c.facts) do facts[key]=nil end
    if not enabled then return 0,"disabled" end
    local now=clock(); if not now then return 0,"clock_unknown" end
    local selected=talent(c.talent)
    if selected==nil then clear(); return 0,"build_unknown" end
    if selected==0 then
        clear(); for _,key in ipairs(c.facts) do facts[key]=0 end
        return 0,"talent_absent"
    end
    local auras=RA:GetModule("PublicAuraFacts")
    local up=auras and auras:ReadPlayer(c.metaAura,now)
    if not public(up) or type(up)~="boolean" then return 0,"form_unknown" end
    if up==false then
        clear(); for _,key in ipairs(c.facts) do facts[key]=0 end
        return 0,"public_form_absent"
    end
    local count=0
    for i,key in ipairs(c.facts) do
        if expires[i] and expires[i]>now then facts[key]=values[i]; count=count+1
        else values[i],expires[i]=nil,nil end
    end
    return count,count>0 and "cast_model" or "history_unknown"
end
function Tracker:OnInitialize() self:Reset() end
function Tracker:OnEnable()
    self:Reset(); enabled=true
    local events=RA:GetModule("EventHandler")
    if not events then return end
    events:Subscribe("ROTAASSIST_SPELLCAST_SUCCEEDED","HavocSurgeTracker",function(_,unit,guid,id) self:OnCast(unit,guid,id) end)
    events:Subscribe("UNIT_AURA","HavocSurgeTracker",function(_,unit)
        if not public(unit) then clear(); return end
        if unit~="player" then return end
        local now=clock()
        local auras=RA:GetModule("PublicAuraFacts")
        local up=now and auras and auras:ReadPlayer(RA.Registry.HAVOC_SURGE.metaAura,now)
        -- A lost/hidden form transition must not carry charges into a new form.
        -- 变身被取消或变化不可读时，不能把旧强化带入下一次变身。
        if not public(up) or up~=true then clear() end
    end)
    for _,event in ipairs({"ROTAASSIST_CHARACTER_CHANGED","ROTAASSIST_SPEC_CHANGED","PLAYER_ENTERING_WORLD","PLAYER_DEAD"}) do
        events:Subscribe(event,"HavocSurgeTracker",function() self:Reset() end)
    end
end
function Tracker:OnDisable()
    enabled=false; self:Reset()
    local events=RA:GetModule("EventHandler")
    if events then events:UnsubscribeAll("HavocSurgeTracker") end
end
