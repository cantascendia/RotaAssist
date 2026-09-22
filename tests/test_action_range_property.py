"""test: only native range or complete public radial proof establishes range."""
import subprocess
import sys
from pathlib import Path

import pytest
from hypothesis import given, settings, strategies as st

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from export_independent_policy import lua
from benchmark_havoc_encounters import verify_events, MOVEMENT, ADDS

LUA=r'C:\Program Files (x86)\Lua\5.1\lua.exe'
signals=st.sampled_from(['true','false','nil','secret'])


@given(signals,signals,signals,st.booleans(),st.booleans(),st.booleans())
@settings(max_examples=65,deadline=None)
def test_only_complete_positive_evidence_produces_a_witness(native,has_range,melee,valid,havoc,area):
    known_native=native if native in ('true','false') else 'nil'
    expected=known_native if valid else 'nil'
    if expected=='nil' and valid and havoc and area and has_range=='false' and melee=='true': expected='true'
    code='''local h=require("tests.helpers")
local RA,ns=h.loadAddon(); h.loadRegistry(ns)
local secret={}; issecretvalue=function(v) return rawequal(v,secret) end
IsPlayerSpell=function() return true end
C_Spell.GetOverrideSpell=function(id) return id end
C_Spell.SpellHasRange=function() return HAS_RANGE end
C_Spell.IsSpellInRange=function(id) if id==162794 then return MELEE end; return NATIVE end
UnitExists=function(u) return u=="target" and VALID end
UnitCanAttack=function() return true end; UnitIsDead=function() return false end
RA:RegisterModule("SpecDetector",{GetCurrentSpec=function() return {specID=SPEC} end})
assert(h.loadAddonFile("addon/Engine/TargetContext.lua","RotaAssist",ns))
local T=RA:GetModule("TargetContext"); T:OnInitialize(); T:OnEnable()
local value=T:GetActionRange(SPELL); io.write(tostring(value))
'''
    for key,value in [('HAS_RANGE',has_range),('MELEE',melee),('NATIVE',native),('VALID',lua(valid)),('SPEC','577' if havoc else '581'),('SPELL','258920' if area else '198013')]:
        code=code.replace(key,value)
    result=subprocess.run([LUA,'-e',code],cwd=ROOT,capture_output=True,text=True)
    assert result.returncode==0,result.stderr
    assert result.stdout==expected


def test_event_validation_requires_execution_not_just_a_profile_directive():
    with pytest.raises(ValueError,match='instantiated'):
        verify_events('raid_events='+MOVEMENT,[MOVEMENT])
    with pytest.raises(ValueError,match='execute'):
        verify_events("0.000 Creating raid event '"+MOVEMENT+"'.\n",[MOVEMENT])
    trace=("0.000 Creating raid event '"+MOVEMENT+"'.\n15.000 movement_distance (id=0) starts.\n"
           "0.000 Creating raid event '"+ADDS+"'.\n25.000 Enemy 'Fluffy_Pillow' summons 1 for 20.000s.\n")
    evidence=verify_events(trace,[MOVEMENT,ADDS])
    assert [row['firstStart'] for row in evidence]==[15,25]
    assert [row['observedStarts'] for row in evidence]==[1,1]
