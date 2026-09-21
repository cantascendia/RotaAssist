"""test: own policy serialization, shared evaluator behavior and cache provenance."""
import hashlib
import json
import operator
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest
from hypothesis import given, settings, strategies as st

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"scripts"))
from independent_policy import canonical, simc_lines
from export_independent_policy import export, lua
import search_independent_policy as search

POLICY=json.loads((ROOT/"research/independent-policy/candidate.json").read_text())
LUA=r"C:\Program Files (x86)\Lua\5.1\lua.exe"
OPS={">":operator.gt,">=":operator.ge,"<":operator.lt,"<=":operator.le,"==":operator.eq}


def test_checked_in_policy_is_exact_export():
    assert (ROOT/"addon/Data/IndependentPolicy.lua").read_text(encoding="utf-8")==export(POLICY)
    assert hashlib.sha256(canonical(POLICY)).hexdigest() in export(POLICY)


def test_simc_export_preserves_each_predicate_and_order():
    lines=simc_lines(POLICY)[2:]
    assert len(lines)==len(POLICY["rules"])
    for line,rule in zip(lines,POLICY["rules"]):
        assert line.split(",")[0]=="actions+=/"+rule["action"]
        for field,op,value in rule["conditions"]:
            assert f"({field}{op}{value})" in line
        if rule["form"]:
            assert "buff.metamorphosis."+("up" if rule["form"]=="meta" else "down") in line


FIELDS=sorted({c[0] for r in POLICY["rules"] for c in r["conditions"] if c[0]!="charges"}|{"buff.metamorphosis.up"})
IDS=sorted({r["spellID"] for r in POLICY["rules"]})
@settings(max_examples=40,deadline=None)
@given(st.lists(st.integers(0,120),min_size=len(FIELDS),max_size=len(FIELDS)),
       st.lists(st.booleans(),min_size=len(IDS),max_size=len(IDS)),st.integers(0,2))
def test_exported_lua_matches_full_information_reference(values,ready,charges):
    facts=dict(zip(FIELDS,values)); readiness=dict(zip(IDS,ready))
    expected=None
    for rule in POLICY["rules"]:
        if not readiness[rule["spellID"]]:
            continue
        if rule["form"] and ((facts["buff.metamorphosis.up"]>0)!=(rule["form"]=="meta")):
            continue
        if all(OPS[op](charges if field=="charges" else facts[field],value) for field,op,value in rule["conditions"]):
            expected=rule["spellID"]; break
    snapshot={"facts":facts,"known":{id:True for id in IDS},"ready":readiness,"charges":{id:charges for id in IDS}}
    script='''local h=require("tests.helpers")
local RA,ns=h.loadAddon()
assert(h.loadAddonFile("addon/Data/IndependentPolicy.lua","RotaAssist",ns))
assert(h.loadAddonFile("addon/Engine/IndependentDecision.lua","RotaAssist",ns))
local result=RA:GetModule("IndependentDecision"):Evaluate(RA.IndependentPolicy,SNAPSHOT)
io.write(tostring(result.spellID))
'''.replace("SNAPSHOT",lua(snapshot))
    result=subprocess.run([LUA,"-e",script],cwd=ROOT,capture_output=True,text=True)
    assert result.returncode==0,result.stderr
    assert result.stdout==("nil" if expected is None else str(expected))


@pytest.mark.parametrize("change",["raw","profile","summary","policy"])
def test_experiment_cache_rejects_tampering(tmp_path,monkeypatch,change):
    def launch(command,**kwargs):
        Path(next(x[6:] for x in command if x.startswith("json2="))).write_text("{}")
        return SimpleNamespace(returncode=0,stdout="",stderr="")
    monkeypatch.setattr(search.subprocess,"run",launch)
    monkeypatch.setattr(search,"parse_result",lambda *a:{"options":{"max_time":120,"fixed_time":True},
        "dps_mean":123,"dps_standard_error":2,"dps_sample_count":499,"warnings":[]})
    search.run(tmp_path/"simc",b"actions=auto_attack\n",None,tmp_path,1,120,500,20260924)
    report=next(tmp_path.glob("*.report.json"))
    if change=="raw": next(tmp_path.glob("*.raw.json")).write_text('{"changed":true}')
    elif change=="profile": next(tmp_path.glob("*.simc")).write_text("changed")
    else:
        data=json.loads(report.read_text()); data["dps" if change=="summary" else "policy"]=999
        report.write_text(json.dumps(data))
    with pytest.raises(ValueError,match="cached experiment"):
        search.run(tmp_path/"simc",b"actions=auto_attack\n",None,tmp_path,1,120,500,20260924)


def test_export_rejects_nonfinite_constants():
    with pytest.raises(ValueError,match="nonfinite"):
        lua(float("nan"))
