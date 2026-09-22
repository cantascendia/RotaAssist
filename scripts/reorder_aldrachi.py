"""Search skill ordering, verify finalists, then freeze before a new holdout."""
import argparse,copy,hashlib,json,math
from pathlib import Path
from benchmark_aldrachi import PROFILE_SHA
from independent_policy import canonical
from search_independent_policy import run
from simc_bench import ENGINE_SHA256,SOURCE_COMMIT,APL_SHA256,apl_bytes


def ordering_neighbors(policy):
    size=len(policy["rules"])
    for i in range(size):
        for j in sorted({0,3,6,10,size-1}):
            if i==j: continue
            candidate=copy.deepcopy(policy)
            rule=candidate["rules"].pop(i); candidate["rules"].insert(j,rule)
            candidate["parameters"]={"search":"aldrachi_order_v4"}
            yield candidate


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ("simc","profile","start","output"): p.add_argument("--"+name,type=Path,required=True)
    args=p.parse_args(); simc=args.simc.resolve(); out=args.output.resolve(); out.mkdir(parents=True,exist_ok=True)
    if hashlib.sha256(simc.read_bytes()).hexdigest()!=ENGINE_SHA256: raise ValueError("engine drift")
    base=args.profile.read_bytes().replace(b"\r\n",b"\n")
    if hashlib.sha256(base).hexdigest()!=PROFILE_SHA or hashlib.sha256(apl_bytes(base)).hexdigest()!=APL_SHA256: raise ValueError("profile drift")
    def measure(policy,iterations,seed): return [run(simc,base,policy,out,t,120,iterations,seed) for t in (1,5)]
    reference=measure(None,150,20261025); best=json.loads(args.start.read_text()); bestScore=0; results=[]; seen=set()
    for round in range(2):
        for policy in [best]+list(ordering_neighbors(best)):
            key=hashlib.sha256(canonical(policy)).hexdigest()
            if key in seen: continue
            seen.add(key); rows=measure(policy,150,20261025)
            ratios=[a["dps"]/b["dps"] for a,b in zip(rows,reference)]
            result={"policy":policy,"ratios":ratios,"minimumRatio":min(ratios),"measurements":rows}; results.append(result)
            if result["minimumRatio"]>bestScore: best,bestScore=policy,result["minimumRatio"]
        (out/"screen.json").write_text(json.dumps({"round":round,"reference":reference,"candidates":results},indent=2)+"\n")
        print("ROUND",round,"BEST",bestScore,flush=True)
    reference=measure(None,1000,20261026); finalists=[]
    for candidate in sorted(results,key=lambda r:r["minimumRatio"],reverse=True)[:8]:
        rows=measure(candidate["policy"],1000,20261026); ratios=[a["dps"]/b["dps"] for a,b in zip(rows,reference)]
        finalists.append({"policy":candidate["policy"],"minimumRatio":min(ratios),"ratios":ratios,"measurements":rows})
    winner=max(finalists,key=lambda r:r["minimumRatio"]); best=winner["policy"]
    frozen=out/"candidate.json"
    if frozen.exists() and canonical(json.loads(frozen.read_text()))!=canonical(best): raise ValueError("frozen selection changed")
    frozen.write_text(json.dumps(best,indent=2)+"\n")
    (out/"finalists.json").write_text(json.dumps({"reference":reference,"candidates":finalists},indent=2)+"\n")
    scenarios=[]
    for targets in (1,2,5):
        for duration in (120,300):
            ref=run(simc,base,None,out,targets,duration,3000,20261027)
            own=run(simc,base,best,out,targets,duration,3000,20261027)
            delta=own["dps"]-ref["dps"]; error=(own["standardError"]+ref["standardError"])
            scenarios.append({"targets":targets,"duration":duration,"ratio":own["dps"]/ref["dps"],"delta":delta,
                "deltaMinusThreeSESum":delta-3*error,"reference":ref,"candidate":own})
    report={"sourceCommit":SOURCE_COMMIT,"engineSha256":ENGINE_SHA256,"profileSha256":PROFILE_SHA,
        "policySha256":hashlib.sha256(canonical(best)).hexdigest(),"discoveryCandidateCount":len(results),
        "discoveryMinimumRatio":winner["minimumRatio"],"scenarios":scenarios,
        "beatsEveryReference":all(r["deltaMinusThreeSESum"]>0 for r in scenarios),"liveValidated":False,"automaticReplacementQualified":False}
    (out/"holdout.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps({"ratios":[r["ratio"] for r in scenarios]}),flush=True)


if __name__=="__main__": main()
