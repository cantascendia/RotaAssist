"""test: public clock evidence and future surge knowledge never exceed proof."""
import subprocess
from pathlib import Path

from hypothesis import given, settings, strategies as st

ROOT=Path(__file__).resolve().parents[1]
LUA=r'C:\Program Files (x86)\Lua\5.1\lua.exe'


def run(code):
    result=subprocess.run([LUA,'-e',code],cwd=ROOT,capture_output=True,text=True)
    assert result.returncode==0,result.stderr
    return result.stdout


@given(st.sampled_from(['true','false','nil','f.secret']),
       st.integers(0,1600),st.integers(0,1500),st.booleans(),st.booleans(),
       st.sampled_from(['none','available','empty','secret']),st.booleans())
@settings(max_examples=100,deadline=None)
def test_next_action_requires_all_evidence(flag,elapsed_ms,window_ms,clock_public,same_clock,charges,event):
    # Oracle uses integer milliseconds; compare away from floating-point boundaries.
    remaining=1500-elapsed_ms
    valid=(event and flag=='true' and clock_public and same_clock and charges in ('none','available')
           and 0<remaining<min(window_ms,400))
    boundary=remaining==min(window_ms,400) and remaining>0
    code=f'''local f=require("tests.action_timing_fixture").create()
f.now=100+{elapsed_ms}/1000; f.window="{window_ms}"; f.flag={flag}
f.start={100 if same_clock else 99}
f.duration={"1.5" if clock_public else "f.secret"}
'''
    if charges!='none':
        current={'available':'1','empty':'0','secret':'f.secret'}[charges]
        code+=f'f.charge={{maxCharges=2,currentCharges={current},cooldownStartTime=90,cooldownDuration=30}}\n'
    if event: code+='f:capture()\n'
    code+='io.write(tostring(f.timing:GetDelay(258920)~=nil))'
    observed=run(code)=='true'
    if not boundary:
        assert observed==valid
    elif observed:
        assert event and flag=='true' and clock_public and same_clock and charges in ('none','available')


@given(st.integers(0,21000),st.integers(0,400),st.integers(0,2000))
@settings(max_examples=55,deadline=None)
def test_planning_does_not_extend_or_destroy_current_surge_knowledge(elapsed_ms,delay_ms,aura_ms):
    code=f'''local h=require("tests.helpers")
local RA,ns=h.loadAddon(); h.loadRegistry(ns)
local now=100; GetTime=function() return now end
RA:RegisterModule("CharacterState",{{GetSnapshot=function() return {{talentsComplete=true,specID=577,generation=1,talentKey="fel"}} end,
    GetTalentRank=function() return 1 end}})
RA:RegisterModule("PublicAuraFacts",{{ReadPlayer=function() return true,{aura_ms}/1000 end}})
assert(h.loadAddonFile("addon/Engine/HavocSurgeTracker.lua","RotaAssist",ns))
local t=RA:GetModule("HavocSurgeTracker"); t:OnEnable(); t:OnCast("player","meta",191427)
now=100+{elapsed_ms}/1000
local future={{}}; t:Populate(future,{delay_ms}/1000)
local current={{}}; t:Populate(current)
io.write(tostring(future["action.annihilation.demonsurge_available"])..":"..tostring(current["action.annihilation.demonsurge_available"]))
'''
    # Avoid testing exact binary-floating boundaries as different real intervals.
    if elapsed_ms+delay_ms==20000 or elapsed_ms==20000 or (delay_ms>0 and aura_ms==delay_ms):
        return
    current=elapsed_ms<20000
    future=elapsed_ms+delay_ms<20000 and (delay_ms==0 or aura_ms>delay_ms)
    assert run(code)==('1' if future else 'nil')+':'+('1' if current else 'nil')
