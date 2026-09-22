"""Select and freeze an own Aldrachi policy using pinned actual SimC comparisons."""
import argparse,hashlib,itertools,json,math
from pathlib import Path
from aldrachi_policy import make_policy
from independent_policy import canonical
from search_independent_policy import run
from simc_bench import ENGINE_SHA256,SOURCE_COMMIT,APL_SHA256,apl_bytes

PROFILE_SHA="ee729fafbd70047213098bf77b0db7a0d33d350472f5de816cf4bfefed0031df"


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ("simc","profile","fel","output"): parser.add_argument("--"+name,type=Path,required=True)
    args=parser.parse_args(); simc=args.simc.resolve(); out=args.output.resolve(); out.mkdir(parents=True,exist_ok=True)
    if hashlib.sha256(simc.read_bytes()).hexdigest()!=ENGINE_SHA256: raise ValueError("engine hash mismatch")
    base=args.profile.read_bytes().replace(b"\r\n",b"\n")
    if hashlib.sha256(base).hexdigest()!=PROFILE_SHA or hashlib.sha256(apl_bytes(base)).hexdigest()!=APL_SHA256:
        raise ValueError("Aldrachi profile/APL hash mismatch")
    fel=json.loads(args.fel.read_text()); targets=(1,5)
    baseline=[run(simc,base,None,out,t,120,500,20261016) for t in targets]
    negative=[run(simc,base,fel,out,t,120,500,20261016) for t in targets]
    candidates=[]
    for order,gate,meta in itertools.product(("sweep","strike"),("both","rending","none"),(0,8)):
        policy=make_policy(fel,order,gate,meta)
        results=[run(simc,base,policy,out,t,120,500,20261016) for t in targets]
        ratios=[a["dps"]/b["dps"] for a,b in zip(results,baseline)]
        candidates.append({"policy":policy,"measurements":results,"ratios":ratios,"minimumRatio":min(ratios)})
    selected=max(candidates,key=lambda row:row["minimumRatio"])
    frozen=out/"candidate.json"; policy=selected["policy"]
    if frozen.exists() and canonical(json.loads(frozen.read_text()))!=canonical(policy): raise ValueError("frozen selection changed")
    frozen.write_text(json.dumps(policy,indent=2)+"\n")
    discovery={"reference":baseline,"mismatchedFel":negative,"candidates":candidates,"selected":selected}
    (out/"discovery.json").write_text(json.dumps(discovery,indent=2)+"\n")
    holdout=[]
    for count,duration in itertools.product((1,2,5),(120,300)):
        reference=run(simc,base,None,out,count,duration,3000,20261017)
        own=run(simc,base,policy,out,count,duration,3000,20261017)
        delta=own["dps"]-reference["dps"]; error=(own["standardError"]+reference["standardError"])
        holdout.append({"targets":count,"duration":duration,"ratio":own["dps"]/reference["dps"],
                        "delta":delta,"deltaMinusThreeSESum":delta-3*error,"reference":reference,"candidate":own})
    report={"sourceCommit":SOURCE_COMMIT,"engineSha256":ENGINE_SHA256,"profileSha256":PROFILE_SHA,
            "policySha256":hashlib.sha256(canonical(policy)).hexdigest(),"discoveryCandidateCount":len(candidates),
            "discoveryMinimumRatio":selected["minimumRatio"],"scenarios":holdout,
            "beatsEveryReference":all(r["deltaMinusThreeSESum"]>0 for r in holdout),
            "liveValidated":False,"automaticReplacementQualified":False}
    (out/"holdout.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps({"selected":policy["parameters"],"ratios":[r["ratio"] for r in holdout]}),flush=True)


if __name__=="__main__": main()
