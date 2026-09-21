"""Behavioral mutation gate for event-derived Havoc surge flags."""
import argparse,json,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
TRACKER="addon/Engine/HavocSurgeTracker.lua"
MUTATIONS=[
    ("ignore_consumption",TRACKER,"then values[index]=0 end","then values[index]=1 end"),
    ("ignore_duplicate_cast",TRACKER,"if guids[i]==guid then return end","if false then return end"),
    ("rearm_aura_on_eye",TRACKER,"for i=1,2 do values[i]=1","for i=1,3 do values[i]=1"),
    ("ignore_demonic_selection",TRACKER,"if demonic==0 then return end","-- ignore unselected talent"),
    ("retain_expired_flags",TRACKER,"if expires[i] and expires[i]>now then facts[key]=values[i]","if expires[i] then facts[key]=values[i]"),
    ("unknown_form_is_active",TRACKER,'return 0,"form_unknown"','up=true'),
    ("retain_dead_history",TRACKER,'"PLAYER_ENTERING_WORLD","PLAYER_DEAD"','"PLAYER_ENTERING_WORLD"'),
    ("retain_cancelled_form",TRACKER,'if not public(up) or up~=true then clear() end','-- retain cancelled form'),
    ("disconnect_observer","addon/Engine/IndependentObserver.lua",'if surge then status.surgeTrackedFacts,status.surgeSource=surge:Populate(sample.facts) end','-- disconnected cast model'),
]


def main():
    p=argparse.ArgumentParser(description=__doc__); p.add_argument("--output",type=Path,required=True)
    args=p.parse_args(); args.output.mkdir(parents=True,exist_ok=True); results=[]
    for name,file,before,after in MUTATIONS:
        folder=Path(tempfile.mkdtemp(prefix=name+"-",dir=args.output.resolve()))
        for part in ("addon","tests"):
            shutil.copytree(ROOT/part,folder/part,ignore=shutil.ignore_patterns("__pycache__"))
        (folder/"scripts").mkdir(); shutil.copy2(ROOT/"scripts/run_tests.lua",folder/"scripts/run_tests.lua")
        path=folder/file; source=path.read_text(encoding="utf-8")
        if source.count(before)!=1: raise ValueError("mutation anchor drift: "+name)
        path.write_text(source.replace(before,after),encoding="utf-8")
        run=subprocess.run([r"C:\Program Files (x86)\Lua\5.1\lua.exe","scripts/run_tests.lua","havoc_surge"],cwd=folder,capture_output=True,text=True)
        (folder/"result.txt").write_text(run.stdout+run.stderr,encoding="utf-8")
        results.append({"mutation":name,"killedByBehaviorTest":run.returncode!=0 and "FAIL " in run.stdout})
    (args.output/"results.json").write_text(json.dumps(results,indent=2)+"\n")
    print(json.dumps(results,indent=2))
    if not all(row["killedByBehaviorTest"] for row in results): raise SystemExit(1)


if __name__=="__main__": main()
