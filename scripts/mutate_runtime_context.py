"""Behavior mutations for automatic in-game spell/range discovery."""
import argparse,json,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CATALOG="addon/Engine/SpellCatalog.lua"
CONTEXT="addon/Engine/TargetContext.lua"
MUTATIONS=[
    ("include_passive_and_offspec",CATALOG,'if not passive and not offSpec then','if true then'),
    ("retain_old_book",CATALOG,'wipe(snapshot.spells)\n    snapshot.revision','-- keep stale spells\n    snapshot.revision'),
    ("lose_base_known_override",CATALOG,'if learned~=true and base~=id and flag(call(IsPlayerSpell,base))==true then learned=true end','-- lost override'),
    ("disable_generic_ranges",CONTEXT,'state.genericSupported = trackedSpells > 0','state.genericSupported = trackedSpells > 0; if not config then return state end'),
    ("count_idle_enemies",CONTEXT,'if engaged == true then','if engaged ~= nil then'),
    ("ignore_target_distance",CONTEXT,'local value = range(spellID, "target")','local value = true'),
    ("duplicate_targetable_guids",CONTEXT,'seen[guid] = true; result.min = result.min + 1','result.min = result.min + 1'),
]


def main():
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args(); args.output.mkdir(parents=True,exist_ok=True); results=[]
    for name,file,before,after in MUTATIONS:
        folder=Path(tempfile.mkdtemp(prefix=name+"-",dir=args.output.resolve()))
        for part in ("addon","tests"):
            shutil.copytree(ROOT/part,folder/part,ignore=shutil.ignore_patterns("__pycache__"))
        (folder/"scripts").mkdir(); shutil.copy2(ROOT/"scripts/run_tests.lua",folder/"scripts/run_tests.lua")
        path=folder/file; source=path.read_text(encoding="utf-8")
        if before not in source: raise ValueError("mutation anchor drift: "+name)
        path.write_text(source.replace(before,after),encoding="utf-8")
        run=subprocess.run([r"C:\Program Files (x86)\Lua\5.1\lua.exe","scripts/run_tests.lua","runtime"],cwd=folder,capture_output=True,text=True)
        (folder/"result.txt").write_text(run.stdout+run.stderr,encoding="utf-8")
        results.append({"mutation":name,"killedByBehaviorTest":run.returncode!=0 and "FAIL " in run.stdout})
    (args.output/"results.json").write_text(json.dumps(results,indent=2)+"\n")
    print(json.dumps(results,indent=2))
    if not all(row["killedByBehaviorTest"] for row in results): raise SystemExit(1)


if __name__=="__main__": main()
