-- Resource inequalities from public native usability and minimum-cost facts.
-- 公开的可用性与最低费用只证明资源范围，不还原或读取秘密资源数值。
local _, NS = ...
local RA = NS.RA
local Evidence = {}
RA:RegisterModule("ResourceEvidence", Evidence)
local result = {source="public_usability_bounds", min=0, max=nil, observations=0}
local seen = {}
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function number(v)
    if public(v) and type(v)=="number" and v==v and math.abs(v)<math.huge then return v end
end
local function boolean(v)
    if public(v) and type(v)=="boolean" then return v end
end

local function minimumCost(spellID, powerType)
    if not C_Spell or type(C_Spell.GetSpellPowerCost)~="function" then return nil end
    local ok,costs=pcall(C_Spell.GetSpellPowerCost,spellID)
    if not ok or not public(costs) or type(costs)~="table" then return nil end
    local count, minimum=0,nil
    for _,cost in ipairs(costs) do
        if not public(cost) or type(cost)~="table" then return nil end
        local required=number(cost.requiredAuraID)
        if required==nil then return nil end
        local applies=required==0
        if not applies then
            applies=boolean(cost.hasRequiredAura)
            if applies==nil then return nil end
        end
        if applies then
            local kind=number(cost.type)
            local percent,perSecond=number(cost.costPercent),number(cost.costPerSec)
            local value,total=number(cost.minCost),number(cost.cost)
            if kind~=powerType or percent~=0 or perSecond~=0 or value==nil or value<=0
               or total==nil or total<value then return nil end
            count=count+1
            minimum=value
        end
    end
    if count==1 then return minimum end
end

-- Borrowed result, rebuilt on each call. No state is propagated through casts.
-- 返回复用缓冲区；每次重建，不把旧推断延续到施法后的状态。
function Evidence:Observe(rules, powerType)
    result.min,result.max,result.observations,result.inconsistent=0,nil,0,false
    wipe(seen)
    if type(rules)~="table" or not C_Spell or type(C_Spell.IsSpellUsable)~="function"
       or type(IsPlayerSpell)~="function" then return result end
    for _,rule in ipairs(rules) do
        local id=number(rule.spellID)
        if id and id>0 and not seen[id] then
            seen[id]=true
            local learnedOK,learned=pcall(IsPlayerSpell,id)
            if learnedOK and boolean(learned)==true then
                local cost=minimumCost(id,powerType)
                if cost then
                    local ok,usable,insufficient=pcall(C_Spell.IsSpellUsable,id)
                    if ok then
                        usable,insufficient=boolean(usable),boolean(insufficient)
                        if usable==true and insufficient==false then
                            result.min=math.max(result.min,cost)
                            result.observations=result.observations+1
                        elseif usable==false and insufficient==true then
                            result.max=math.min(result.max or math.huge,cost)
                            result.observations=result.observations+1
                        elseif usable==true and insufficient==true then
                            result.inconsistent=true
                        end
                    end
                end
            end
        end
    end
    -- Upper evidence is strict (< cost). Equality of endpoints is inconsistent.
    -- 上界证据实际是严格小于费用；上下界相等也表示冲突。
    if result.max and result.min>=result.max then result.inconsistent=true end
    if result.inconsistent then result.min,result.max,result.observations=0,nil,0 end
    return result
end
function Evidence:OnInitialize() end
function Evidence:OnEnable() end
function Evidence:OnDisable()
    result.min,result.max,result.observations,result.inconsistent=0,nil,0,false
    wipe(seen)
end
