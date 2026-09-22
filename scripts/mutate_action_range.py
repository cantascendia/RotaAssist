"""Focused behavioral mutations for the action applicability witness."""
import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
TARGET='addon/Engine/TargetContext.lua'
MUTATIONS=[
    ('ignore_native_false',TARGET,'if native~=nil then return native,"native_spell_range" end','if native==true then return native,"native_spell_range" end'),
    ('all_spells_radial',TARGET,'or area[spellID]~=true','or false'),
    ('ignore_no_range_declaration',TARGET,'if readBool(C_Spell and C_Spell.SpellHasRange,spellID)~=false then','if false then'),
    ('false_probe_is_proof',TARGET,'self:GetSpellRange(probe)==true','self:GetSpellRange(probe)~=nil'),
    ('unknown_probe_is_proof',TARGET,'if probe and self:GetSpellRange(probe)==true then','if probe then'),
    ('ignore_specialization',TARGET,'if config and spec and spec.specID == config.specID then return config end','if config then return config end'),
    ('disabled_can_prove',TARGET,'if not enabled or not public(spellID)','if not public(spellID)'),
    ('observer_uses_only_native','addon/Engine/IndependentObserver.lua','if target.GetActionRange then','if false then'),
]


def main():
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('--output',type=Path,required=True)
    args=p.parse_args(); args.output.mkdir(parents=True,exist_ok=True); outcomes=[]
    for name,file,before,after in MUTATIONS:
        folder=Path(tempfile.mkdtemp(prefix=name+'-',dir=args.output.resolve()))
        for part in ('addon','tests'): shutil.copytree(ROOT/part,folder/part,ignore=shutil.ignore_patterns('__pycache__'))
        (folder/'scripts').mkdir(); shutil.copy2(ROOT/'scripts/run_tests.lua',folder/'scripts/run_tests.lua')
        path=folder/file; source=path.read_text(encoding='utf-8')
        if source.count(before)!=1: raise ValueError('anchor drift: '+name)
        path.write_text(source.replace(before,after),encoding='utf-8')
        run=subprocess.run([r'C:\Program Files (x86)\Lua\5.1\lua.exe','scripts/run_tests.lua','action_range'],cwd=folder,capture_output=True,text=True)
        (folder/'result.txt').write_text(run.stdout+run.stderr,encoding='utf-8')
        outcomes.append({'name':name,'killedByBehaviorTest':run.returncode!=0 and 'FAIL ' in run.stdout})
    (args.output/'results.json').write_text(json.dumps(outcomes,indent=2)+'\n'); print(json.dumps(outcomes,indent=2))
    if not all(r['killedByBehaviorTest'] for r in outcomes): raise SystemExit(1)


if __name__=='__main__': main()
