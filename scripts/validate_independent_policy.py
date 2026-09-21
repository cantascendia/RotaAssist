"""Freeze the discovery winner then run a new, held-out seed and durations."""
import argparse
import hashlib
import json
import math
from pathlib import Path
from independent_policy import canonical
from search_independent_policy import run
from simc_bench import ENGINE_SHA256, SOURCE_COMMIT, validated_profile


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ("simc","profile","selection","output","evidence"):
        p.add_argument("--"+name, required=True, type=Path)
    args=p.parse_args()
    simc=args.simc.resolve()
    if hashlib.sha256(simc.read_bytes()).hexdigest()!=ENGINE_SHA256:
        raise ValueError("engine hash mismatch")
    base,profile_hash,_=validated_profile(args.profile,"stock")
    selection=json.loads(args.selection.read_text())
    policy=selection["candidates"][0]["policy"]
    digest=hashlib.sha256(canonical(policy)).hexdigest()
    args.evidence.mkdir(parents=True,exist_ok=True)
    frozen=args.evidence/"candidate.json"
    if frozen.exists() and canonical(json.loads(frozen.read_text()))!=canonical(policy):
        raise ValueError("holdout candidate was already frozen; cannot silently tune on this holdout")
    frozen.write_text(json.dumps(policy,indent=2)+"\n")
    results=[]
    for targets in (1,5):
        for duration in (120,300):
            stock=run(simc,base,None,args.output.resolve(),targets,duration,5000,20260925)
            own=run(simc,base,policy,args.output.resolve(),targets,duration,5000,20260925)
            delta=own["dps"]-stock["dps"]
            error=math.hypot(own["standardError"],stock["standardError"])
            results.append({"targets":targets,"duration":duration,"seed":20260925,
                "stockDps":stock["dps"],"candidateDps":own["dps"],"ratio":own["dps"]/stock["dps"],
                "delta":delta,"independentDifferenceSE":error,"deltaMinusThreeSE":delta-3*error,
                "stockSamples":stock["samples"],"candidateSamples":own["samples"],
                "stockRawSha256":stock["rawSha256"],"candidateRawSha256":own["rawSha256"],
                "stockProfileSha256":stock["profileSha256"],"candidateProfileSha256":own["profileSha256"],
                "warnings":own["warnings"]})
    report={"schema":"rotaassist.independent-holdout.v1","engineSha256":ENGINE_SHA256,
        "sourceCommit":SOURCE_COMMIT,"stockProfileSha256":profile_hash,"policySha256":digest,
        "discoveryCandidateCount":len(selection["candidates"]),
        "discoveryMinimumRatio":selection["candidates"][0]["minimumStockRatio"],
        "scenarios":results,"clearsAllBenchmarkGates":all(r["deltaMinusThreeSE"]>0 for r in results),
        "automaticReplacementQualified":False,"liveValidated":False,
        "reason":"Full-information fixed-profile benchmark does not establish live observation or personal build coverage."}
    (args.evidence/"holdout.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report,indent=2))


if __name__=="__main__":
    main()
