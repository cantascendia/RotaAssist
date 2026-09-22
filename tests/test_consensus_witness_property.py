"""test: generated counterexamples independently replay through the base evaluator."""
import subprocess
import sys
from pathlib import Path

from hypothesis import given, settings, strategies as st

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from export_independent_policy import lua


@given(st.lists(st.tuples(st.integers(1,3),st.sampled_from(['<','<=','>','>=','==']),
                         st.integers(0,100)),min_size=1,max_size=8),st.booleans())
@settings(max_examples=110,deadline=None)
def test_every_interval_witness_replays_to_its_claimed_action(rules,ready_unknown):
    policy={'schema':'rotaassist.independent-policy.v1','rules':[
        {'spellID':spell,'conditions':[['fury',op,threshold]]} for spell,op,threshold in rules]}
    code='''local h=require("tests.helpers")
local RA,ns=h.loadAddon()
for _,n in ipairs({"IndependentDecision","IndependentConsensus"}) do
    assert(h.loadAddonFile("addon/Engine/"..n..".lua","RotaAssist",ns))
end
local p=POLICY
local snapshot={facts={},bounds={fury={min=0,max=100}},known={[1]=true,[2]=true,[3]=true},
ready={[1]=READY,[2]=true,[3]=true}}
local r=RA:GetModule("IndependentConsensus"):Evaluate(p,snapshot)
assert(r.maximumDPSProven==false)
for _,w in ipairs(r.counterexamples) do
    local s={facts={},known={},ready={},charges={}}
    for i=1,w.count do
        local b=w.bounds[i]; local v
        if b.min==b.max then v=b.min
        elseif b.min==-math.huge and b.max==math.huge then v=0
        elseif b.min==-math.huge then v=b.max-1
        elseif b.max==math.huge then v=b.min+1
        else v=(b.min+b.max)/2 end
        assert(v>b.min or (v==b.min and not b.minOpen))
        assert(v<b.max or (v==b.max and not b.maxOpen))
        local id=b.key:match("^known:(%d+)$")
        if id then s.known[tonumber(id)]=v>=1
        else
            id=b.key:match("^ready:(%d+)$")
            if id then s.ready[tonumber(id)]=v>=1 else s.facts[b.key]=v end
        end
    end
    assert(s.facts.fury>=0 and s.facts.fury<=100)
    local actual=RA:GetModule("IndependentDecision"):Evaluate(p,s)
    assert((actual.spellID or 0)==w.action, "witness failed independent replay")
    assert(actual.status=="decided" or actual.status=="wait")
end
if r.status=="ambiguous" then assert(#r.counterexamples==2) end
'''.replace('POLICY',lua(policy)).replace('READY','nil' if ready_unknown else 'true')
    result=subprocess.run([r'C:\Program Files (x86)\Lua\5.1\lua.exe','-e',code],cwd=ROOT,capture_output=True,text=True)
    assert result.returncode==0,result.stdout+result.stderr
