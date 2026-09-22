"""test: population thresholds, source preservation and adaptive export semantics."""
import copy
import json
import subprocess
import sys
from pathlib import Path

import pytest
from hypothesis import given,settings,strategies as st

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from export_independent_policy import export_adaptive,lua
from retune_encounter_policy import variants,rank
from independent_policy import canonical


def test_search_changes_only_an_explicit_population_gated_area_rule():
    original=json.loads((ROOT/'research/independent-policy/candidate.json').read_text())
    saved=canonical(original); candidates=list(variants(original))
    assert len(candidates)==16 and candidates[0]==original
    for policy in candidates[1:]:
        added=policy['rules'][policy['parameters']['index']]
        assert added['spellID']==258920
        assert added['conditions']==[['active_enemies','>=',policy['parameters']['threshold']]]
        remaining=copy.deepcopy(policy['rules']); remaining.pop(policy['parameters']['index'])
        assert remaining==original['rules']
    candidates[1]['rules'][0]['spellID']=1
    assert canonical(original)==saved and candidates[0]==original


def test_selection_cannot_trade_away_single_target_to_hide_the_worst_encounter():
    def rows(*values): return [{'dps':v} for v in values]
    previous=rows(100,80,80); reference=rows(100,100,100)
    assert rank(rows(98,110,110),reference,previous)[0]==-1
    assert rank(rows(99,90,85),reference,previous)==(.85,[.99,.9,.85])


@given(st.integers(1,5),st.integers(0,8),st.booleans(),st.booleans())
@settings(max_examples=60,deadline=None)
def test_exported_policy_consensus_agrees_with_all_enemy_populations(threshold,count,exact,ready):
    policy={'schema':'rotaassist.independent-policy.v1','heroProfile':'fel_scarred','specID':577,'rules':[
        {'spellID':258920,'conditions':[['active_enemies','>=',threshold]]},
        {'spellID':162794,'conditions':[]}]}
    snapshot={'facts':{'active_enemies':count} if exact else {},'bounds':{} if exact else {'active_enemies':{'min':count}},
              'known':{258920:True,162794:True},'ready':{258920:ready,162794:True}}
    # One value beyond every threshold represents the unbounded upper interval.
    outcomes={258920 if ready and n>=threshold else 162794 for n in ([count] if exact else range(count,max(count,threshold)+2))}
    program='''local h=require("tests.helpers")
local RA,ns=h.loadAddon()
assert(loadstring(EXPORT))("RotaAssist",ns)
assert(h.loadAddonFile("addon/Engine/IndependentDecision.lua","RotaAssist",ns))
assert(h.loadAddonFile("addon/Engine/IndependentConsensus.lua","RotaAssist",ns))
local r=RA:GetModule("IndependentConsensus"):Evaluate(RA.IndependentAdaptivePolicies.fel_scarred,SNAPSHOT)
io.write(r.status..":"..tostring(r.spellID))
'''
    # Export contains bilingual comments; a temporary UTF-8 file avoids quoting it.
    import tempfile
    with tempfile.TemporaryDirectory(prefix='adaptive-export-') as directory:
        file=Path(directory)/'policy.lua'; file.write_text(export_adaptive([policy]),encoding='utf-8')
        program=program.replace('assert(loadstring(EXPORT))("RotaAssist",ns)',f'assert(loadfile({lua(str(file).replace(chr(92),"/"))}))("RotaAssist",ns)')
        program=program.replace('SNAPSHOT',lua(snapshot))
        result=subprocess.run([r'C:\Program Files (x86)\Lua\5.1\lua.exe','-e',program],cwd=ROOT,capture_output=True,text=True)
    assert result.returncode==0,result.stderr
    expected='ambiguous:nil' if len(outcomes)>1 else f'decided:{next(iter(outcomes))}'
    assert result.stdout==expected


def test_export_rejects_duplicate_hero_overwrites():
    policy={'heroProfile':'fel_scarred','rules':[]}
    with pytest.raises(ValueError,match='duplicate'):
        export_adaptive([policy,policy])


@given(st.floats(min_value=0,max_value=30,allow_nan=False,allow_infinity=False),st.booleans())
@settings(max_examples=45,deadline=None)
def test_enhanced_beam_uses_the_selected_demonic_duration(remaining,selected):
    code='''local h=require("tests.helpers")
local RA,ns=h.loadAddon(); h.loadRegistry(ns)
RA:RegisterModule("CharacterState",{GetSnapshot=function() return {talentsComplete=true,specID=577} end,
GetTalentRank=function() return RANK end})
assert(h.loadAddonFile("addon/Engine/TalentTransitions.lua","RotaAssist",ns))
local s={cooldowns={},inMetaKnown=true,inMeta=true,metaRemains=REMAINING}
assert(RA:GetModule("TalentTransitions"):Apply(s,577,452497))
io.write(tostring(s.metaRemains))
'''.replace('RANK','1' if selected else '0').replace('REMAINING',repr(remaining))
    result=subprocess.run([r'C:\Program Files (x86)\Lua\5.1\lua.exe','-e',code],cwd=ROOT,capture_output=True,text=True)
    assert result.returncode==0,result.stderr
    assert float(result.stdout)==pytest.approx(remaining+(5 if selected else 0))
