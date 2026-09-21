"""Freeze a refinement winner and compare against old own policy plus stock."""
import argparse
import hashlib
import json
from pathlib import Path

from independent_policy import canonical
from search_independent_policy import run
from simc_bench import ENGINE_SHA256, SOURCE_COMMIT, validated_profile

SCENARIOS=((1,120),(1,300),(3,180),(5,120),(5,300),(8,180))


def difference(own, reference):
    delta=own["dps"]-reference["dps"]
    # Shared seeds can correlate streams. Sum of marginal SEs is conservative
    # for arbitrary covariance, unlike assuming independent samples.
    uncertainty=3*(own["standardError"]+reference["standardError"])
    return {"ratio":own["dps"]/reference["dps"],"delta":delta,
            "deltaMinusThreeSESum":delta-uncertainty,"deltaPlusThreeSESum":delta+uncertainty}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ("simc","profile","selection","previous","output","evidence"):
        parser.add_argument("--"+name,type=Path,required=True)
    parser.add_argument("--seed",type=int,default=20260928)
    args=parser.parse_args()
    simc=args.simc.resolve(); output=args.output.resolve()
    output.mkdir(parents=True,exist_ok=True); args.evidence.mkdir(parents=True,exist_ok=True)
    if hashlib.sha256(simc.read_bytes()).hexdigest()!=ENGINE_SHA256:
        raise ValueError("engine hash mismatch")
    base,profile_hash,_=validated_profile(args.profile,"stock")
    selection=json.loads(args.selection.read_text())
    policy=selection["candidates"][0]["policy"]
    previous=json.loads(args.previous.read_text())
    frozen=args.evidence/"candidate.json"
    if frozen.exists() and canonical(json.loads(frozen.read_text()))!=canonical(policy):
        raise ValueError("candidate already frozen for this holdout")
    frozen.write_text(json.dumps(policy,indent=2)+"\n")
    scenarios=[]
    for targets,duration in SCENARIOS:
        measurements={name:run(simc,base,candidate,output,targets,duration,5000,args.seed)
                      for name,candidate in (("stock",None),("previous",previous),("candidate",policy))}
        scenarios.append({"targets":targets,"duration":duration,"seed":args.seed,
                          "vsPrevious":difference(measurements["candidate"],measurements["previous"]),
                          "vsStock":difference(measurements["candidate"],measurements["stock"]),
                          "measurements":measurements})
    report={"schema":"rotaassist.refinement-holdout.v1","engineSha256":ENGINE_SHA256,
            "sourceCommit":SOURCE_COMMIT,"stockProfileSha256":profile_hash,
            "policySha256":hashlib.sha256(canonical(policy)).hexdigest(),
            "previousPolicySha256":hashlib.sha256(canonical(previous)).hexdigest(),
            "discoveryCandidates":len(selection["candidates"]),"scenarios":scenarios,
            "clearsEveryPreviousPolicyGate":all(s["vsPrevious"]["deltaMinusThreeSESum"]>0 for s in scenarios),
            "clearsEveryStockGate":all(s["vsStock"]["deltaMinusThreeSESum"]>0 for s in scenarios),
            "liveValidated":False,"maximumDpsEstablished":False}
    (args.evidence/"holdout.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps({k:v for k,v in report.items() if k!="scenarios"},indent=2),flush=True)


if __name__=="__main__": main()
