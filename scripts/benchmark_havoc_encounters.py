"""Evaluate frozen Havoc policies under pinned movement and add-wave proxies."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

from independent_policy import canonical
from search_independent_policy import run
from simc_bench import ENGINE_SHA256, SOURCE_COMMIT, PROFILE_SHA256, APL_SHA256, apl_bytes
from benchmark_aldrachi import PROFILE_SHA as ALDRACHI_SHA

ROOT=Path(__file__).resolve().parents[1]
MOVEMENT='movement,first=15,cooldown=30,distance=20'
ADDS='adds,count=4,first=25,cooldown=60,duration=20'
SCENARIOS={'movement':[MOVEMENT],'add_waves':[ADDS],'movement_and_adds':[MOVEMENT,ADDS]}
PROFILES={
    'fel_scarred':('MID2_Demon_Hunter_Havoc.simc',PROFILE_SHA256,'research/independent-policy/candidate.json'),
    'aldrachi_reaver':('MID2_Demon_Hunter_Havoc_Aldrachi_Reaver.simc',ALDRACHI_SHA,'research/aldrachi-policy/candidate.json'),
}


def verify_events(trace,events):
    evidence=[]
    for event in events:
        if "Creating raid event '"+event+"'." not in trace: raise ValueError('event not instantiated: '+event)
        pattern=(r'^([1-9][0-9]*\.[0-9]+) movement_distance \(id=\d+\) starts\.' if event.startswith('movement,')
                 else r"^([1-9][0-9]*\.[0-9]+) Enemy 'Fluffy_Pillow' summons \d+ for 20\.000s\.")
        matches=re.findall(pattern,trace,re.M)
        if not matches: raise ValueError('event did not execute: '+event)
        evidence.append({'event':event,'observedStarts':len(matches),'firstStart':float(matches[0])})
    return evidence


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--simc',type=Path,required=True); p.add_argument('--output',type=Path,required=True)
    args=p.parse_args(); simc=args.simc.resolve(); out=args.output.resolve(); out.mkdir(parents=True,exist_ok=True)
    if hashlib.sha256(simc.read_bytes()).hexdigest()!=ENGINE_SHA256: raise ValueError('engine drift')
    policies={hero:json.loads((ROOT/row[2]).read_text()) for hero,row in PROFILES.items()}
    frozen={hero:hashlib.sha256(canonical(policy)).hexdigest() for hero,policy in policies.items()}
    # Freeze identity before the first result. This turn does no encounter-based tuning.
    (out/'frozen-policies.json').write_text(json.dumps(frozen,indent=2)+'\n')
    comparisons=[]
    for hero,(filename,profile_hash,_) in PROFILES.items():
        base=(simc.parent/'profiles/MID2'/filename).read_bytes().replace(b'\r\n',b'\n')
        if hashlib.sha256(base).hexdigest()!=profile_hash or hashlib.sha256(apl_bytes(base)).hexdigest()!=APL_SHA256:
            raise ValueError('profile/APL drift')
        for name,events in SCENARIOS.items():
            folder=out/hero/name; folder.mkdir(parents=True,exist_ok=True)
            encounter=base+('\nraid_events='+'/'.join(events)+'\n').encode()
            ref=run(simc,encounter,None,folder,1,180,3000,20261101)
            own=run(simc,encounter,policies[hero],folder,1,180,3000,20261101)
            # One short reference trajectory proves events executed, not just parsed.
            trace=folder/'events.log'
            command=[str(simc),ref['command'][1],'iterations=1','threads=1','max_time=90','fixed_time=1',
                     'seed=20261102','debug=1','output='+str(trace)]
            result=subprocess.run(command,capture_output=True,text=True,timeout=120)
            (folder/'events-console.txt').write_text(result.stdout+result.stderr,encoding='utf-8')
            if result.returncode: raise ValueError('event replay failed')
            evidence=verify_events(trace.read_text(encoding='utf-8'),events)
            delta=own['dps']-ref['dps']; err=own['standardError']+ref['standardError']
            row={'hero':hero,'scenario':name,'events':events,'profileSha256':profile_hash,'policySha256':frozen[hero],
                 'reference':ref,'candidate':own,'ratio':own['dps']/ref['dps'],'delta':delta,
                 'deltaMinusThreeSESum':delta-3*err,'deltaPlusThreeSESum':delta+3*err,
                 'eventReplay':{'command':command,'raw':str(trace),'sha256':hashlib.sha256(trace.read_bytes()).hexdigest(),'evidence':evidence}}
            comparisons.append(row)
            print(json.dumps({'hero':hero,'scenario':name,'ratio':row['ratio']}),flush=True)
    report={'sourceCommit':SOURCE_COMMIT,'engineSha256':ENGINE_SHA256,'scenarios':comparisons,
            'frozenPolicies':frozen,'policyTunedOnTheseScenarios':False,'liveValidated':False,
            'representsSpecificBossOrDungeonRoute':False,'automaticReplacementQualified':False}
    (out/'holdout.json').write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__': main()
