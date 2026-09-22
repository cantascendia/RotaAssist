"""Search current-population burst priorities; freeze before independent holdout."""
import argparse
import copy
import hashlib
import itertools
import json
from pathlib import Path

from benchmark_havoc_encounters import PROFILES, MOVEMENT, ADDS
from independent_policy import canonical
from search_independent_policy import run
from simc_bench import ENGINE_SHA256, SOURCE_COMMIT, APL_SHA256, apl_bytes

ROOT=Path(__file__).resolve().parents[1]
DISCOVERY={'single':(1,[]),'waves':(1,[ADDS]),'moving_waves':(1,[MOVEMENT,ADDS])}
HOLDOUT={**DISCOVERY,'movement':(1,[MOVEMENT]),'five':(5,[])}


def variants(policy):
    yield copy.deepcopy(policy)
    for index,threshold in itertools.product((0,2,6,10,14),(2,3,5)):
        candidate=copy.deepcopy(policy)
        candidate['parameters']={'search':'current_population_burst','index':index,'threshold':threshold}
        candidate['rules'].insert(index,{'action':'immolation_aura','spellID':258920,'cost':0,'form':None,
                                       'conditions':[['active_enemies','>=',threshold]]})
        yield candidate


def rank(rows,reference,previous):
    ratios=[r['dps']/ref['dps'] for r,ref in zip(rows,reference)]
    eligible=rows[0]['dps']>=previous[0]['dps']*.99
    return min(ratios) if eligible else -1,ratios


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--simc',type=Path,required=True); p.add_argument('--output',type=Path,required=True)
    args=p.parse_args(); engine=args.simc.resolve(); out=args.output.resolve(); out.mkdir(parents=True,exist_ok=True)
    if hashlib.sha256(engine.read_bytes()).hexdigest()!=ENGINE_SHA256: raise ValueError('engine drift')
    all_results=[]
    for hero,(filename,digest,policy_path) in PROFILES.items():
        folder=out/hero; folder.mkdir(exist_ok=True)
        base=(engine.parent/'profiles/MID2'/filename).read_bytes().replace(b'\r\n',b'\n')
        if hashlib.sha256(base).hexdigest()!=digest or hashlib.sha256(apl_bytes(base)).hexdigest()!=APL_SHA256:
            raise ValueError('profile/APL drift')
        old=json.loads((ROOT/policy_path).read_text())
        def measure(policy,scenarios,iterations,seed,duration):
            rows=[]
            for name,(targets,events) in scenarios.items():
                dest=folder/name; dest.mkdir(exist_ok=True)
                payload=base+('\nraid_events='+'/'.join(events)+'\n').encode() if events else base
                rows.append(run(engine,payload,policy,dest,targets,duration,iterations,seed))
            return rows
        refs=measure(None,DISCOVERY,300,20261110,180)
        previous=measure(old,DISCOVERY,300,20261110,180)
        candidates=[]
        for policy in variants(old):
            rows=measure(policy,DISCOVERY,300,20261110,180); score,ratios=rank(rows,refs,previous)
            candidates.append({'policy':policy,'score':score,'ratios':ratios,'measurements':rows})
        (folder/'discovery.json').write_text(json.dumps({'reference':refs,'previous':previous,'candidates':candidates},indent=2)+'\n')
        # Verify top four and the unchanged policy on a new selection seed.
        refs=measure(None,DISCOVERY,1000,20261111,180); previous=measure(old,DISCOVERY,1000,20261111,180)
        pool=[row['policy'] for row in sorted(candidates,key=lambda r:r['score'],reverse=True)[:4]]
        if old not in pool: pool.append(old)
        finalists=[]
        for policy in pool:
            rows=measure(policy,DISCOVERY,1000,20261111,180); score,ratios=rank(rows,refs,previous)
            finalists.append({'policy':policy,'score':score,'ratios':ratios,'measurements':rows})
        winner=max(finalists,key=lambda r:r['score'])['policy']
        frozen=folder/'candidate.json'
        if frozen.exists() and canonical(json.loads(frozen.read_text()))!=canonical(winner): raise ValueError('frozen winner changed')
        frozen.write_text(json.dumps(winner,indent=2)+'\n')
        (folder/'finalists.json').write_text(json.dumps({'reference':refs,'previous':previous,'candidates':finalists},indent=2)+'\n')
        comparisons=[]
        for duration in (120,300):
            refs=measure(None,HOLDOUT,3000,20261112,duration)
            previous=measure(old,HOLDOUT,3000,20261112,duration)
            rows=measure(winner,HOLDOUT,3000,20261112,duration)
            for name,ref,prior,own in zip(HOLDOUT,refs,previous,rows):
                comparisons.append({'scenario':name,'duration':duration,'reference':ref,'previous':prior,'candidate':own,
                                    'referenceRatio':own['dps']/ref['dps'],'previousRatio':own['dps']/prior['dps'],
                                    'referenceDeltaMinusThreeSESum':own['dps']-ref['dps']-3*(own['standardError']+ref['standardError']),
                                    'previousDeltaMinusThreeSESum':own['dps']-prior['dps']-3*(own['standardError']+prior['standardError'])})
        result={'hero':hero,'profileSha256':digest,'policySha256':hashlib.sha256(canonical(winner)).hexdigest(),
                'previousPolicySha256':hashlib.sha256(canonical(old)).hexdigest(),'comparisons':comparisons,
                'changed':winner!=old,'beatsEveryReference':all(r['referenceDeltaMinusThreeSESum']>0 for r in comparisons)}
        (folder/'holdout.json').write_text(json.dumps(result,indent=2)+'\n'); all_results.append(result)
        print('HERO',hero,'CHANGED',result['changed'],'RATIOS',[round(r['referenceRatio'],4) for r in comparisons],flush=True)
    (out/'holdout.json').write_text(json.dumps({'sourceCommit':SOURCE_COMMIT,'engineSha256':ENGINE_SHA256,
        'heroes':all_results,'liveValidated':False,'automaticReplacementQualified':False},indent=2)+'\n')


if __name__=='__main__': main()
