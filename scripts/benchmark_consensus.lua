-- Synthetic proof coverage and bounded-cost diagnostic, not live combat coverage.
-- 合成状态的证明覆盖率与耗时诊断，不代表游戏内覆盖率或帧耗时。
local h=require("tests.helpers")
local RA,ns=h.loadAddon()
for _,file in ipairs({"Data/IndependentPolicy.lua","Engine/IndependentDecision.lua","Engine/IndependentConsensus.lua"}) do
    assert(h.loadAddonFile("addon/"..file,"RotaAssist",ns))
end
local D,C=RA:GetModule("IndependentDecision"),RA:GetModule("IndependentConsensus")
C:OnInitialize()
local policy=RA.IndependentPolicy
local seed=2709
local function rand(n) seed=(seed*16807)%2147483647; return seed%n end
local fields,seen={},{}
for _,r in ipairs(policy.rules) do
    for _,c in ipairs(r.conditions) do
        if c[1]~="charges" and not seen[c[1]] then seen[c[1]]=true; fields[#fields+1]=c[1] end
    end
end
fields[#fields+1]="buff.metamorphosis.up"
local before,after,extra,budgets,maxNodes=0,0,0,0,0
local total=2000
local samples={}
for i=1,total do
    local s={facts={},known={},ready={},charges={},bounds={}}
    for _,field in ipairs(fields) do
        if rand(3)>0 then
            s.facts[field]=(field=="fury" and rand(121)) or (field:find("cooldown",1,true) and rand(31)) or rand(2)
        end
    end
    for _,r in ipairs(policy.rules) do
        local id=r.spellID
        s.known[id]=true
        if rand(4)>0 then s.ready[id]=rand(3)>0 end
        if rand(3)>0 then s.charges[id]=rand(3) end
    end
    samples[i]=s
    local old=D:Evaluate(policy,s).status
    local result=C:Evaluate(policy,s)
    if old=="decided" then before=before+1 end
    if result.status=="decided" then
        after=after+1
        if old~="decided" then extra=extra+1 end
    end
    if result.status=="budget_exceeded" then budgets=budgets+1 end
    maxNodes=math.max(maxNodes,result.nodes)
end
local started=os.clock()
for _=1,5 do for _,s in ipairs(samples) do C:Evaluate(policy,s) end end
local meanMs=(os.clock()-started)*1000/(total*5)
local rules={}
for i=1,16 do rules[i]={spellID=2,conditions={{"fact"..i,">=",0},{"fact"..i,"<",0}}} end
rules[#rules+1]={spellID=1,conditions={}}
local stress={schema="rotaassist.independent-policy.v1",rules=rules}
local snapshot={known={[1]=true,[2]=true},ready={[1]=true,[2]=true},facts={}}
started=os.clock()
local stressStatus,stressNodes
for _=1,200 do local r=C:Evaluate(stress,snapshot); stressStatus,stressNodes=r.status,r.nodes end
local stressMs=(os.clock()-started)*1000/200
io.write(string.format('{"synthetic":true,"seed":2709,"samples":%d,"beforeDecided":%d,"afterDecided":%d,'..
    '"additionalDecisions":%d,"budgetExhaustions":%d,"maxNodes":%d,"meanMilliseconds":%.6f,'..
    '"stressStatus":"%s","stressNodes":%d,"stressMeanMilliseconds":%.6f,"liveCoverageMeasured":false}\n',
    total,before,after,extra,budgets,maxNodes,meanMs,stressStatus,stressNodes,stressMs))
