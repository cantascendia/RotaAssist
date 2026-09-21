"""Run an explicit baseline/current same-row replay; no DPS inference."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", required=True)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--baseline-commit", required=True)
    parser.add_argument("--trace-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--summary", type=Path, required=True)
    args = parser.parse_args()
    traces = sorted(p for p in args.trace_dir.glob("stock-full-*.raw.json")
                    if "-120s-" in p.name or "-300s-" in p.name)
    if len(traces) != 5:
        parser.error("expected the five documented 120/300-second traces")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    summary = {"schema": "rotaassist.havoc.replay-matrix.v1",
               "baselineCommit": args.baseline_commit, "rowsPerRevision": 0,
               "comparison": "same-row nil-head depth1, not Blizzard head or DPS",
               "runs": [], "pairedComparisons": []}
    totals = {}
    for trace in traces:
        paired = {}
        for label, addon in (("rc2", args.baseline), ("rc3", Path("addon"))):
            report = args.output_dir / (label + "-" + trace.stem + ".json")
            subprocess.run([args.lua, "scripts/replay_havoc.lua", str(trace),
                            str(report), "--addon-root", str(addon)], check=True,
                           capture_output=True, text=True)
            data = json.loads(report.read_text(encoding="utf-8"))
            paired[label] = data
            profiles = []
            for result in data["profileResults"]:
                keys = ("profile", "totalTraceRows", "mappedActionRows", "predictedRows",
                        "exactAgreement", "overrideEquivalentAgreement", "mismatches",
                        "noPrediction", "mappedActionAgreementRate", "predictionCoverage")
                compact = {key: result[key] for key in keys}
                compact["declaredImpossibleActions"] = len(result["impossibleActionEvidence"])
                profiles.append(compact)
                key = label + "/" + result["profile"]
                total = totals.setdefault(key, {})
                for metric in ("mappedActionRows", "predictedRows", "exactAgreement",
                               "overrideEquivalentAgreement", "noPrediction",
                               "declaredImpossibleActions"):
                    total[metric] = total.get(metric, 0) + compact[metric]
            summary["runs"].append({"revision": label, "trace": trace.as_posix(),
                "traceSha256": hashlib.sha256(trace.read_bytes()).hexdigest(),
                "report": report.as_posix(),
                "reportSha256": hashlib.sha256(report.read_bytes()).hexdigest(),
                "profiles": profiles})
            if label == "rc3":
                summary["rowsPerRevision"] += profiles[0]["totalTraceRows"]
        for baseline, current in zip(paired["rc2"]["profileResults"],
                                     paired["rc3"]["profileResults"]):
            before = {r["index"]: r for r in baseline["comparisons"]}
            after = {r["index"]: r for r in current["comparisons"]}
            common = before.keys() & after.keys()
            summary["pairedComparisons"].append({"trace": trace.as_posix(),
                "profile": current["profile"], "commonRows": len(common),
                "baselineOnlyRows": sorted(before.keys() - after.keys()),
                "currentOnlyRows": sorted(after.keys() - before.keys()),
                "changedPredictionRows": sum(before[i]["predictedSpellID"] !=
                                             after[i]["predictedSpellID"] for i in common)})
    summary["totals"] = totals
    summary["limitations"] = data["unresolvedFields"]
    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(totals, indent=2))


if __name__ == "__main__":
    main()
