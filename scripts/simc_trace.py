#!/usr/bin/env python3
"""Export a pinned, real SimC Havoc full-state action trace for offline replay.

This emits observed SimC data, not an addon-equivalent state or a DPS verdict.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
import sys
from pathlib import Path

try:
    from scripts import simc_bench as bench
except ImportError:  # Direct `python scripts/simc_trace.py` invocation.
    import simc_bench as bench


SCHEMA = "simc-havoc-full-state-trace-v1"
REQUIRED_STATE_KEYS = frozenset({"time", "resources", "resources_max"})
REQUIRED_ACTION_KEYS = frozenset({"id", "name", "target", "spell_name", "queue_failed"})


def validated_trace(raw: dict, *, targets: int, duration: int, seed: int) -> dict:
    """Keep SimC rows intact after checking their provenance and actual coverage."""
    if raw.get("version") != bench.EXPECTED_VERSION or raw.get("git_revision") != bench.SOURCE_COMMIT[:7]:
        raise ValueError("SimC version/revision mismatch")
    if raw.get("report_version") != "2.0.0":
        raise ValueError("expected pinned JSON report version 2.0.0")
    sim = raw.get("sim")
    if not isinstance(sim, dict):
        raise ValueError("missing SimC sim object")
    options = sim.get("options", {})
    dbc = options.get("dbc", {})
    if dbc.get("version_used") != "Live" or dbc.get("Live", {}).get("wow_version") != "12.1.0.69875" or dbc.get("Live", {}).get("build_level") != 69875:
        raise ValueError("SimC game build mismatch")
    required_options = {
        "desired_targets": targets, "max_time": duration, "seed": seed,
        "threads": 1, "iterations": 1, "fixed_time": True, "log": True,
        "vary_combat_length": 0,
    }
    for key, expected in required_options.items():
        if options.get(key) != expected:
            raise ValueError(f"SimC option mismatch: {key}")
    players = sim.get("players", [])
    if len(players) != 1 or players[0].get("specialization") != "Havoc Demon Hunter":
        raise ValueError("expected one Havoc Demon Hunter")
    player = players[0]
    if not isinstance(player.get("talents"), str) or not player["talents"]:
        raise ValueError("missing static SimC talents")
    data = player.get("collected_data", {})
    actions = data.get("action_sequence")
    precombat = data.get("action_sequence_precombat")
    if not isinstance(actions, list) or not actions or not isinstance(precombat, list):
        raise ValueError("missing full action sequence")
    has_buff_remains = has_cooldowns = has_targets = False
    wait_rows = 0
    previous_time = -math.inf
    for index, row in enumerate(actions):
        if not isinstance(row, dict) or not REQUIRED_STATE_KEYS <= row.keys():
            raise ValueError(f"incomplete state row {index}")
        if "wait" in row:
            if REQUIRED_ACTION_KEYS & row.keys() or not isinstance(row["wait"], (int, float)) or not math.isfinite(row["wait"]) or row["wait"] <= 0:
                raise ValueError(f"invalid wait row {index}")
            wait_rows += 1
        elif not REQUIRED_ACTION_KEYS <= row.keys():
            raise ValueError(f"incomplete action row {index}")
        timestamp = row["time"]
        if not isinstance(timestamp, (int, float)) or not math.isfinite(timestamp) or timestamp < previous_time:
            raise ValueError(f"invalid or unsorted action timestamp {index}")
        previous_time = timestamp
        if timestamp < 0 or timestamp > duration + 0.001:
            raise ValueError(f"action timestamp out of requested fight: {index}")
        if not isinstance(row["resources"], dict) or "fury" not in row["resources"] or not isinstance(row["resources_max"], dict) or "fury" not in row["resources_max"]:
            raise ValueError(f"missing observed fury state in action row {index}")
        has_buff_remains |= any("remains" in buff for buff in row.get("buffs", []))
        has_cooldowns |= bool(row.get("cooldowns"))
        has_targets |= bool(row.get("targets"))
    if not (has_buff_remains and has_cooldowns and has_targets):
        raise ValueError("JSON did not include expected full-state snapshots")
    for warning in raw.get("logs", []):
        if warning.get("level") != "implementation_not_yet_verified" or bench.MODEL_WARNING not in warning.get("message", ""):
            raise ValueError(f"unrecognized SimC warning/error: {warning}")
    return {
        "schema": SCHEMA,
        "simc_version": raw["version"],
        "simc_git_revision": raw["git_revision"],
        "simc_report_version": raw["report_version"],
        "sim": {
            "options": options,
            "players": [{
                "name": player["name"],
                "specialization": player["specialization"],
                "talents": player["talents"],
                "profile_source": player.get("profile_source"),
                "collected_data": {
                    "action_sequence_precombat": precombat,
                    "action_sequence": actions,
                },
            }],
        },
        "logs": raw.get("logs", []),
        "coverage": {
            "precombat_rows": len(precombat),
            "combat_rows": len(actions),
            "wait_rows": wait_rows,
            "full_states_observed": True,
            "not_captured_per_action": [
                "current_available_charges", "gcd_remaining", "target_health",
                "APL_rule_evaluation", "addon_Secret_value_availability",
            ],
            "cooldown_stacks_meaning": "SimC configured charges, not currently available charges",
            "snapshot_timing": "before ordinary action execution; special action paths may differ",
        },
    }


def run(args: argparse.Namespace) -> Path:
    if args.targets not in (1, 5) or args.duration not in (30, 60, 120, 300):
        raise ValueError("only 1/5 targets and 30/60/120/300-second trace scenarios are supported")
    simc = args.simc.resolve(strict=True)
    profile_path = args.profile.resolve(strict=True)
    if bench.sha256(simc.read_bytes()) != bench.ENGINE_SHA256:
        raise ValueError("pinned simc.exe SHA-256 mismatch")
    profile, profile_hash, apl_hash = bench.validated_profile(profile_path, "stock")
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    stem = f"stock-full-{args.targets}t-{args.duration}s-seed{args.seed}"
    staged_profile = output / f"{stem}.simc"
    raw_path = output / f"{stem}.raw.json"
    log_path = output / f"{stem}.log.txt"
    console_path = output / f"{stem}.console.txt"
    export_path = output / f"{stem}.trace.json"
    staged_profile.write_bytes(profile)
    command = [
        str(simc), str(staged_profile), "iterations=1", f"desired_targets={args.targets}",
        "threads=1", "fixed_time=1", f"max_time={args.duration}",
        "vary_combat_length=0", f"seed={args.seed}", "log=1", "log_spell_id=1",
        "report_details=1", f"json={raw_path},version=2.0.0,full_states=1", f"output={log_path}",
    ]
    completed = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=args.timeout)
    console = completed.stdout + "\n" + completed.stderr
    console_path.write_text(console, encoding="utf-8")
    if completed.returncode != 0 or re.search(r"(?im)^(?:Error:|.*Warning: Unknown option)", console):
        raise RuntimeError(f"SimC failed/unknown option; inspect {console_path}: {console[-1000:]}")
    if "Report will be generated with full state for each action." not in console:
        raise ValueError("SimC did not confirm full-state collection")
    if not raw_path.is_file() or not log_path.is_file():
        raise ValueError("SimC did not create raw JSON and combat log")
    raw_bytes = raw_path.read_bytes()
    exported = validated_trace(json.loads(raw_bytes), targets=args.targets, duration=args.duration, seed=args.seed)
    exported["provenance"] = {
        "upstream_commit": bench.SOURCE_COMMIT,
        "binary_sha256": bench.ENGINE_SHA256,
        "stock_profile_sha256": profile_hash,
        "stock_apl_sha256": apl_hash,
        "raw_json_sha256": bench.sha256(raw_bytes),
        "combat_log_sha256": bench.sha256(log_path.read_bytes()),
        "command": command,
        "raw_json_path": str(raw_path),
        "combat_log_path": str(log_path),
    }
    export_path.write_text(json.dumps(exported, indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")
    return export_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simc", required=True, type=Path)
    parser.add_argument("--profile", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--targets", required=True, type=int, choices=(1, 5))
    parser.add_argument("--duration", type=int, default=30, choices=(30, 60, 120, 300))
    parser.add_argument("--seed", type=int, default=20260922)
    parser.add_argument("--timeout", type=int, default=120)
    args = parser.parse_args()
    try:
        path = run(args)
    except (OSError, ValueError, RuntimeError, KeyError, TypeError, json.JSONDecodeError, subprocess.TimeoutExpired) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
