"""Threshold/structure refinement of our own policy with pinned real SimC."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

from independent_policy import canonical
from search_independent_policy import run
from simc_bench import ENGINE_SHA256, validated_profile


def neighbors(policy):
    """Generic mutations; does not read or transcribe the reference APL."""
    for index, rule in enumerate(policy["rules"]):
        for ci, (field, op, value) in enumerate(rule["conditions"]):
            values = ([0, 15, 25, 35, 40, 55, 70, 90, 100] if field == "fury"
                      else [0, 1, 2, 4, 8, 12] if field.startswith("cooldown.") else [])
            for replacement in values:
                if replacement == value:
                    continue
                candidate = copy.deepcopy(policy)
                candidate["rules"][index]["conditions"][ci][2] = replacement
                candidate["parameters"] = {"search": "threshold_structure_v1"}
                yield candidate
        if rule["conditions"]:
            candidate = copy.deepcopy(policy)
            del candidate["rules"][index]
            candidate["parameters"] = {"search": "threshold_structure_v1"}
            yield candidate
        if rule["action"] == "vengeful_retreat":
            candidate = copy.deepcopy(policy)
            candidate["rules"][index]["offGCD"] = not rule.get("offGCD", False)
            candidate["parameters"] = {"search": "threshold_structure_v1"}
            yield candidate
    # Only actions already present in our policy; promote by enemy-count hypothesis.
    for action in ("immolation_aura", "eye_beam", "the_hunt"):
        source = next(r for r in policy["rules"] if r["action"] == action and not r["conditions"])
        for index in (0, len(policy["rules"]) // 2, len(policy["rules"]) - 3):
            candidate = copy.deepcopy(policy)
            promoted = copy.deepcopy(source)
            promoted["conditions"] = [["active_enemies", ">=", 2]]
            candidate["rules"].insert(index, promoted)
            candidate["parameters"] = {"search": "threshold_structure_v1"}
            yield candidate


def score(measurements, baselines):
    if len(measurements) != len(baselines) or not measurements:
        raise ValueError("scenario count mismatch")
    ratios = []
    for own, ref in zip(measurements, baselines):
        if (own["targets"], own["duration"]) != (ref["targets"], ref["duration"]):
            raise ValueError("scenario identity mismatch")
        ratios.append(own["dps"] / ref["dps"])
    return min(ratios), ratios


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("simc", "profile", "start", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--rounds", type=int, default=2)
    parser.add_argument("--iterations", type=int, default=500)
    args = parser.parse_args()
    simc, output = args.simc.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if hashlib.sha256(simc.read_bytes()).hexdigest() != ENGINE_SHA256:
        raise ValueError("engine hash mismatch")
    base, profile_hash, _ = validated_profile(args.profile, "stock")
    baseline = [run(simc, base, None, output, t, 300, args.iterations, 20260927) for t in (1, 5)]
    best = json.loads(args.start.read_text())
    visited, results, rounds = set(), [], []
    best_score = -1
    for iteration in range(args.rounds):
        for policy in [best] + list(neighbors(best)):
            key = hashlib.sha256(canonical(policy)).hexdigest()
            if key in visited:
                continue
            visited.add(key)
            measurements = [run(simc, base, policy, output, t, 300, args.iterations, 20260927) for t in (1, 5)]
            worst, ratios = score(measurements, baseline)
            results.append({"policy": policy, "minimumStockRatio": worst, "stockRatios": ratios,
                            "measurements": measurements})
            if worst > best_score:
                best, best_score = policy, worst
        rounds.append({"round": iteration, "bestRatio": best_score})
        results.sort(key=lambda r: r["minimumStockRatio"], reverse=True)
        report = {"discoveryOnly": True, "profileSha256": profile_hash, "baseline": baseline,
                  "rounds": rounds, "candidates": results}
        (output / "refinement.json").write_text(json.dumps(report, indent=2) + "\n")
        print("ROUND", iteration, best_score, "CANDIDATES", len(results), flush=True)


if __name__ == "__main__":
    main()
