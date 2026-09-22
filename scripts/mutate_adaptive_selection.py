"""Behavior mutations for selected hero data and current-population bounds."""
import argparse,json,shutil,subprocess,tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MUTATIONS=[
    ('ignore_adaptive','addon/Engine/IndependentObserver.lua','if adaptive then','if false then'),
    ('ignore_identity','addon/Engine/IndependentObserver.lua','if adaptive.heroProfile~=selected or adaptive.specID~=spec.specID then','if false then'),
    ('wrong_selected_hero','addon/Engine/IndependentObserver.lua','RA.IndependentAdaptivePolicies[selected]','RA.IndependentAdaptivePolicies.fel_scarred'),
    ('lower_bound_is_exact','addon/Engine/IndependentObserver.lua','if state.targetCountKnown==true then','if true then'),
    ('drop_lower_bound','addon/Engine/IndependentObserver.lua','sample.bounds.active_enemies=enemyBounds','sample.bounds.active_enemies=nil'),
    ('unlearned_gaze','addon/Data/Registry.lua','[452497] = 198013,\n','[452497] = nil,\n'),
    ('drop_gaze_transition','addon/Engine/TalentTransitions.lua','if data and spellID==data.abyssalGaze then','if false then'),
    ('skip_gaze_reset','addon/Data/Registry.lua','resetCooldowns = {198013, 452497, 188499, 210152}','resetCooldowns = {198013, 188499, 210152}'),
    ('ignore_base_cooldown_metadata','addon/Engine/SmartQueueManager.lua','or (pairedID and RA.WhitelistSpells[pairedID])','or nil'),
]


def main():
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('--output',type=Path,required=True)
    args=p.parse_args(); args.output.mkdir(parents=True,exist_ok=True); results=[]
    for name,file,before,after in MUTATIONS:
        d=Path(tempfile.mkdtemp(prefix=name+'-',dir=args.output.resolve()))
        for part in ('addon','tests'): shutil.copytree(ROOT/part,d/part,ignore=shutil.ignore_patterns('__pycache__'))
        (d/'scripts').mkdir(); shutil.copy2(ROOT/'scripts/run_tests.lua',d/'scripts/run_tests.lua')
        path=d/file; s=path.read_text(encoding='utf-8')
        if s.count(before)!=1: raise ValueError('anchor drift: '+name)
        path.write_text(s.replace(before,after),encoding='utf-8')
        result=subprocess.run([r'C:\Program Files (x86)\Lua\5.1\lua.exe','scripts/run_tests.lua','adaptive_policy_selection','abyssal_gaze'],cwd=d,capture_output=True,text=True)
        (d/'result.txt').write_text(result.stdout+result.stderr,encoding='utf-8')
        results.append({'name':name,'killedByBehaviorTest':result.returncode!=0 and 'FAIL ' in result.stdout})
    (args.output/'results.json').write_text(json.dumps(results,indent=2)+'\n'); print(json.dumps(results,indent=2))
    if not all(r['killedByBehaviorTest'] for r in results): raise SystemExit(1)


if __name__=='__main__': main()
