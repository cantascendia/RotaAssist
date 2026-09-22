"""Behavioral mutation checks in disposable copies, not the working tree."""
import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MUTATIONS=[
    ('static_base_proves_proc','addon/Core/Init.lua','return current==spellID','return true'),
    ('ignore_base_learning','addon/Core/Init.lua','if not baseKnown then return false end','if false then return false end'),
    ('drop_proc_in_observer','addon/Engine/IndependentObserver.lua','boolean(RA.IsPlayerSpellKnownSafe,RA,id)','boolean(IsPlayerSpell,id)'),
    ('drop_proc_in_final_queue','addon/Engine/SmartQueueManager.lua','if RA:IsPlayerSpellKnownSafe(sid)~=true then','if not IsPlayerSpell(sid) then'),
    ('drop_proc_in_castability','addon/Engine/SmartQueueManager.lua','if RA:IsPlayerSpellKnownSafe(spellID)~=true then','if not IsPlayerSpell(spellID) then'),
    ('skip_dynamic_range','addon/Engine/IndependentObserver.lua','if target and target.IsActive and target:IsActive() and target.GetSpellRange then','if false then'),
    ('ignore_hero_conflict','addon/Engine/IndependentObserver.lua','if selected then return nil,"conflicting_hero_talents" end','if false then return nil,"conflicting_hero_talents" end'),
    ('mask_unknown_hero','addon/Engine/IndependentObserver.lua','if unknown or not selected then','if not selected then'),
    ('reject_meta_probe','addon/Engine/TargetContext.lua','readBool(RA.IsPlayerSpellKnownSafe, RA, probe)','readBool(IsPlayerSpell, probe)'),
    ('reject_meta_resource','addon/Engine/ResourceEvidence.lua','pcall(RA.IsPlayerSpellKnownSafe,RA,id)','pcall(IsPlayerSpell,id)'),
]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--lua',default=r'C:\Program Files (x86)\Lua\5.1\lua.exe')
    args=p.parse_args(); args.output.mkdir(parents=True,exist_ok=True); outcomes=[]
    for name,file,before,after in MUTATIONS:
        sandbox=Path(tempfile.mkdtemp(prefix=name+'-',dir=args.output.resolve()))
        for folder in ('addon','tests'):
            shutil.copytree(ROOT/folder,sandbox/folder,ignore=shutil.ignore_patterns('__pycache__'))
        (sandbox/'scripts').mkdir(); shutil.copy2(ROOT/'scripts/run_tests.lua',sandbox/'scripts/run_tests.lua')
        path=sandbox/file; source=path.read_text(encoding='utf-8')
        if source.count(before)!=1: raise ValueError('mutation anchor drift: '+name)
        path.write_text(source.replace(before,after),encoding='utf-8')
        result=subprocess.run([args.lua,'scripts/run_tests.lua','aldrachi','havoc_overrides'],cwd=sandbox,capture_output=True,text=True)
        (sandbox/'result.txt').write_text(result.stdout+result.stderr,encoding='utf-8')
        outcomes.append({'name':name,'killedByBehaviorTest':result.returncode!=0 and 'FAIL ' in result.stdout,'exitCode':result.returncode})
    (args.output/'results.json').write_text(json.dumps(outcomes,indent=2)+'\n')
    print(json.dumps(outcomes,indent=2))
    if not all(r['killedByBehaviorTest'] for r in outcomes): raise SystemExit(1)


if __name__=='__main__': main()
