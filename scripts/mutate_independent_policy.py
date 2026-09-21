"""Targeted mutation checks in disposable copies; never edit the working tree."""
import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MUTATIONS=[
    ("unknown_as_false","addon/Engine/IndependentDecision.lua",
     "if matches == nil then\n                    conditionResult = nil",
     "if matches == nil then\n                    conditionResult = false"),
    ("ignore_earlier_candidate","addon/Engine/IndependentDecision.lua",
     "if #result.candidates == 1 then","if true then"),
    ("population_lower_bound_as_exact","addon/Engine/IndependentObserver.lua",
     "if state.targetCountKnown==true then","if true then"),
    ("inferred_resource_as_observed","addon/Engine/IndependentObserver.lua",
     "if state.resourceKnown==true then","if true then"),
    ("disconnect_queue_observer","addon/Engine/SmartQueueManager.lua",
     "if independent then\n            independent:Observe(limitedState)",
     "if false and independent then\n            independent:Observe(limitedState)"),
]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--lua",default=r"C:\Program Files (x86)\Lua\5.1\lua.exe")
    p.add_argument("--output",type=Path,required=True)
    args=p.parse_args(); args.output.mkdir(parents=True,exist_ok=True)
    outcomes=[]
    for name,file,before,after in MUTATIONS:
        sandbox=Path(tempfile.mkdtemp(prefix=name+"-",dir=args.output.resolve()))
        for folder in ("addon","tests"):
            shutil.copytree(ROOT/folder,sandbox/folder,ignore=shutil.ignore_patterns("__pycache__"))
        (sandbox/"scripts").mkdir()
        shutil.copy2(ROOT/"scripts/run_tests.lua",sandbox/"scripts/run_tests.lua")
        path=sandbox/file; source=path.read_text(encoding="utf-8")
        if source.count(before)!=1: raise ValueError("mutation anchor drift: "+name)
        path.write_text(source.replace(before,after),encoding="utf-8")
        result=subprocess.run([args.lua,"scripts/run_tests.lua","independent"],cwd=sandbox,capture_output=True,text=True)
        (sandbox/"result.txt").write_text(result.stdout+result.stderr,encoding="utf-8")
        killed=result.returncode!=0 and "FAIL " in result.stdout
        outcomes.append({"name":name,"killedByBehaviorTest":killed,"exitCode":result.returncode})
    (args.output/"results.json").write_text(json.dumps(outcomes,indent=2)+"\n")
    print(json.dumps(outcomes,indent=2))
    if not all(item["killedByBehaviorTest"] for item in outcomes): raise SystemExit(1)


if __name__=="__main__": main()
