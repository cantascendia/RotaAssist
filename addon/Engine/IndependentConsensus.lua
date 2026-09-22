-- Correlate unknown predicates by exploring feasible numeric intervals.
-- 将同一未知事实的条件关联起来；只有全部可行状态一致时才确认动作。
local _,NS=...
local RA=NS.RA
local Consensus={}
RA:RegisterModule("IndependentConsensus",Consensus)
local MAX_DOMAINS,MAX_PREDICATES,MAX_DEPTH=128,1216,128
local DEFAULT_BUDGET=2048
local domains,predicates,domainIndex,starts,counts,ids={},{},{},{},{},{}
local result={status="unavailable",candidates={},missing={},counterexamples={}}
local witnessPool={}
local candidateSet={}
local domainCount,predicateCount,ruleCount,nodes,budget=0,0,0,0,DEFAULT_BUDGET
local selected,diverged,exhausted,leaves=nil,false,false,0
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function number(v)
    if not public(v) then return nil end
    if type(v)=="boolean" then return v and 1 or 0 end
    if type(v)=="number" and v==v and math.abs(v)<math.huge then return v end
end
local function flag(v)
    if public(v) and type(v)=="boolean" then return v and 1 or 0 end
end
function Consensus:OnInitialize()
    for i=1,MAX_DOMAINS do domains[i]=domains[i] or {} end
    for i=1,MAX_PREDICATES do predicates[i]=predicates[i] or {} end
    for i=1,2 do
        witnessPool[i]=witnessPool[i] or {bounds={}}
        for j=1,MAX_DOMAINS do witnessPool[i].bounds[j]=witnessPool[i].bounds[j] or {} end
    end
end
local function domain(key,value,bound,isFlag)
    local index=domainIndex[key]
    if index then return index end
    domainCount=domainCount+1
    if domainCount>MAX_DOMAINS then return nil end
    index=domainCount; domainIndex[key]=index
    local d=domains[index]
    d.key=key
    if value~=nil then d.lo,d.hi=value,value
    else
        local lo,hi
        if public(bound) and type(bound)=="table" then lo,hi=number(bound.min),number(bound.max) end
        if lo and hi and lo>hi then lo,hi=nil,nil end
        d.lo,d.hi=lo or (isFlag and 0 or -math.huge),hi or (isFlag and 1 or math.huge)
    end
    d.loOpen,d.hiOpen=false,false
    return index
end
local function add(index,op,value)
    if not index then return false end
    predicateCount=predicateCount+1
    if predicateCount>MAX_PREDICATES then return false end
    local pred=predicates[predicateCount]
    pred.domain,pred.op,pred.value=index,op,value
    return true
end
local function compile(policy,snapshot)
    wipe(domainIndex)
    domainCount,predicateCount,ruleCount=0,0,#policy.rules
    for ri,rule in ipairs(policy.rules) do
        local id=rule.spellID
        starts[ri],ids[ri]=predicateCount+1,id
        if not add(domain("known:"..id,flag(snapshot.known and snapshot.known[id]),nil,true),">=",1)
           or not add(domain("ready:"..id,flag(snapshot.ready and snapshot.ready[id]),nil,true),">=",1) then return false end
        for _,condition in ipairs(rule.conditions) do
            local field,op,value=condition[1],condition[2],condition[3]
            local key,actual=field,nil
            if field=="charges" then
                key="charges:"..id; actual=number(snapshot.charges and snapshot.charges[id])
            else actual=number(snapshot.facts and snapshot.facts[field]) end
            if not add(domain(key,actual,snapshot.bounds and snapshot.bounds[field]),op,value) then return false end
        end
        if rule.form then
            local field="buff.metamorphosis.up"
            if not add(domain(field,number(snapshot.facts and snapshot.facts[field]),snapshot.bounds and snapshot.bounds[field]),
                       rule.form=="meta" and ">" or "<=",0) then return false end
        end
        counts[ri]=predicateCount-starts[ri]+1
    end
    return true
end
local function constrain(d,op,value)
    if op==">" or op==">=" then
        local open=op==">"
        if value>d.lo then d.lo,d.loOpen=value,open
        elseif value==d.lo then d.loOpen=d.loOpen or open end
    elseif op=="<" or op=="<=" then
        local open=op=="<"
        if value<d.hi then d.hi,d.hiOpen=value,open
        elseif value==d.hi then d.hiOpen=d.hiOpen or open end
    else -- Equality intersects both bounds / 等值与上下界同时求交。
        if value<d.lo or value>d.hi or (value==d.lo and d.loOpen) or (value==d.hi and d.hiOpen) then return false end
        d.lo,d.hi,d.loOpen,d.hiOpen=value,value,false,false
    end
    return d.lo<d.hi or (d.lo==d.hi and not d.loOpen and not d.hiOpen)
