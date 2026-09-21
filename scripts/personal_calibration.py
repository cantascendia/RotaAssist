"""Character-specific, reproducible Havoc policy comparison (offline only)."""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from pathlib import Path

from independent_policy import canonical
from search_independent_policy import run
from simc_bench import ENGINE_SHA256, SOURCE_COMMIT, validated_profile, apl_bytes

SLOTS = tuple("head neck shoulders back chest wrists hands waist legs feet finger1 finger2 trinket1 trinket2 main_hand off_hand".split())
GEAR_KEYS = set("id bonus_id gem_id enchant_id crafted_stats ilevel context crafted_bonus_id gem_bonus_id drop_level content_tuning redirected_base_stats".split())
METADATA = {"source", "origin", "server", "region"}
FIELDS = {"demonhunter", "spec", "level", "race", "role", "position", "talents", "omnium_talents",
          "potion", "flask", "food", "augmentation", "temporary_enchant", "professions"}


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def gear(value: str) -> dict[str, str]:
    parts = value.split(",")
    if not re.fullmatch(r"[a-z0-9_]*", parts[0]):
        raise ValueError("invalid equipment name")
    fields = {}
    for part in parts[1:]:
        key, separator, val = part.partition("=")
        if not separator or key not in GEAR_KEYS or key in fields or not re.fullmatch(r"[0-9]+(?:[/:][0-9]+)*", val):
            raise ValueError("unsupported or duplicate equipment modifier: " + key)
        fields[key] = val
    if not fields.get("id", "0").isdigit() or int(fields.get("id", "0")) <= 0:
        raise ValueError("equipment requires a positive item ID")
    return fields


