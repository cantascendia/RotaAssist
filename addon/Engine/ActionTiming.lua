-- Event-proven GCD readiness inside a bounded public queue window.
-- 仅用冷却事件公开证据，在有限队列窗口内规划下一次动作。
local _,NS=...
local RA=NS.RA
local Timing={}
RA:RegisterModule("ActionTiming",Timing)
local starts,durations,seen,eventFacts={},{},{},{}
local enabled=false
local gcdStart,gcdDuration
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function number(v)
    if public(v) and type(v)=="number" and v==v and math.abs(v)<math.huge then return v end
end
local function clock(id,facts)
    local ok,remaining,_,start,duration=pcall(RA.GetSpellCooldownSafe,RA,id,facts)
    if ok then return number(remaining),number(start),number(duration) end
end
local function chargeAvailable(id)
    if not C_Spell or type(C_Spell.GetSpellCharges)~="function" then return false end
    local ok,info=pcall(C_Spell.GetSpellCharges,id)
    if not ok or not public(info) then return false end
    if info==nil then return true end -- native non-charge spell / 原生非充能技能
    if type(info)~="table" then return false end
    local maximum,current=number(info.maxCharges),number(info.currentCharges)
    return maximum~=nil and current~=nil and maximum>=1 and maximum%1==0
        and current>=1 and current<=maximum and current%1==0
end
function Timing:Reset()
    wipe(starts); wipe(durations); wipe(seen)
    gcdStart,gcdDuration=nil,nil
end
local function capturePolicy(policy,spellID,baseSpellID)
    if type(policy)~="table" or type(policy.rules)~="table" then return end
    for index,rule in ipairs(policy.rules) do
        if index>64 then break end
        local id=number(rule.spellID)
        if id and id>0 and id%1==0 and not seen[id]
           and (spellID==nil or id==spellID or id==baseSpellID) then
            seen[id]=true
            wipe(eventFacts)
            local remaining,start,duration=clock(id,eventFacts)
            if eventFacts.isOnGCD==true and eventFacts.isEnabled==true
               and remaining and remaining>0 and start==gcdStart and duration==gcdDuration
               and chargeAvailable(id) then
                starts[id],durations[id]=start,duration
            end
        end
    end
end
function Timing:Capture(spellID,baseSpellID)
    self:Reset()
    if not public(spellID) or not public(baseSpellID) then return end
    if spellID~=nil and not number(spellID) then return end
    local config=RA.Registry and RA.Registry.ACTION_TIMING
    if not enabled or not config then return end
    local remaining,start,duration=clock(config.gcdSpellID)
    if not remaining or remaining<=0 or not start or not duration or duration<=0 then return end
    gcdStart,gcdDuration=start,duration
    capturePolicy(RA.IndependentPolicy,spellID,baseSpellID)
    for _,policy in pairs(RA.IndependentPolicies or {}) do capturePolicy(policy,spellID,baseSpellID) end
    for _,policy in pairs(RA.IndependentAdaptivePolicies or {}) do capturePolicy(policy,spellID,baseSpellID) end
end
function Timing:GetQueueDelay()
    local config=RA.Registry and RA.Registry.ACTION_TIMING
    if not enabled or not config or not gcdStart or next(starts)==nil then return nil end
    local reader=(C_CVar and C_CVar.GetCVar) or GetCVar
    if type(reader)~="function" then return nil end
    local ok,value=pcall(reader,"SpellQueueWindow")
    if not ok or not public(value) or (type(value)~="string" and type(value)~="number") then return nil end
    local window=number(tonumber(value))
    if not window or window<=0 then return nil end
    window=math.min(window/1000,config.maxQueueWindow)
    local remaining,start,duration=clock(config.gcdSpellID)
    if remaining and remaining>0 and remaining<=window
       and start==gcdStart and duration==gcdDuration then return remaining end
end
function Timing:GetDelay(id)
    id=number(id)
    if not id or not starts[id] then return nil end
    local delay=self:GetQueueDelay()
    if not delay then return nil end
    local remaining,start,duration=clock(id)
    if remaining and remaining>0 and start==starts[id] and duration==durations[id]
       and chargeAvailable(id) then return delay end
end
function Timing:OnInitialize() self:Reset() end
function Timing:OnEnable()
    enabled=true; self:Reset()
    local events=RA:GetModule("EventHandler")
    if not events then return end
    events:Subscribe("SPELL_UPDATE_COOLDOWN","ActionTiming",function(_,id,base) self:Capture(id,base) end)
    for _,event in ipairs({"SPELL_UPDATE_CHARGES","ROTAASSIST_CHARACTER_CHANGED","ROTAASSIST_SPEC_CHANGED",
        "TRAIT_CONFIG_UPDATED","SPELLS_CHANGED","PLAYER_ENTERING_WORLD","PLAYER_DEAD"}) do
        events:Subscribe(event,"ActionTiming",function() self:Reset() end)
    end
    for _,event in ipairs({"UNIT_SPELLCAST_START","ROTAASSIST_SPELLCAST_SUCCEEDED"}) do
        events:Subscribe(event,"ActionTiming",function(_,unit)
            if not public(unit) or unit=="player" then self:Reset() end
        end)
    end
end
function Timing:OnDisable()
    enabled=false; self:Reset()
    local events=RA:GetModule("EventHandler")
    if events then events:UnsubscribeAll("ActionTiming") end
end
