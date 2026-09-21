"""Behavior mutations for public-evidence and experimental-head boundaries."""
import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MUTATIONS=[
    ("optional_cost_as_minimum","addon/Engine/ResourceEvidence.lua",
     "minimum=value","minimum=total"),
    ("accept_contradictory_bounds","addon/Engine/ResourceEvidence.lua",
     "if result.max and result.min>=result.max then result.inconsistent=true end",
     "if false then result.inconsistent=true end"),
    ("infer_nil_aura_absence","addon/Engine/PublicAuraFacts.lua",
     'if C_Secrets and boolean(C_Secrets.ShouldAurasBeSecret)==false',
     'if C_Secrets and true'),
    ("ignore_experimental_opt_in","addon/Engine/IndependentObserver.lua",
     'if not settings or settings.independentExperimental~=true then return nil end',
     'if not settings then return nil end'),
    ("seed_with_discarded_reference","addon/Engine/SmartQueueManager.lua",
     'context.blizzSpell = selected', 'context.blizzSpell = nil'),
    ("skip_resource_evidence","addon/Engine/IndependentObserver.lua",
     'if bounds.observations>0 and not bounds.inconsistent then sample.bounds.fury=bounds end',
     'if false then sample.bounds.fury=bounds end'),
]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path,required=True)
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
        result=subprocess.run([r"C:\Program Files (x86)\Lua\5.1\lua.exe","scripts/run_tests.lua",
            "resource_evidence","public_aura","public_signal"],cwd=sandbox,capture_output=True,text=True)
        (sandbox/"result.txt").write_text(result.stdout+result.stderr,encoding="utf-8")
        killed=result.returncode!=0 and "FAIL " in result.stdout
        results.append({"mutation":name,"killedByBehaviorTest":killed})
    (args.output/"results.json").write_text(json.dumps(results,indent=2)+"\n")
    print(json.dumps(results,indent=2))
    if not all(r["killedByBehaviorTest"] for r in results): raise SystemExit(1)

if __name__=="__main__": main()