def character_export(text: str) -> tuple[bytes, dict]:
    if len(text) > 200_000 or "\x00" in text:
        raise ValueError("invalid character export size/content")
    values, equipment = {}, {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, separator, value = line.partition("=")
        if not separator or key in values or key in equipment:
            raise ValueError("invalid or duplicate profile field: " + key)
        if key in METADATA:
            continue
        if key in SLOTS or key in ("shirt", "tabard"):
            equipment[key] = gear(value)
            continue
        if key not in FIELDS:
            raise ValueError("unsupported profile field: " + key)
        if key == "demonhunter":
            value = "RotaAssistCharacter"
        elif key == "talents":
            if not re.fullmatch(r"[A-Za-z0-9+/=]{10,4096}", value):
                raise ValueError("invalid talent import string")
        elif not re.fullmatch(r"[a-z0-9_:/=]+", value):
            raise ValueError("invalid profile value: " + key)
        values[key] = value
    if values.get("spec") != "havoc" or values.get("level") != "90" or "demonhunter" not in values:
        raise ValueError("this version requires one level-90 Havoc character")
    if not values.get("race") or not values.get("talents") or set(SLOTS) - equipment.keys():
        raise ValueError("incomplete character: race, talents and all 16 combat slots are required")
    if values.get("role", "attack") != "attack" or values.get("position", "back") != "back":
        raise ValueError("this version measures role=attack and position=back")
    values.update(role="attack", position="back")
    lines = ["demonhunter=RotaAssistCharacter"]
    lines += [key + "=" + value for key, value in sorted(values.items()) if key != "demonhunter"]
    lines += [slot + "=," + ",".join(key + "=" + val for key, val in sorted(fields.items()))
              for slot, fields in sorted(equipment.items())]
    normalized = ("\n".join(lines) + "\n").encode()
    return normalized, {"fields": values, "equipment": equipment, "sha256": digest(normalized)}


def verify_character(raw: dict, identity: dict) -> None:
    player = raw["sim"]["players"][0]
    for field in ("race", "level", "talents"):
        if str(player.get(field)) != identity["fields"][field]:
            raise ValueError("simulated character mismatch: " + field)
    for slot, expected in identity["equipment"].items():
        actual = gear(player.get("gear", {}).get(slot, {}).get("encoded_item", ""))
        if any(actual.get(key) != value for key, value in expected.items()):
            raise ValueError("simulated equipment mismatch: " + slot)


def candidates(frozen: dict) -> list[dict]:
    result = [frozen]
    for threshold in (25, 55, 70, 90):
        changed = copy.deepcopy(frozen)
        matches = 0
        for rule in changed["rules"]:
            if rule["action"] == "felblade":
                for condition in rule["conditions"]:
                    if condition[:2] == ["fury", "<="]:
                        condition[2] = threshold
                        matches += 1
        if matches != 1:
            raise ValueError("frozen policy threshold anchor drift")
        changed["parameters"] = {"personalGeneratorThreshold": threshold}
        result.append(changed)
    return result


def difference(own: dict, reference: dict) -> dict:
    delta = own["dps"] - reference["dps"]
    margin = 3 * (own["standardError"] + reference["standardError"])
    return {"ratio": own["dps"] / reference["dps"], "delta": delta,
            "lowerDelta": delta - margin, "upperDelta": delta + margin}


def select_candidate(discovery: list, baselines: list) -> dict:
    return max(discovery, key=lambda item: min(measure["dps"] / baseline["dps"]
               for measure, baseline in zip(item["measurements"], baselines)))


def compare(args) -> Path:
    if not 100 <= args.iterations <= 10000 or not args.iterations <= args.verify_iterations <= 20000:
        raise ValueError("iterations must be 100..10000; verification must be discovery..20000")
    if args.seed == args.holdout_seed:
        raise ValueError("discovery and holdout seeds must differ")
    scenarios = []
    for scenario in args.scenarios.split(","):
        target, duration = map(int, scenario.split(":"))
        if not 1 <= target <= 20 or not 30 <= duration <= 600 or (target, duration) in scenarios:
            raise ValueError("invalid or duplicate scenario")
        scenarios.append((target, duration))
    if not 1 <= len(scenarios) <= 6:
        raise ValueError("one to six scenarios required")
    engine = args.simc.resolve(strict=True)
    if digest(engine.read_bytes()) != ENGINE_SHA256:
        raise ValueError("pinned SimC executable hash mismatch")
    normalized, identity = character_export(args.profile.read_text(encoding="utf-8-sig"))
    reference, _, _ = validated_profile(args.reference, "stock")
    base = normalized + b"\n" + apl_bytes(reference)
    policy = json.loads(args.policy.read_text(encoding="utf-8-sig"))
    # Fixed family is bundled and checked before any external execution.
    if digest(canonical(policy)) != "5ce0425925b2979bf757ebce0d62c1bdb36afc41f72c765912ba4a8fe532de81":
        raise ValueError("frozen policy hash mismatch")
    family = candidates(policy)
    experiment = {"schema": "rotaassist.personal-calibration.v1", "characterSha256": identity["sha256"],
                  "engineSha256": ENGINE_SHA256, "baseSha256": digest(base), "scenarios": scenarios,
                  "discoverySeed": args.seed, "holdoutSeed": args.holdout_seed,
                  "iterations": args.iterations, "verificationIterations": args.verify_iterations,
                  "candidateSha256s": [digest(canonical(p)) for p in family]}
    folder = args.output.resolve() / digest(canonical(experiment))[:24]
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "experiment.json").write_text(json.dumps(experiment, indent=2) + "\n")
    (folder / "character.simc").write_bytes(normalized)

    def measure(candidate, seed, iterations):
        rows = []
        for target, duration in scenarios:
            row = run(engine, base, candidate, folder, target, duration, iterations, seed)
            verify_character(json.loads(Path(row["raw"]).read_text(encoding="utf-8")), identity)
            rows.append(row)
        return rows

    baselines = measure(None, args.seed, args.iterations)
    discovery = [{"policy": candidate, "measurements": measure(candidate, args.seed, args.iterations)} for candidate in family]
    selected = select_candidate(discovery, baselines)
    # Frozen selection exists before any holdout run, with its discovery evidence.
    (folder / "selection.json").write_text(json.dumps({"selected": selected, "discovery": discovery,
        "reference": baselines}, indent=2) + "\n")
    reference_holdout = measure(None, args.holdout_seed, args.verify_iterations)
    candidate_holdout = measure(selected["policy"], args.holdout_seed, args.verify_iterations)
    comparisons = [difference(own, stock) for own, stock in zip(candidate_holdout, reference_holdout)]
    clears = all(row["lowerDelta"] > 0 for row in comparisons)
    reference_raw = json.loads(Path(reference_holdout[0]["raw"]).read_text(encoding="utf-8"))
    modeled_stats = reference_raw["sim"]["players"][0].get("collected_data", {}).get("buffed_stats", {})
    report = {**experiment, "sourceCommit": SOURCE_COMMIT, "identity": identity,
              "selectedPolicySha256": digest(canonical(selected["policy"])),
              "candidateClearsEveryReferenceGate": clears,
              "conclusion": "candidate_improved_tested_scenarios" if clears else "reference_not_reliably_beaten",
              "holdoutReference": reference_holdout, "holdoutCandidate": candidate_holdout,
              "comparisons": comparisons, "modeledBuffedStats": modeled_stats,
              "liveValidated": False, "runtimePolicyInstalled": False,
              "maximumDpsEstablished": False}
    (folder / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    lines = ["# 角色配置循环对比（离线）", "", "角色指纹：`" + identity["sha256"] + "`", "",
             "| 敌人数 | 时长 | 参考 DPS | 候选 DPS | 相对差异 | 保守差值区间 |",
             "|---|---|---|---|---|---|"]
    for scenario, stock, own, delta in zip(scenarios, reference_holdout, candidate_holdout, comparisons):
        lines.append(f"| {scenario[0]} | {scenario[1]} 秒 | {stock['dps']:.1f} | {own['dps']:.1f} | {(delta['ratio']-1)*100:+.2f}% | {delta['lowerDelta']:+.1f} 至 {delta['upperDelta']:+.1f} |")
    lines += ["", "候选在全部测试场景通过保守改善门槛。" if clears else "候选没有在全部测试场景可靠超过参考循环。",
              "", "参考循环使用固定 SimC APL 与导入的角色装备/天赋。比较的是完整信息、固定目标数的模拟战斗。",
              "只搜索了 5 个自主候选，不代表全局最高输出；没有将结果安装为游戏内策略，也没有验证实战。",
              "区间为差值加减 3 倍双方标准误之和，不是严格置信区间。请查看 JSON 中的引擎警告和原始输出。"]
    if modeled_stats:
        lines += ["", "## 参考模拟的增益后属性快照（非游戏实测）", "", "```json",
                  json.dumps(modeled_stats, indent=2), "```"]
    (folder / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return folder


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ("profile", "simc", "reference", "policy", "output"):
        parser.add_argument("--" + key, type=Path, required=True)
    parser.add_argument("--iterations", type=int, default=500)
    parser.add_argument("--verify-iterations", type=int, default=2000)
    parser.add_argument("--scenarios", default="1:120,5:120,5:300")
    parser.add_argument("--seed", type=int, default=20261003)
    parser.add_argument("--holdout-seed", type=int, default=20261004)
    args = parser.parse_args()
    print("REPORT: " + str(compare(args)), flush=True)


if __name__ == "__main__":
    main()
