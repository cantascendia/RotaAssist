"""Behavioral mutation gate for event-scoped GCD readiness."""
import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MUTATIONS=[
    ('ignore_gcd_flag','addon/Engine/ActionTiming.lua','eventFacts.isOnGCD==true','true'),
    ('ignore_spell_clock','addon/Engine/ActionTiming.lua','start==gcdStart and duration==gcdDuration\n','true\n'),
    ('ignore_queue_window','addon/Engine/ActionTiming.lua','remaining<=window','true'),
    ('ignore_clock_refresh','addon/Engine/ActionTiming.lua','start==starts[id] and duration==durations[id]','true'),
    ('ignore_charges','addon/Engine/ActionTiming.lua','local function chargeAvailable(id)\n','local function chargeAvailable(id)\n    if true then return true end\n'),
    ('ignore_cast_reset','addon/Engine/ActionTiming.lua','if not public(unit) or unit=="player" then self:Reset() end','if false then self:Reset() end'),
    ('ignore_event_scope','addon/Engine/ActionTiming.lua','(spellID==nil or id==spellID or id==baseSpellID)','true'),
    ('ignore_aura_expiry','addon/Engine/IndependentObserver.lua','sample.facts[key]=remains>delay','sample.facts[key]=true'),
    ('keep_unbounded_aura','addon/Engine/IndependentObserver.lua','else sample.facts[key]=nil end','else sample.facts[key]=true end'),
    ('drop_gcd_readiness','addon/Engine/IndependentObserver.lua','and timing:GetDelay(id) then remaining=0','and false then remaining=0'),
    ('extend_surge_expiry','addon/Engine/HavocSurgeTracker.lua','expires[i]>now+delay','expires[i]>now'),
    ('ignore_form_horizon','addon/Engine/HavocSurgeTracker.lua','if delay>0 and (not number(remains) or remains<=delay) then','if false then'),
]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args(); args.output.mkdir(parents=True,exist_ok=True)
    results=[]
    for name,file,before,after in MUTATIONS:
        directory=Path(tempfile.mkdtemp(prefix=name+'-',dir=args.output.resolve()))
        for part in ('addon','tests'):
            shutil.copytree(ROOT/part,directory/part,ignore=shutil.ignore_patterns('__pycache__'))
        (directory/'scripts').mkdir(); shutil.copy2(ROOT/'scripts/run_tests.lua',directory/'scripts/run_tests.lua')
        path=directory/file; source=path.read_text(encoding='utf-8')
        if source.count(before)!=1: raise ValueError('anchor drift: '+name)
        path.write_text(source.replace(before,after),encoding='utf-8')
        result=subprocess.run([r'C:\Program Files (x86)\Lua\5.1\lua.exe','scripts/run_tests.lua','action_timing'],
                              cwd=directory,capture_output=True,text=True)
        (directory/'result.txt').write_text(result.stdout+result.stderr,encoding='utf-8')
        results.append({'name':name,'killed':result.returncode!=0 and 'FAIL ' in result.stdout})
    (args.output/'results.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(results,indent=2))
    if not all(row['killed'] for row in results): raise SystemExit(1)


if __name__=='__main__': main()
