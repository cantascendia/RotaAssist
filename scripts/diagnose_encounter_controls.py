"""Isolate reference retarget/pickup effects without weakening qualification."""
import argparse,hashlib,json
from pathlib import Path
from benchmark_havoc_encounters import PROFILES,MOVEMENT,ADDS
from search_independent_policy import run
from simc_bench import ENGINE_SHA256,APL_SHA256,apl_bytes


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--simc',type=Path,required=True); p.add_argument('--output',type=Path,required=True)
    args=p.parse_args(); exe=args.simc.resolve(); out=args.output.resolve(); out.mkdir(parents=True,exist_ok=True)
    if hashlib.sha256(exe.read_bytes()).hexdigest()!=ENGINE_SHA256: raise ValueError('engine drift')
    results=[]
    for hero,(filename,digest,_) in PROFILES.items():
        raw=(exe.parent/'profiles/MID2'/filename).read_bytes().replace(b'\r\n',b'\n')
        if hashlib.sha256(raw).hexdigest()!=digest or hashlib.sha256(apl_bytes(raw)).hexdigest()!=APL_SHA256:
            raise ValueError('profile/APL drift')
        for intervention,prefix in [('reference',None),('without_auto_retarget','actions+=/retarget_auto_attack'),
                                    ('without_fragment_pickup','actions+=/pick_up_fragment')]:
            folder=out/hero/intervention; folder.mkdir(parents=True,exist_ok=True)
            lines=raw.decode().splitlines()
            if prefix and not any(line.startswith(prefix) for line in lines): raise ValueError('intervention anchor absent')
            modified='\n'.join(line for line in lines if prefix is None or not line.startswith(prefix))
            modified+='\nraid_events='+MOVEMENT+'/'+ADDS+'\n'
            measurement=run(exe,modified.encode(),None,folder,1,180,500,20261115)
            results.append({'hero':hero,'intervention':intervention,'measurement':measurement})
    (out/'results.json').write_text(json.dumps(results,indent=2)+'\n')


if __name__=='__main__': main()
