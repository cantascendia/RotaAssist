"""test: generated temporal safety plus pinned trace replay through real Lua."""
import json
import subprocess
from pathlib import Path

from hypothesis import given, settings, strategies as st
from scripts.export_independent_policy import lua

ROOT=Path(__file__).resolve().parents[1]
LUA=r"C:\Program Files (x86)\Lua\5.1\lua.exe"


@given(st.integers(0,2),st.lists(st.integers(1,499),min_size=1,max_size=30))
@settings(max_examples=60,deadline=None)
def test_consumed_flags_cannot_rearm_without_a_trigger(index,deltas):
    # Observe only after consuming one action. Neither time nor unrelated casts
    # may turn it back on; at the conservative horizon the fact must be unknown.
    code='''local h=require("tests.helpers")
local RA,ns=h.loadAddon(); h.loadRegistry(ns)
local now=0; GetTime=function() return now end
RA:RegisterModule("CharacterState",{GetSnapshot=function() return {talentsComplete=true,specID=577} end,GetTalentRank=function() return 1 end})
RA:RegisterModule("PublicAuraFacts",{ReadPlayer=function() return true end})
assert(h.loadAddonFile("addon/Engine/HavocSurgeTracker.lua","RotaAssist",ns))
local tracker=RA:GetModule("HavocSurgeTracker"); tracker:OnInitialize(); tracker:OnEnable()
tracker:OnCast("player","meta",191427)
local index=INDEX; local spells={201427,210152,258920}
tracker:OnCast("player","consume",spells[index])
local facts={}; local count=0
for i,dt in ipairs(DELTAS) do
    now=now+dt/100; tracker:OnCast("player","other"..i,6603); tracker:Populate(facts)
    local value=facts[RA.Registry.HAVOC_SURGE.facts[index]]
    if now<20 then assert(value==0) else assert(value==nil) end
    count=count+1
end
tracker:OnDisable(); tracker:Populate(facts)
for _,key in ipairs(RA.Registry.HAVOC_SURGE.facts) do assert(facts[key]==nil) end
io.write(count)
'''.replace("INDEX",str(index+1)).replace("DELTAS",lua(deltas))
    run=subprocess.run([LUA,"-e",code],cwd=ROOT,capture_output=True,text=True)
    assert run.returncode==0,run.stdout+run.stderr
    assert int(run.stdout)==len(deltas)


def test_pinned_simulator_trace_fixtures(tmp_path):
    evidence=ROOT/"research/havoc-surge"
    rows=json.loads((evidence/"trace-1t-20261012.json").read_text())
    fixture=tmp_path/"trace.lua"; fixture.write_text("return "+lua(rows),encoding="utf-8")
    run=subprocess.run([LUA,"scripts/replay_havoc_surge.lua",str(fixture)],cwd=ROOT,capture_output=True,text=True)
    assert run.returncode==0,run.stdout+run.stderr
    assert "checked=247 unknown=218 samples=155" in run.stdout
