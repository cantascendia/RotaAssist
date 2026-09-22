"""test: generated complete snapshots and shipped Aldrachi policy provenance."""
import hashlib
import json
import operator
import subprocess
import sys
from pathlib import Path

import pytest
from hypothesis import given, settings, strategies as st

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from export_independent_policy import export_registered, lua
from independent_policy import canonical, simc_lines

POLICY=json.loads((ROOT/'research/aldrachi-policy/candidate.json').read_text())
IDS=sorted({r['spellID'] for r in POLICY['rules']})
FIELDS=sorted({c[0] for r in POLICY['rules'] for c in r['conditions']} - {'charges'})
OPS={'>':operator.gt,'>=':operator.ge,'<':operator.lt,'<=':operator.le,'==':operator.eq}
LUA=r'C:\Program Files (x86)\Lua\5.1\lua.exe'


@given(st.lists(st.integers(0,120),min_size=len(FIELDS),max_size=len(FIELDS)),
       st.lists(st.booleans(),min_size=len(IDS)*2,max_size=len(IDS)*2),
       st.integers(0,2),st.booleans())
@settings(max_examples=60,deadline=None)
def test_shipped_lua_matches_priority_oracle_for_complete_public_snapshots(values,flags,charges,meta):
    facts=dict(zip(FIELDS,values)); facts['buff.metamorphosis.up']=int(meta)
    known=dict(zip(IDS,flags[:len(IDS)])); ready=dict(zip(IDS,flags[len(IDS):]))
    snapshot={'facts':facts,'known':known,'ready':ready,'charges':{id:charges for id in IDS}}
    # Availability is supplied separately: this checks priority semantics, not DPS.
    expected=None
    for r in POLICY['rules']:
        if not known[r['spellID']] or not ready[r['spellID']]: continue
        if r['form'] and meta!=(r['form']=='meta'): continue
        if all(OPS[op](charges if field=='charges' else facts[field],value) for field,op,value in r['conditions']):
            expected=r['spellID']; break
    code='''local h=require("tests.helpers")
local RA,ns=h.loadAddon()
assert(h.loadAddonFile("addon/Data/IndependentAldrachi.lua","RotaAssist",ns))
assert(h.loadAddonFile("addon/Engine/IndependentDecision.lua","RotaAssist",ns))
local result=RA:GetModule("IndependentDecision"):Evaluate(RA.IndependentPolicies.aldrachi_reaver,SNAPSHOT)
io.write(result.status..":"..tostring(result.spellID))
'''.replace('SNAPSHOT',lua(snapshot))
    result=subprocess.run([LUA,'-e',code],cwd=ROOT,capture_output=True,text=True)
    assert result.returncode==0,result.stderr
    assert result.stdout==('wait:nil' if expected is None else f'decided:{expected}')


def test_shipped_policy_matches_frozen_simulation_candidate():
    assert (ROOT/'addon/Data/IndependentAldrachi.lua').read_text(encoding='utf-8')==export_registered(POLICY)
    holdout=json.loads((ROOT/'research/aldrachi-policy/holdout.json').read_text())
    assert holdout['policySha256']==hashlib.sha256(canonical(POLICY)).hexdigest()
    assert not holdout['automaticReplacementQualified']
    for row in holdout['scenarios']:
        assert row['candidate']['seed']==20261027
        assert row['reference']['seed']==20261027
        assert row['deltaMinusThreeSESum']<=row['delta']<=row['deltaPlusThreeSESum']
    lines=simc_lines(POLICY)[2:]
    assert len(lines)==len(POLICY['rules'])
    for line,rule in zip(lines,POLICY['rules']):
        assert line.split(',')[0]=='actions+=/'+rule['action']
        for field,op,value in rule['conditions']:
            assert f'({field}{op}{value})' in line
        if rule['form']:
            assert ('buff.metamorphosis.up' if rule['form']=='meta' else 'buff.metamorphosis.down') in line


@pytest.mark.parametrize('hero',['','x\n','../aldrachi','英雄','x"'])
def test_registered_export_rejects_invalid_hero_identity(hero):
    with pytest.raises(ValueError,match='hero profile'):
        export_registered({**POLICY,'heroProfile':hero})
