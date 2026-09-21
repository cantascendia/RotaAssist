"""Search own policies with pinned actual SimC; retain failed/lower DPS evidence."""
import argparse
import hashlib
import itertools
import json
import subprocess
from pathlib import Path

from independent_policy import make_policy, simc_lines, canonical
from simc_bench import ENGINE_SHA256, validated_profile, parse_result


def run(simc, base, policy, output, targets, duration, iterations, seed):
    key = hashlib.sha256(canonical(policy)).hexdigest()[:12] if policy else "stock"
    prefix = output / f"{key}-{targets}t-{duration}s-{iterations}i-{seed}"
    report_path = prefix.with_suffix(".report.json")
    text = base.decode()
    if policy:
        lines = [line for line in text.splitlines() if not line.startswith(("actions=", "actions+="))]
        text = "\n".join(lines + [""] + simc_lines(policy)) + "\n"
    profile = prefix.with_suffix(".simc")
    raw = prefix.with_suffix(".raw.json")
    command = [str(simc), str(profile), f"iterations={iterations}", f"desired_targets={targets}",
               "threads=2", "fixed_time=1", f"max_time={duration}", "vary_combat_length=0",
               f"seed={seed}", f"json2={raw}", "report_details=0"]
    cached = report_path.exists()
    if cached:
        old = json.loads(report_path.read_text())
        if (old["policy"] != policy or old["command"] != command
                or profile.read_text(encoding="utf-8") != text
                or old["profileSha256"] != hashlib.sha256(profile.read_bytes()).hexdigest()
                or old["rawSha256"] != hashlib.sha256(raw.read_bytes()).hexdigest()):
            raise ValueError("cached experiment integrity mismatch")
    else:
        profile.write_text(text, encoding="utf-8")
        process = subprocess.run(command, capture_output=True, text=True, timeout=600)
        prefix.with_suffix(".log.txt").write_text(process.stdout + process.stderr, encoding="utf-8")
        if process.returncode:
            raise RuntimeError(process.stdout[-1500:] + process.stderr[-1500:])
    data = json.loads(raw.read_text(encoding="utf-8"))
    parsed = parse_result(data, targets, seed, 2, iterations)
    if int(parsed["options"]["max_time"]) != duration or not parsed["options"]["fixed_time"]:
        raise ValueError("scenario timing mismatch")
    result = {"policyKey": key, "policy": policy, "targets": targets, "duration": duration,
              "seed": seed, "iterations": iterations, "dps": parsed["dps_mean"],
              "standardError": parsed["dps_standard_error"], "samples": parsed["dps_sample_count"],
              "profileSha256": hashlib.sha256(profile.read_bytes()).hexdigest(),
              "rawSha256": hashlib.sha256(raw.read_bytes()).hexdigest(),
              "raw": str(raw), "warnings": parsed["warnings"], "command": command}
    if cached and old != result:
        raise ValueError("cached experiment summary mismatch")
    report_path.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: result[k] for k in ["policyKey", "targets", "duration", "seed", "dps"]}), flush=True)
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--simc", type=Path, required=True)
    p.add_argument("--profile", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--pilot", action="store_true")
    p.add_argument("--family", choices=("basic", "burst", "refined"), default="basic")
    args = p.parse_args()
    simc = args.simc.resolve()
    if hashlib.sha256(simc.read_bytes()).hexdigest() != ENGINE_SHA256:
        raise ValueError("engine hash mismatch")
    base, _, _ = validated_profile(args.profile, "stock")
    output = args.output.resolve(); output.mkdir(parents=True, exist_ok=True)
    baseline = [run(simc, base, None, output, t, 120, 500, 20260924) for t in (1, 5)]
    candidates = [make_policy(burst_aware=args.family == "burst", retreat=args.family == "burst")]
    if not args.pilot:
        candidates = [make_policy(meta_gate=m, generator_limit=g, aura_first=a, hunt_first=h, break_fury=f,
                                  burst_aware=args.family == "burst", retreat=args.family == "burst")
                      for m,g,a,h,f in itertools.product((0,8), (40,70), (False,True), (False,True), (35,70))]
    if args.family == "refined":
        candidates = [make_policy(meta_gate=0, generator_limit=g, aura_first=True, hunt_first=True,
                                  break_fury=f, burst_aware=True, retreat=True,
                                  empowered_aura_expiry=e, retreat_off_gcd=o)
                      for g,f,e,o in itertools.product((40,70,100), (0,35), (None,1.5), (False,True))]
    scored = []
    for policy in candidates:
        measurements = [run(simc, base, policy, output, t, 120, 500, 20260924) for t in (1, 5)]
        ratios = [m["dps"] / b["dps"] for m,b in zip(measurements, baseline)]
        scored.append({"policy": policy, "minimumStockRatio": min(ratios), "stockRatios": ratios,
                       "measurements": measurements})
    scored.sort(key=lambda x: x["minimumStockRatio"], reverse=True)
    (output/("search-results-" + args.family + ".json")).write_text(json.dumps({"baseline": baseline, "candidates": scored}, indent=2)+"\n")
    print("BEST", scored[0]["minimumStockRatio"], scored[0]["policy"]["parameters"], flush=True)


if __name__ == "__main__":
    main()
