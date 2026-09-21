"""Run bounded character-import/calibration behavioral mutations in isolated copies."""
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MUTATIONS = [
    ("accept_profile_directives", "if key not in FIELDS:", "if False:"),
    ("discard_enchants", 'fields[key] = val', 'fields[key] = "0" if key == "enchant_id" else val'),
    ("ignore_gear_mismatch", 'if any(actual.get(key) != value for key, value in expected.items()):', 'if False:'),
    ("prefer_best_single_scenario", 'key=lambda item: min(', 'key=lambda item: max('),
    ("erase_measurement_uncertainty", 'margin = 3 * (own["standardError"] + reference["standardError"])', 'margin = 0'),
    ("reuse_discovery_seed", 'if args.seed == args.holdout_seed:', 'if False:'),
    ("ignore_character_talents", 'if str(player.get(field)) != identity["fields"][field]:', 'if field != "talents" and str(player.get(field)) != identity["fields"][field]:'),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for name, before, after in MUTATIONS:
        sandbox = Path(tempfile.mkdtemp(prefix=name + "-", dir=args.output.resolve()))
        (sandbox / "scripts").mkdir()
        (sandbox / "tests").mkdir()
        (sandbox / "research/independent-policy").mkdir(parents=True)
        for script in ("personal_calibration.py", "simc_bench.py", "search_independent_policy.py", "independent_policy.py"):
            shutil.copy2(ROOT / "scripts" / script, sandbox / "scripts" / script)
        shutil.copy2(ROOT / "tests/test_personal_calibration.py", sandbox / "tests")
        shutil.copy2(ROOT / "research/independent-policy/candidate.json", sandbox / "research/independent-policy")
        path = sandbox / "scripts/personal_calibration.py"
        code = path.read_text(encoding="utf-8")
        if code.count(before) != 1:
            raise ValueError("mutation anchor drift: " + name)
        path.write_text(code.replace(before, after), encoding="utf-8")
        run = subprocess.run([sys.executable, "-m", "pytest", "tests/test_personal_calibration.py", "-q"],
                             cwd=sandbox, capture_output=True, text=True)
        (sandbox / "result.txt").write_text(run.stdout + run.stderr, encoding="utf-8")
        results.append({"mutation": name, "killedByBehaviorTest": run.returncode == 1 and "FAILED " in run.stdout})
    (args.output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    print(json.dumps(results, indent=2))
    if not all(row["killedByBehaviorTest"] for row in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