end
local inverse={[">"]="<=",[">="]="<",["<"]=">=",["<="]=">"}
local function witness(id)
    leaves=leaves+1
    if not candidateSet[id] then
        candidateSet[id]=true
        if id~=0 then result.candidates[#result.candidates+1]=id end
        -- At most two counterexamples suffice to show policy disagreement.
        -- 两个区间见证只证明策略分歧，不声称恢复了真实隐藏战况。
        local index=#result.counterexamples+1
        if index<=2 then
            local w=witnessPool[index]; w.action,w.count=id,domainCount
            for i=1,domainCount do
                local d,b=domains[i],w.bounds[i]
                b.key,b.min,b.max=d.key,d.lo,d.hi
                b.minOpen,b.maxOpen=d.loOpen,d.hiOpen
            end
            result.counterexamples[index]=w
        end
    end
    if selected==nil then selected=id elseif selected~=id then diverged=true end
end
local visit
visit=function(ri,pi,depth)
    if diverged or exhausted then return end
    nodes=nodes+1
    if nodes>budget or depth>MAX_DEPTH then exhausted=true; return end
    if ri>ruleCount then witness(0); return end -- Waiting is a real alternative / 等待也是可能结果。
    if pi>counts[ri] then witness(ids[ri]); return end
    local pred=predicates[starts[ri]+pi-1]
    local d=domains[pred.domain]
    local lo,hi,loOpen,hiOpen=d.lo,d.hi,d.loOpen,d.hiOpen
    if constrain(d,pred.op,pred.value) then visit(ri,pi+1,depth+1) end
    d.lo,d.hi,d.loOpen,d.hiOpen=lo,hi,loOpen,hiOpen
    if pred.op=="==" then
        if constrain(d,"<",pred.value) then visit(ri+1,1,depth+1) end
        d.lo,d.hi,d.loOpen,d.hiOpen=lo,hi,loOpen,hiOpen
        if constrain(d,">",pred.value) then visit(ri+1,1,depth+1) end
    elseif constrain(d,inverse[pred.op],pred.value) then visit(ri+1,1,depth+1) end
    d.lo,d.hi,d.loOpen,d.hiOpen=lo,hi,loOpen,hiOpen
end

-- Borrowed result; budget exhaustion always fails closed.
-- 复用结果；搜索预算耗尽不会把部分结果提升为确定推荐。
function Consensus:Evaluate(policy,snapshot,nodeBudget)
    wipe(result.counterexamples)
    result.policyInvariant,result.maximumDPSProven=false,false
    result.proofScope="supplied_policy_only"
    local evaluator=RA:GetModule("IndependentDecision")
    if not evaluator then
        wipe(result.candidates); wipe(result.missing)
        result.status,result.spellID,result.exhaustive="unavailable",nil,false
        result.nodes,result.leaves=0,0
        return result
    end
    local base=evaluator:Evaluate(policy,snapshot)
    wipe(result.candidates); wipe(result.missing); wipe(candidateSet)
    result.status,result.spellID,result.exhaustive=base.status,base.spellID,false
    result.nodes,result.leaves=0,0
    for _,key in ipairs(base.missing) do result.missing[#result.missing+1]=key end
    for _,id in ipairs(base.candidates) do result.candidates[#result.candidates+1]=id end
    if base.status~="ambiguous" then
        result.exhaustive=base.status=="decided" or base.status=="wait"
        result.policyInvariant=result.exhaustive
        return result
    end
    if not domains[1] then self:OnInitialize() end
    if not compile(policy,snapshot) then result.status="budget_exceeded"; return result end
    wipe(result.candidates)
    nodes,leaves,selected,diverged,exhausted=0,0,nil,false,false
    local requested=number(nodeBudget)
    budget=requested and math.min(DEFAULT_BUDGET,math.max(1,math.floor(requested))) or DEFAULT_BUDGET
    visit(1,1,0)
    result.nodes,result.leaves=nodes,leaves
    result.exhaustive=not exhausted and not diverged
    if exhausted then result.status="budget_exceeded"; wipe(result.counterexamples)
    elseif diverged then result.status="ambiguous"
    elseif selected==0 then result.status="wait"
    elseif selected~=nil then result.status="decided"; result.spellID=selected
    else result.status="unavailable" end
    result.policyInvariant=result.exhaustive and (result.status=="decided" or result.status=="wait")
    if not diverged then wipe(result.counterexamples) end
    return result
end
function Consensus:OnEnable() end
function Consensus:OnDisable()
    wipe(result.candidates); wipe(result.missing)
    wipe(result.counterexamples)
    result.policyInvariant,result.maximumDPSProven=false,false
    result.status,result.spellID,result.exhaustive="unavailable",nil,false
end
