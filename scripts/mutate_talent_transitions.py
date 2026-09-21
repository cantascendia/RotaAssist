"""Behavioral mutation gate for selected-talent APL transitions."""
import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL = "addon/Engine/TalentTransitions.lua"
MUTATIONS = [
    ("assume_demonic_selected", MODEL, "selected>0 and data.demonicMinimum or 0", "data.demonicMinimum"),
    ("reset_without_talent", MODEL, "if selected and selected>0 then", "if true then"),
    ("shorten_existing_meta", MODEL, "duration+(wasActive and remaining or 0)", "duration"),
    ("retain_unknown_reset", MODEL, "state.cooldownUnknown[id]=nil", "state.cooldownUnknown[id]=true"),
    ("unknown_talent_is_absent", MODEL, "return true,nil,true", "return true,0,true"),
    ("disconnect_apl", "addon/Engine/APLEngine.lua", "local handled = transitions and transitions:Apply(simState, currentSpecID, spellID)", "local handled = false"),
    ("expire_lower_bound_as_false", "addon/Engine/APLEngine.lua", "if simState.metaExpiryUncertain then simState.inMetaKnown = false", "if false then simState.inMetaKnown = false"),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for name, file, before, after in MUTATIONS:
        sandbox = Path(tempfile.mkdtemp(prefix=name + "-", dir=args.output.resolve()))
        for folder in ("addon", "tests"):
            shutil.copytree(ROOT / folder, sandbox / folder, ignore=shutil.ignore_patterns("__pycache__"))
        (sandbox / "scripts").mkdir()
        shutil.copy2(ROOT / "scripts/run_tests.lua", sandbox / "scripts/run_tests.lua")
        path = sandbox / file
        text = path.read_text(encoding="utf-8")
        if text.count(before) != 1:
            raise ValueError("mutation anchor drift: " + name)
        path.write_text(text.replace(before, after), encoding="utf-8")
        result = subprocess.run([r"C:\Program Files (x86)\Lua\5.1\lua.exe", "scripts/run_tests.lua", "talent_transitions"],
                                cwd=sandbox, capture_output=True, text=True)
        (sandbox / "result.txt").write_text(result.stdout + result.stderr, encoding="utf-8")
        results.append({"mutation": name, "killedByBehaviorTest": result.returncode != 0 and "FAIL " in result.stdout})
    (args.output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    print(json.dumps(results, indent=2))
    if not all(row["killedByBehaviorTest"] for row in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
