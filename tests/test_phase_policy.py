"""test: prefix preservation and explicit phase boundaries, without DPS claims."""
import copy
import json
import subprocess
import sys
from pathlib import Path

import pytest
from hypothesis import given, settings, strategies as st

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"scripts"))
from build_phase_policy import compose
from export_independent_policy import lua
from independent_policy import simc_lines


def policy(first,threshold):
    return {"schema":"rotaassist.independent-policy.v1","specID":577,"heroProfile":"fel_scarred","rules":[
        {"action":"first","spellID":first,"form":None,"conditions":[["fury",">=",threshold]]},
        {"action":"fallback","spellID":3-first,"form":None,"conditions":[]}]}


@given(st.integers(0,120),st.integers(0,120),st.integers(0,120))
@settings(max_examples=30,deadline=None)
def test_composed_lua_matches_each_source_on_both_sides_of_boundary(early_gate,late_gate,fury):
    early,late=policy(1,early_gate),policy(2,late_gate)
    combined=compose(early,late)
    before=1 if fury>=early_gate else 2
    after=2 if fury>=late_gate else 1
    code='''local h=require("tests.helpers")
local RA,ns=h.loadAddon()
assert(h.loadAddonFile("addon/Engine/IndependentDecision.lua","RotaAssist",ns))
assert(h.loadAddonFile("addon/Engine/IndependentConsensus.lua","RotaAssist",ns))
local C=RA:GetModule("IndependentConsensus")
local p=POLICY
for _,t in ipairs({0,119.999,120,300}) do
    local s={facts={time=t,fury=FURY},known={[1]=true,[2]=true},ready={[1]=true,[2]=true}}
    io.write(tostring(C:Evaluate(p,s).spellID)..",")
end
'''.replace("POLICY",lua(combined)).replace("FURY",str(fury))
    process=subprocess.run([r"C:\Program Files (x86)\Lua\5.1\lua.exe","-e",code],cwd=ROOT,capture_output=True,text=True)
    assert process.returncode==0,process.stderr
    assert process.stdout==f"{before},{before},{after},{after},"


def test_unknown_time_does_not_choose_a_phase_and_sources_are_immutable():
    early,late=policy(1,0),policy(2,0)
    old=copy.deepcopy((early,late)); combined=compose(early,late)
    assert (early,late)==old
    assert [r["conditions"][0] for r in combined["rules"]]==[["time","<",120]]*2+[["time",">=",120]]*2
    lines=simc_lines(combined)
    assert sum("(time<120)" in line for line in lines)==2
    assert sum("(time>=120)" in line for line in lines)==2
    code='''local h=require("tests.helpers")
local RA,ns=h.loadAddon()
assert(h.loadAddonFile("addon/Engine/IndependentDecision.lua","RotaAssist",ns))
assert(h.loadAddonFile("addon/Engine/IndependentConsensus.lua","RotaAssist",ns))
local r=RA:GetModule("IndependentConsensus"):Evaluate(POLICY,{facts={fury=50},known={[1]=true,[2]=true},ready={[1]=true,[2]=true}})
io.write(r.status..":"..tostring(r.spellID))
'''.replace("POLICY",lua(combined))
    process=subprocess.run([r"C:\Program Files (x86)\Lua\5.1\lua.exe","-e",code],cwd=ROOT,capture_output=True,text=True)
    assert process.returncode==0,process.stderr
    assert process.stdout=="ambiguous:nil"


def test_phase_composition_rejects_incompatible_context_or_excess_rules():
    early,late=policy(1,0),policy(2,0)
    for invalid in (0,-1,True,float("nan"),float("inf")):
        with pytest.raises(ValueError,match="positive finite"):
            compose(early,late,invalid)
    late["specID"]=581
    with pytest.raises(ValueError,match="context"):
        compose(early,late)
    late["specID"]=577; late["rules"]*=33
    with pytest.raises(ValueError,match="runtime limits"):
        compose(early,late)
