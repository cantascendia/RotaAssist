"""Check phase boundary/prefix faults in isolated project copies."""
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MUTATIONS=[
    ("reverse_phase_guards",'((early,"<"),(late,">="))','((early,">="),(late,"<"))'),
    ("shift_boundary",'["time",op,switch]','["time",op,switch+1]'),
    ("reuse_early_in_late_phase",'((early,"<"),(late,">="))','((early,"<"),(early,">="))'),
]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",required=True,type=Path)
    args=parser.parse_args(); args.output.mkdir(parents=True,exist_ok=True)
    results=[]
    for name,before,after in MUTATIONS:
        sandbox=Path(tempfile.mkdtemp(prefix=name+"-",dir=args.output.resolve()))
        for folder in ("addon","tests","scripts"):
            shutil.copytree(ROOT/folder,sandbox/folder,ignore=shutil.ignore_patterns("__pycache__"))
        path=sandbox/"scripts/build_phase_policy.py"; content=path.read_text(encoding="utf-8")
        if content.count(before)!=1: raise ValueError("mutation anchor drift: "+name)
        path.write_text(content.replace(before,after),encoding="utf-8")
        process=subprocess.run([sys.executable,"-m","pytest","tests/test_phase_policy.py","-q"],
                               cwd=sandbox,capture_output=True,text=True)
        (sandbox/"result.txt").write_text(process.stdout+process.stderr,encoding="utf-8")
        results.append({"mutation":name,"killedByBehaviorTest":process.returncode==1 and "FAILED tests" in process.stdout})
    (args.output/"results.json").write_text(json.dumps(results,indent=2)+"\n")
    print(json.dumps(results,indent=2))
    if not all(r["killedByBehaviorTest"] for r in results): raise SystemExit(1)


if __name__=="__main__": main()
