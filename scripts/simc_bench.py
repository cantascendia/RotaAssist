#!/usr/bin/env python3
"""Run pinned, real SimulationCraft Havoc APL experiments.

The two interventions change exactly one stock APL line each. This tool never
translates addon Lua into SimC or claims its numbers measure addon performance.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import subprocess
import sys
import time
from pathlib import Path


ENGINE_SHA256 = "8c6df94966798cabf6864664c2648de9252e396a5ea90188c115c17c8b5339de"
SOURCE_COMMIT = "774babde5ddc7c5fc9f1abb129b473f8a076df70"
PROFILE_SHA256 = "d14ce688a7016d548c4abd3c2554be2b891c1284d771180ab7cc2571c17db3e1"
APL_SHA256 = "1c1f2231e161d107ecaa81f02fd0b39d4438e3b96d15dd3b813f3ab53b4a8f74"
EXPECTED_VERSION = "1210-01"
EXPECTED_BUILD = "12.1.0.69875 Live"
MODEL_WARNING = "Rune of Unleashed Fire: Procs are assumed to target the same unit"

INTERVENTIONS = {
    "stock": None,
    # Explicitly hold Eye Beam in AoE until Essence Break is within 3 seconds.
    "eye_beam_hold_aoe": (
        "actions+=/eye_beam",
        "actions+=/eye_beam,if=active_enemies=1|cooldown.essence_break.remains<3",
    ),
    # Make a single stock cooldown gate less restrictive, with all other rules intact.
    "essence_break_gate_2s": (
        "actions+=/essence_break,if=cooldown.eye_beam.remains>4",
        "actions+=/essence_break,if=cooldown.eye_beam.remains>2",
    ),
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def apl_bytes(profile: bytes) -> bytes:
    lines = [line for line in profile.replace(b"\r\n", b"\n").splitlines() if line.startswith(b"actions")]
    return b"\n".join(lines) + b"\n"


def validated_profile(profile_path: Path, intervention: str) -> tuple[bytes, str, str]:
    raw = profile_path.read_bytes()
    canonical = raw.replace(b"\r\n", b"\n")
    if sha256(canonical) != PROFILE_SHA256:
        raise ValueError("official stock profile SHA-256 mismatch")
    if sha256(apl_bytes(canonical)) != APL_SHA256:
        raise ValueError("official stock APL SHA-256 mismatch")
    replacement = INTERVENTIONS[intervention]
    if replacement is not None:
        old, new = replacement
        old_line = (old + "\n").encode()
        if canonical.count(old_line) != 1:
            raise ValueError(f"intervention match count is not one: {old}")
        canonical = canonical.replace(old_line, (new + "\n").encode(), 1)
    return canonical, sha256(canonical), sha256(apl_bytes(canonical))


def parse_result(
    data: dict, expected_targets: int, expected_seed: int,
    expected_threads: int, requested_iterations: int,
) -> dict:
    version = str(data.get("version", ""))
    revision = str(data.get("git_revision", ""))
    if version != EXPECTED_VERSION or revision != SOURCE_COMMIT[:7]:
        raise ValueError(f"SimC version/revision mismatch: {version}/{revision}")
    sim = data.get("sim")
    if not isinstance(sim, dict):
        raise ValueError("SimC JSON has no sim object")
    options = sim.get("options", {})
    if options.get("desired_targets") != expected_targets or options.get("seed") != expected_seed:
        raise ValueError("SimC silently changed targets or seed")
    if options.get("threads") != expected_threads or not 1 <= expected_threads <= 4:
        raise ValueError("SimC thread count does not match request")
    if options.get("iterations") != requested_iterations + 1:
        raise ValueError("SimC iteration count does not match this pinned engine")
    dbc = options.get("dbc", {})
    live = dbc.get("Live", {})
    if dbc.get("version_used") != "Live" or live.get("wow_version") != "12.1.0.69875" or live.get("build_level") != 69875:
        raise ValueError("SimC game build is not the pinned 12.1.0.69875 Live build")
    if len(sim.get("players", [])) != 1:
        raise ValueError("expected exactly one player")
    player = sim["players"][0]
    if player.get("specialization") != "Havoc Demon Hunter":
        raise ValueError("profile did not simulate Havoc")
    dps = player["collected_data"]["dps"]
    count = int(dps["count"])
    mean = float(dps["mean"])
    standard_error = float(dps["mean_std_dev"])
    if count < requested_iterations - 2 or not math.isfinite(mean) or mean <= 0:
        raise ValueError(f"invalid or insufficient DPS samples: {count}/{mean}")
    if not math.isfinite(standard_error) or standard_error < 0:
        raise ValueError("invalid DPS standard error")
    warnings = data.get("logs", [])
    for warning in warnings:
        if (
            warning.get("level") != "implementation_not_yet_verified"
            or MODEL_WARNING not in warning.get("message", "")
        ):
            raise ValueError(f"unrecognized SimulationCraft warning/error: {warning}")
    stats = sim.get("statistics", {})
    return {
        "dps_mean": mean,
        "dps_sample_count": count,
        "dps_standard_error": standard_error,
        "dps_95ci_half_width_approx": 1.96 * standard_error,
        "sim_wall_seconds": stats.get("elapsed_time_seconds"),
        "sim_cpu_seconds": stats.get("elapsed_cpu_seconds"),
        "warnings": warnings,
        "simc_version": version,
        "simc_git_revision": revision,
        "build": f"{live['wow_version']} Live",
        "options": options,
    }


def run(args: argparse.Namespace) -> dict:
    if args.threads < 1 or args.threads > 4:
        raise ValueError("threads must be in 1..4")
    if args.iterations < 100:
        raise ValueError("iterations must be at least 100")
    if args.targets not in (1, 5):
        raise ValueError("only the predeclared 1- and 5-target scenarios are supported")
    if args.duration not in (120, 300):
        raise ValueError("duration must be 120 or 300 seconds")
    simc = args.simc.resolve(strict=True)
    if sha256(simc.read_bytes()) != ENGINE_SHA256:
        raise ValueError("simc.exe SHA-256 mismatch")
    profile, profile_hash, apl_hash = validated_profile(args.profile.resolve(strict=True), args.intervention)
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    run_id = f"{args.intervention}-{args.targets}t-{args.duration}s-{args.iterations}i-seed{args.seed}"
    profile_path = output / f"{run_id}.simc"
    raw_json = output / f"{run_id}.simc.json"
    stdout_path = output / f"{run_id}.stdout.txt"
    result_path = output / f"{run_id}.report.json"
    profile_path.write_bytes(profile)
    command = [
        str(simc), str(profile_path), f"iterations={args.iterations}",
        f"desired_targets={args.targets}", f"threads={args.threads}",
        "fixed_time=1", f"max_time={args.duration}", "vary_combat_length=0",
        f"seed={args.seed}", f"json2={raw_json}", "report_details=0",
    ]
    started = time.monotonic()
    completed = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=args.timeout)
    elapsed = time.monotonic() - started
    stdout = completed.stdout + "\n" + completed.stderr
    stdout_path.write_text(stdout, encoding="utf-8")
    if completed.returncode != 0:
        raise RuntimeError(f"SimC exit {completed.returncode}; see {stdout_path}: {stdout[-1500:]}")
    if re.search(r"(?im)^(?:Error:|.*Warning: Unknown option)", stdout):
        raise RuntimeError(f"SimC reported an unsupported option/error; see {stdout_path}")
    if not raw_json.is_file():
        raise RuntimeError("SimC did not create JSON output")
    parsed = parse_result(json.loads(raw_json.read_text(encoding="utf-8")), args.targets, args.seed, args.threads, args.iterations)
    if int(parsed["options"]["max_time"]) != args.duration or not parsed["options"]["fixed_time"]:
        raise ValueError("SimC duration/fixed-time settings do not match request")
    report = {
        "experiment": "official_havoc_apl_one_line_intervention",
        "intervention": args.intervention,
        "source_commit": SOURCE_COMMIT,
        "engine_sha256": ENGINE_SHA256,
        "stock_profile_sha256": PROFILE_SHA256,
        "stock_apl_sha256": APL_SHA256,
        "effective_profile_sha256": profile_hash,
        "effective_apl_sha256": apl_hash,
        "scenario": {"targets": args.targets, "duration_seconds": args.duration, "seed": args.seed, "requested_iterations": args.iterations, "threads": args.threads},
        "command": command,
        "process_elapsed_seconds": elapsed,
        "raw_simc_json": str(raw_json),
        "stdout_log": str(stdout_path),
        **parsed,
    }
    result_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simc", type=Path, required=True)
    parser.add_argument("--profile", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--intervention", choices=tuple(INTERVENTIONS), default="stock")
    parser.add_argument("--targets", type=int, choices=(1, 5), required=True)
    parser.add_argument("--duration", type=int, choices=(120, 300), default=120)
    parser.add_argument("--iterations", type=int, default=5000)
    parser.add_argument("--seed", type=int, default=20260922)
    parser.add_argument("--threads", type=int, default=2)
    parser.add_argument("--timeout", type=int, default=900)
    args = parser.parse_args()
    try:
        report = run(args)
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired, KeyError, TypeError, json.JSONDecodeError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print(json.dumps({k: report[k] for k in ("intervention", "scenario", "dps_mean", "dps_95ci_half_width_approx", "dps_sample_count", "process_elapsed_seconds")}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
