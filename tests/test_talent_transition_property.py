"""test: generated reset/extension invariants against the actual Lua transition."""
import subprocess
from pathlib import Path
from hypothesis import given, settings, strategies as st

ROOT = Path(__file__).resolve().parents[1]


@given(st.integers(0, 1), st.integers(0, 90), st.integers(0, 20), st.integers(0, 100))
@settings(max_examples=50, deadline=None)
def test_manual_meta_preserves_or_resets_exactly_the_selected_cooldowns(rank, eye, blade, remaining):
    code = f'''
local h=require("tests.helpers")
local RA,ns=h.loadAddon(); h.loadRegistry(ns)
RA:RegisterModule("CharacterState",{{GetSnapshot=function() return {{talentsComplete=true,specID=577}} end,
 GetTalentRank=function() return {rank} end}})
assert(h.loadAddonFile("addon/Engine/TalentTransitions.lua","RotaAssist",ns))
local s={{cooldowns={{[198013]={eye},[188499]={blade},[210152]={blade},[370965]=77}},
 cooldownUnknown={{}},inMeta=true,inMetaKnown=true,metaRemains={remaining}}}
assert(RA:GetModule("TalentTransitions"):Apply(s,577,191427))
assert(s.cooldowns[198013]=={0 if rank else eye})
assert(s.cooldowns[188499]=={0 if rank else blade})
assert(s.cooldowns[210152]=={0 if rank else blade})
assert(s.cooldowns[370965]==77)
assert(s.metaRemains=={remaining + 20})
assert(s.metaExpiryUncertain==false)
'''
    result = subprocess.run([r"C:\Program Files (x86)\Lua\5.1\lua.exe", "-e", code],
                            cwd=ROOT, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
