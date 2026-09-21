"""test: independent exhaustive oracle for the symbolic Lua consensus solver."""
import copy
import itertools
import operator
import subprocess
import sys
from pathlib import Path

import pytest
from hypothesis import given, settings, strategies as st

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"scripts"))
from export_independent_policy import lua
from refine_independent_policy import neighbors, score
from validate_refined_policy import difference

LUA=r"C:\Program Files (x86)\Lua\5.1\lua.exe"
OPS={">":operator.gt,">=":operator.ge,"<":operator.lt,"<=":operator.le,"==":operator.eq}
condition=st.tuples(st.sampled_from(["a","b"]),st.sampled_from(list(OPS)),st.integers(0,2))
rules=st.lists(st.tuples(st.integers(1,2),st.lists(condition,max_size=3)),min_size=1,max_size=7)


@given(rules,st.lists(st.one_of(st.none(),st.booleans()),min_size=2,max_size=2),
       st.one_of(st.none(),st.integers(0,2)))
@settings(max_examples=65,deadline=None)
def test_every_symbolic_decision_agrees_with_all_exhaustive_worlds(generated,ready,a):
    policy={"schema":"rotaassist.independent-policy.v1","rules":[
        {"spellID":id,"conditions":[list(c) for c in conditions]} for id,conditions in generated]}
    snapshot={"facts":{} if a is None else {"a":a},"known":{1:True,2:True},
              "ready":{i+1:v for i,v in enumerate(ready) if v is not None}}
    # All threshold endpoints and open cells for constants in {0,1,2}.
    values=[-1,0,0.5,1,1.5,2,3]
    outcomes=set()
    for av,bv,r1,r2 in itertools.product(values if a is None else [a],values,
            [False,True] if ready[0] is None else [ready[0]],
            [False,True] if ready[1] is None else [ready[1]]):
        facts={"a":av,"b":bv}; readiness={1:r1,2:r2}; chosen=None
        for id,conditions in generated:
            if readiness[id] and all(OPS[op](facts[field],value) for field,op,value in conditions):
                chosen=id; break
        outcomes.add(chosen)
    code='''local h=require("tests.helpers")
local RA,ns=h.loadAddon()
assert(h.loadAddonFile("addon/Engine/IndependentDecision.lua","RotaAssist",ns))
assert(h.loadAddonFile("addon/Engine/IndependentConsensus.lua","RotaAssist",ns))
local result=RA:GetModule("IndependentConsensus"):Evaluate(POLICY,SNAPSHOT)
io.write(result.status..":"..tostring(result.spellID))
'''.replace("POLICY",lua(policy)).replace("SNAPSHOT",lua(snapshot))
    process=subprocess.run([LUA,"-e",code],cwd=ROOT,capture_output=True,text=True)
    assert process.returncode==0,process.stderr
    status,spell=process.stdout.split(":")
    if status=="budget_exceeded":
        assert spell=="nil"
    elif outcomes=={None}:
        assert status=="wait" and spell=="nil"
    elif len(outcomes)==1:
        assert status=="decided" and int(spell)==next(iter(outcomes))
    else:
        assert status=="ambiguous" and spell=="nil"


def test_search_keeps_input_and_existing_action_semantics():
    policy={"schema":"rotaassist.independent-policy.v1","rules":[
        {"action":action,"spellID":i+1,"cost":0,"form":None,"conditions":conditions}
        for i,(action,conditions) in enumerate([
            ("felblade",[["fury","<=",40]]),("vengeful_retreat",[["cooldown.eye_beam.remains","<",2]]),
            ("immolation_aura",[]),("eye_beam",[]),("the_hunt",[])])]}
    frozen=copy.deepcopy(policy)
    candidates=list(neighbors(policy))
    assert policy==frozen
    assert candidates
    identities={(r["action"],r["spellID"],r["cost"],r["form"]) for r in policy["rules"]}
    for candidate in candidates:
        assert all((r["action"],r["spellID"],r["cost"],r["form"]) in identities for r in candidate["rules"])
    assert any(any(c[0]=="active_enemies" for r in p["rules"] for c in r["conditions"]) for p in candidates)


def test_discovery_uses_worst_scenario_and_rejects_mismatched_pairs():
    def row(targets,dps): return {"targets":targets,"duration":300,"dps":dps}
    own=[row(1,120),row(5,90)]; ref=[row(1,100),row(5,100)]
    assert score(own,ref)==(0.9,[1.2,0.9])
    with pytest.raises(ValueError,match="identity"):
        score(own,list(reversed(ref)))
    with pytest.raises(ValueError,match="count"):
        score(own,ref[:1])


def test_holdout_uncertainty_does_not_assume_seed_stream_independence():
    result=difference({"dps":120,"standardError":3},{"dps":100,"standardError":4})
    assert result=={"ratio":1.2,"delta":20,"deltaMinusThreeSESum":-1,"deltaPlusThreeSESum":41}
