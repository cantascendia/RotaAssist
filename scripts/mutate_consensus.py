"""Isolated behavioral mutations for the all-feasible-worlds proof boundary."""
import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SOLVER="addon/Engine/IndependentConsensus.lua"
MUTATIONS=[
    ("drop_false_branches",SOLVER,"elseif constrain(d,inverse[pred.op],pred.value) then","elseif false then"),
    ("merge_equality_with_upper_side",SOLVER,'if constrain(d,">",pred.value) then','if false then'),
    ("ignore_possible_wait",SOLVER,"if ri>ruleCount then witness(0); return end","if ri>ruleCount then return end"),
    ("ignore_budget_exhaustion",SOLVER,'if exhausted then result.status="budget_exceeded"',
     'if exhausted then result.status="decided"; result.spellID=1'),
    ("merge_different_charge_domains",SOLVER,'key="charges:"..id;','key="charges";'),
    ("disconnect_observer_consensus","addon/Engine/IndependentObserver.lua",
     "local evaluated=(consensus or evaluator):Evaluate(policy,sample)",
     "local evaluated=evaluator:Evaluate(policy,sample)"),
]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",required=True,type=Path)
    args=parser.parse_args(); args.output.mkdir(parents=True,exist_ok=True)
    results=[]
    for name,file,before,after in MUTATIONS:
        sandbox=Path(tempfile.mkdtemp(prefix=name+"-",dir=args.output.resolve()))
        for folder in ("addon","tests"):
            shutil.copytree(ROOT/folder,sandbox/folder,ignore=shutil.ignore_patterns("__pycache__"))
        (sandbox/"scripts").mkdir(); shutil.copy2(ROOT/"scripts/run_tests.lua",sandbox/"scripts/run_tests.lua")
        path=sandbox/file; content=path.read_text(encoding="utf-8")
        if content.count(before)!=1: raise ValueError("mutation anchor drift: "+name)
        path.write_text(content.replace(before,after),encoding="utf-8")
        process=subprocess.run([r"C:\Program Files (x86)\Lua\5.1\lua.exe","scripts/run_tests.lua","consensus"],
                               cwd=sandbox,capture_output=True,text=True)
        (sandbox/"result.txt").write_text(process.stdout+process.stderr,encoding="utf-8")
        results.append({"mutation":name,"killedByBehaviorTest":process.returncode!=0 and "FAIL " in process.stdout})
    (args.output/"results.json").write_text(json.dumps(results,indent=2)+"\n")
    print(json.dumps(results,indent=2))
    if not all(r["killedByBehaviorTest"] for r in results): raise SystemExit(1)


if __name__=="__main__": main()
