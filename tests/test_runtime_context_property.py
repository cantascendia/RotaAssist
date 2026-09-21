"""test: generated per-spell targetable lower bounds do not count aliases twice."""
import subprocess
from pathlib import Path
from hypothesis import given, settings, strategies as st
from scripts.export_independent_policy import lua

ROOT=Path(__file__).resolve().parents[1]


@given(st.lists(st.tuples(st.integers(1,8), st.booleans(), st.booleans()), max_size=20))
@settings(max_examples=50, deadline=None)
def test_distinct_engaged_in_range_enemies(rows):
    # Repeated GUIDs must describe the same unit; use one stable state per GUID.
    states={identity:(near,combat) for identity,near,combat in rows}
    normalized=[[identity,*states[identity]] for identity,_,_ in rows]
    expected=1+len({identity for identity,(near,combat) in states.items() if near and combat})
    code='''local h=require("tests.helpers")
local RA,ns=h.loadAddon(); h.loadRegistry(ns)
local rows=ROWS
local units={target={id="target",near=true,combat=false}}
for index,r in ipairs(rows) do units["nameplate"..index]={id=tostring(r[1]),near=r[2],combat=r[3]} end
UnitExists=function(u) return units[u]~=nil end
UnitCanAttack=function() return true end; UnitIsDead=function() return false end
UnitAffectingCombat=function(u) return units[u].combat end
UnitGUID=function(u) return units[u] and units[u].id end
UnitIsUnit=function(a,b) return units[a].id==units[b].id end
IsPlayerSpell=function() return true end
C_Spell.IsSpellHarmful=function() return true end
C_Spell.IsSpellInRange=function(_,u) return units[u].near end
RA:RegisterModule("SpecDetector",{GetCurrentSpec=function() return {specID=63} end})
RA:RegisterModule("SpellCatalog",{GetSnapshot=function() return {spells={[501]={}}} end})
assert(h.loadAddonFile("addon/Engine/TargetContext.lua","RotaAssist",ns))
local C=RA:GetModule("TargetContext"); C:OnInitialize(); C:OnEnable()
local result=C:GetSpellTargets(501)
assert(result.complete==false); io.write(result.min)
'''.replace("ROWS",lua(normalized))
    process=subprocess.run([r"C:\Program Files (x86)\Lua\5.1\lua.exe","-e",code],cwd=ROOT,capture_output=True,text=True)
    assert process.returncode==0,process.stdout+process.stderr
    assert int(process.stdout)==expected
