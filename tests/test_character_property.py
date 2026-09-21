"""test: generated node order/rank identity and rejected incomplete builds."""
import subprocess
import sys
from pathlib import Path
from hypothesis import given,settings,strategies as st

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"scripts"))
from export_independent_policy import lua


@given(st.lists(st.integers(1,3),min_size=1,max_size=15),st.booleans())
@settings(max_examples=40,deadline=None)
def test_build_key_is_order_independent_and_retains_each_selected_rank(ranks,reverse):
    ids=list(range(1,len(ranks)+1))
    if reverse: ids.reverse()
    expected="577|99|"+";".join(sorted(f"{i}:{100+i}:{rank}" for i,rank in enumerate(ranks,1)))
    code='''local h=require("tests.helpers")
local RA,ns=h.loadAddon()
local ranks=RANKS
GetSpecialization=function() return 1 end
GetSpecializationInfo=function() return 577 end
C_ClassTalents={GetActiveConfigID=function() return 7 end,GetActiveHeroTalentSpec=function() return 99 end}
C_Traits={ConfigHasStagedChanges=function() return false end,
 GetConfigInfo=function() return {treeIDs={1}} end,GetTreeNodes=function() return IDS end,
 GetNodeInfo=function(_,id) return {activeRank=ranks[id],activeEntry={entryID=id+100,rank=ranks[id]},entryIDs={id+100}} end,
 GetEntryInfo=function(_,id) return {definitionID=id+1000} end,
 GetDefinitionInfo=function(id) return {spellID=id+10000} end}
assert(h.loadAddonFile("addon/Engine/CharacterState.lua","RotaAssist",ns))
local C=RA:GetModule("CharacterState"); C:OnInitialize()
local s=C:Refresh(); assert(s.talentsComplete)
for i,rank in ipairs(ranks) do assert(C:GetTalentRank(11100+i)==rank) end
io.write(s.talentKey)
'''.replace("RANKS",lua(ranks)).replace("IDS",lua(ids))
    process=subprocess.run([r"C:\Program Files (x86)\Lua\5.1\lua.exe","-e",code],cwd=ROOT,capture_output=True,text=True)
    assert process.returncode==0,process.stderr
    assert process.stdout==expected
