"""Local search over own policy ordering; discovery data never qualify release."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

from independent_policy import canonical
from search_independent_policy import run
from simc_bench import ENGINE_SHA256, validated_profile


def neighbors(policy):
    # Move each rule by one place, and each unconditioned cooldown to the front.
    # These are generic search operators, not a transcription of an upstream APL.
    for index in range(len(policy["rules"])):
        for destination in sorted({0, max(0,index-1), min(len(policy["rules"])-1,index+1)}):
            if index == destination:
                continue
            candidate = copy.deepcopy(policy)
            rule = candidate["rules"].pop(index)
            candidate["rules"].insert(destination, rule)
            candidate["parameters"] = {"search": "rule_relocation"}
            yield candidate
    # Explicit AoE hypothesis: spend aura charges before ordinary resource dumps.
    for position in (0, 8, len(policy["rules"])-3):
        candidate = copy.deepcopy(policy)
        candidate["rules"].insert(position, {"action":"immolation_aura", "spellID":258920,
            "cost":0, "form":None, "conditions":[["active_enemies", ">=", 2]]})
        candidate["parameters"] = {"search":"aoe_aura"}
        yield candidate


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simc", required=True, type=Path)
    parser.add_argument("--profile", required=True, type=Path)
    parser.add_argument("--start", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--rounds", type=int, default=2)
    args = parser.parse_args()
    simc, output = args.simc.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if hashlib.sha256(simc.read_bytes()).hexdigest() != ENGINE_SHA256:
        raise ValueError("engine hash mismatch")
    base, _, _ = validated_profile(args.profile, "stock")
    baseline = [run(simc, base, None, output, t,120,500,20260924) for t in (1,5)]
    best = json.loads(args.start.read_text())["candidates"][0]["policy"]
    visited, results, rounds = set(), [], []
    score = -1
    for iteration in range(args.rounds):
        for policy in [best] + list(neighbors(best)):
            digest = hashlib.sha256(canonical(policy)).hexdigest()
            if digest in visited:
                continue
            visited.add(digest)
            measurements = [run(simc,base,policy,output,t,120,500,20260924) for t in (1,5)]
            ratios = [m["dps"]/b["dps"] for m,b in zip(measurements,baseline)]
            item = {"policy":policy, "minimumStockRatio":min(ratios), "stockRatios":ratios,
                    "measurements":measurements}
            results.append(item)
            if min(ratios) > score:
                best, score = policy, min(ratios)
        rounds.append({"round":iteration, "bestRatio":score})
        results.sort(key=lambda x:x["minimumStockRatio"], reverse=True)
        (output/"order-search.json").write_text(json.dumps({"baseline":baseline,"rounds":rounds,"candidates":results},indent=2)+"\n")
        print("ROUND", iteration, score, flush=True)


if __name__ == "__main__":
    main()
