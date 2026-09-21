"""Behavioral mutations for character provenance and live queue invalidation."""
import argparse,json,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MODEL="addon/Engine/CharacterState.lua"
MUTATIONS=[
    ("retain_stale_dynamic_stats",MODEL,'wipe(stats)','-- mutation: retain previous stats'),
    ("accept_staged_edits",MODEL,'if boolean(traits.ConfigHasStagedChanges,config)~=false then return "staged_changes" end',
     'if false then return "staged_changes" end'),
    ("ignore_configuration_race",MODEL,'if integer(call(classes.GetActiveConfigID))~=config','if false'),
    ("select_every_choice",MODEL,'if rank>0 and entryID==activeID then','if rank>0 then'),
    ("ignore_gear_modifiers",MODEL,'tokens[#tokens+1]=slot..":"..token','tokens[#tokens+1]=slot..":"..id'),
    ("accept_unknown_build","addon/Engine/IndependentObserver.lua",'if not build.talentsComplete or build.specID~=policy.specID then','if false then'),
    ("disconnect_queue_invalidation","addon/Engine/SmartQueueManager.lua",'eh:Subscribe("ROTAASSIST_CHARACTER_CHANGED", "SmartQueueManager", function()',
     'eh:Subscribe("ROTAASSIST_UNUSED_CHARACTER", "SmartQueueManager", function()'),
]


def main():
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args(); args.output.mkdir(parents=True,exist_ok=True); results=[]
    for name,file,before,after in MUTATIONS:
        sandbox=Path(tempfile.mkdtemp(prefix=name+"-",dir=args.output.resolve()))
        for folder in ("addon","tests"):
            shutil.copytree(ROOT/folder,sandbox/folder,ignore=shutil.ignore_patterns("__pycache__"))
        (sandbox/"scripts").mkdir(); shutil.copy2(ROOT/"scripts/run_tests.lua",sandbox/"scripts/run_tests.lua")
        path=sandbox/file; text=path.read_text(encoding="utf-8")
        if text.count(before)!=1: raise ValueError("mutation anchor drift: "+name)
        path.write_text(text.replace(before,after),encoding="utf-8")
        process=subprocess.run([r"C:\Program Files (x86)\Lua\5.1\lua.exe","scripts/run_tests.lua","character"],cwd=sandbox,capture_output=True,text=True)
        (sandbox/"result.txt").write_text(process.stdout+process.stderr,encoding="utf-8")
        results.append({"mutation":name,"killedByBehaviorTest":process.returncode!=0 and "FAIL " in process.stdout})
    (args.output/"results.json").write_text(json.dumps(results,indent=2)+"\n")
    print(json.dumps(results,indent=2))
    if not all(r["killedByBehaviorTest"] for r in results): raise SystemExit(1)


if __name__=="__main__": main()
