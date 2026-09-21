-- Measure which independent policy facts are publicly observable this frame.
-- 检验当前帧独立决策所需的公开事实；未验证策略只输出诊断，不替换主推荐。
local _, NS = ...
local RA = NS.RA
local Observer = {}
RA:RegisterModule("IndependentObserver", Observer)
local sample = {facts={},known={},ready={},charges={},bounds={}}
local enemyBounds, seen = {}, {}
local status = {status="unavailable", mode="observation_only"}
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function finite(v)
    if public(v) and type(v)=="number" and v==v and math.abs(v)<math.huge then return v end
end
local function boolean(fn, ...)
    if type(fn)~="function" then return nil end
    local ok,value=pcall(fn,...)
    if ok and public(value) and type(value)=="boolean" then return value end
end
local function cooldown(id)
    local ok,value=pcall(RA.GetSpellCooldownSafe,RA,id)
    if ok then return finite(value) end
end
function Observer:Reset()
    wipe(status)
    status.status="unavailable"
    status.mode="observation_only"
end
function Observer:GetStatus() return status end
function Observer:Observe(state)
    self:Reset()
    local policy=RA.IndependentPolicy
    local evaluator=RA:GetModule("IndependentDecision")
    local specModule=RA:GetModule("SpecDetector")
    local spec=specModule and specModule:GetCurrentSpec()
    local apl=RA:GetModule("APLEngine")
    if not policy or not evaluator or not spec or spec.specID~=policy.specID
       or not apl or not apl.GetProfileName or apl:GetProfileName()~=policy.heroProfile then return status end
    if not state or state.targetValid~=true then status.status="target_unknown"; return status end
    for _,values in pairs(sample) do wipe(values) end
    wipe(seen)
    if state.resourceKnown==true then sample.facts.fury=finite(state.resource) end
    if state.inMetaKnown==true and public(state.inMeta) and type(state.inMeta)=="boolean" then
        sample.facts["buff.metamorphosis.up"]=state.inMeta
    end
    if state.windowUnknown and state.windowUnknown.essence_break~=true then
        local window=state.windows and state.windows.essence_break
        if public(window) and type(window)=="boolean" then sample.facts["debuff.essence_break.up"]=window end
    end
    local count=finite(state.targetCount)
    if count and count>=0 then
        -- A range lower bound can prove >= N, but cannot prove exact population.
        -- 范围内数量下界可证明至少 N 个，不能证明准确总数。
        if state.targetCountKnown==true then sample.facts.active_enemies=count
        else enemyBounds.min=count; enemyBounds.max=nil; sample.bounds.active_enemies=enemyBounds end
    end
    for _,rule in ipairs(policy.rules) do
        local id=rule.spellID
        if not seen[id] then
            seen[id]=true
            sample.known[id]=boolean(IsPlayerSpell,id)
            sample.charges[id]=finite(state.charges and state.charges[id])
            local remaining=cooldown(id)
            if rule.action then sample.facts["cooldown."..rule.action..".remains"]=remaining end
            local usable=boolean(C_Spell and C_Spell.IsSpellUsable,id)
            local inRange=state.spellRange and state.spellRange[id]
            if not public(inRange) or type(inRange)~="boolean" then inRange=nil end
            if usable==false or inRange==false or (remaining and remaining>0)
               or (state.softBlocked and state.softBlocked[id]) then sample.ready[id]=false
            elseif usable==true and remaining==0 and inRange==true then sample.ready[id]=true end
        end
    end
    -- SimC virtual Demonsurge flags are deliberately absent. Missing is unknown.
    -- SimC 内部强化消耗标志没有伪造对应光环；缺失仍然保持未知。
    local evaluated=evaluator:Evaluate(policy,sample)
    status.status=evaluated.status
    status.spellID=evaluated.spellID
    status.candidates=evaluated.candidates
    status.missing=evaluated.missing
    status.policySha256=policy.policySha256
    status.performanceQualified=false
    return status
end
function Observer:OnInitialize() self:Reset() end
function Observer:OnEnable() self:Reset() end
function Observer:OnDisable() self:Reset() end
