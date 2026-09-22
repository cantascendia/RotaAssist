"""Reject false optimality claims and corrupted counterexample evidence."""
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MUTATIONS=[
    ('include_self_regret','scripts/optimality_bounds.py','if b!=a','if True'),
    ('reverse_regret','scripts/optimality_bounds.py','row[b][1]-row[a][0]','row[a][1]-row[b][0]'),
    ('allow_missing_actions','scripts/optimality_bounds.py','set(returns)!=set(alternatives)','False'),
    ('drop_prior_weight','scripts/optimality_bounds.py','sum(p*row[a][i]','sum(row[a][i]'),
    ('claim_live_proof','scripts/optimality_bounds.py',"'maximumDPSProven':False","'maximumDPSProven':True"),
    ('wrong_witness_action','addon/Engine/IndependentConsensus.lua','w.action,w.count=id,domainCount','w.action,w.count=999,domainCount'),
    ('close_open_endpoint','addon/Engine/IndependentConsensus.lua','b.minOpen,b.maxOpen=d.loOpen,d.hiOpen','b.minOpen,b.maxOpen=false,false'),
    ('drop_wait_witness','addon/Engine/IndependentConsensus.lua','if index<=2 then','if index<=2 and id~=0 then'),
    ('claim_policy_is_dps','addon/Engine/IndependentConsensus.lua','result.policyInvariant,result.maximumDPSProven=false,false','result.policyInvariant,result.maximumDPSProven=false,true'),
]


def main():
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('--output',type=Path,required=True)
    args=p.parse_args(); args.output.mkdir(parents=True,exist_ok=True); rows=[]
    for name,file,before,after in MUTATIONS:
        d=Path(tempfile.mkdtemp(prefix=name+'-',dir=args.output.resolve()))
        for part in ('addon','tests','scripts'):
            shutil.copytree(ROOT/part,d/part,ignore=shutil.ignore_patterns('__pycache__'))
        path=d/file; source=path.read_text(encoding='utf-8')
        expected=2 if name=='claim_policy_is_dps' else 1
        if source.count(before)!=expected: raise ValueError('anchor drift: '+name)
        path.write_text(source.replace(before,after),encoding='utf-8')
        command=([sys.executable,'-m','pytest','tests/test_optimality_bounds.py','-q'] if file.endswith('.py')
                 else [r'C:\Program Files (x86)\Lua\5.1\lua.exe','scripts/run_tests.lua','consensus_evidence'])
        r=subprocess.run(command,cwd=d,capture_output=True,text=True)
        (d/'result.txt').write_text(r.stdout+r.stderr,encoding='utf-8')
        killed=r.returncode!=0 and (('FAILED ' in r.stdout) if file.endswith('.py') else 'FAIL ' in r.stdout)
        rows.append({'name':name,'killed':killed})
    (args.output/'results.json').write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(rows,indent=2))
    if not all(row['killed'] for row in rows): raise SystemExit(1)


if __name__=='__main__': main()
