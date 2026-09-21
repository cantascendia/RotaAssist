"""test: generated public usability constraints must contain the hidden truth."""
import subprocess
from hypothesis import given, settings, strategies as st
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
LUA=r"C:\Program Files (x86)\Lua\5.1\lua.exe"


@settings(max_examples=40,deadline=None)
@given(st.integers(0,200),st.lists(st.integers(1,180),min_size=1,max_size=15,unique=True))
def test_bounds_contain_resource_for_generated_costs(actual,costs):
    script=r'''
local h=require("tests.helpers")
local RA,ns=h.loadAddon()
assert(h.loadAddonFile("addon/Engine/ResourceEvidence.lua","RotaAssist",ns))
local costs={COSTS}
local actual=ACTUAL
local rules={}
for i=1,#costs do rules[i]={spellID=i} end
IsPlayerSpell=function() return true end
UnitPower=function() error("must not inspect hidden value") end
C_Spell.GetSpellPowerCost=function(id)
 return {{type=17,minCost=costs[id],cost=costs[id]+20,costPercent=0,costPerSec=0,requiredAuraID=0,hasRequiredAura=false}}
end
C_Spell.IsSpellUsable=function(id) return actual>=costs[id],actual<costs[id] end
local r=RA:GetModule("ResourceEvidence"):Observe(rules,17)
assert(not r.inconsistent)
assert(r.observations==#costs)
assert(actual>=r.min)
assert(not r.max or actual<r.max)
'''.replace("COSTS",",".join(map(str,costs))).replace("ACTUAL",str(actual))
    result=subprocess.run([LUA,"-e",script],cwd=ROOT,capture_output=True,text=True)
    assert result.returncode==0,result.stdout+result.stderr
