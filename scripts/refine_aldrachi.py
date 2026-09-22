"""Aldrachi structure search with a fresh discovery seed and frozen holdout."""
import argparse,copy,hashlib,itertools,json,math
from pathlib import Path
from benchmark_aldrachi import PROFILE_SHA
from independent_policy import canonical
from search_independent_policy import run
from simc_bench import ENGINE_SHA256,SOURCE_COMMIT,APL_SHA256,apl_bytes


def neighbors(policy):
    for i,rule in enumerate(policy["rules"]):
        if rule["action"]!="reavers_glaive":
            candidate=copy.deepcopy(policy); del candidate["rules"][i]
            candidate["parameters"]={"search":"aldrachi_structure_v2","change":"remove","index":i}
            yield candidate
        for ci,(field,op,value) in enumerate(rule["conditions"]):
            choices=(15,40,70,100) if field=="fury" else ()
            for replacement in choices:
                if replacement==value: continue
                candidate=copy.deepcopy(policy); candidate["rules"][i]["conditions"][ci][2]=replacement
                candidate["parameters"]={"search":"aldrachi_structure_v2","change":"threshold","index":i,"value":replacement}
                yield candidate
        if any(c[0] in ("buff.glaive_flurry.up","buff.rending_strike.up") for c in rule["conditions"]) and rule["action"]!="reavers_glaive":
            for count,op in ((2,">="),(1,"<=")):
                candidate=copy.deepcopy(policy); candidate["rules"][i]["conditions"].append(["active_enemies",op,count])
                candidate["parameters"]={"search":"aldrachi_structure_v2","change":"population","index":i,"count":count}
                yield candidate


def burst_neighbors(policy):
    # Diagnose lost Death Sweep damage: test burst-window priority and whether
    # early combo spenders should wait for Blade Dance's remaining cooldown.
    for first,gate in itertools.product((False,True),(0,1,2,4,8)):
        candidate=copy.deepcopy(policy)
        for rule in candidate["rules"]:
            if rule["action"] in ("annihilation","chaos_strike") and any(c[0]=="buff.rending_strike.up" for c in rule["conditions"]):
                rule["conditions"].append(["cooldown.blade_dance.remains",">",gate])
        if first:
            burst=[r for r in candidate["rules"] if any(c[0]=="debuff.essence_break.up" for c in r["conditions"])]
            other=[r for r in candidate["rules"] if r not in burst]
            candidate["rules"]=burst+other
        candidate["parameters"]={"search":"aldrachi_burst_v3","burstFirst":first,"danceGate":gate}
        yield candidate


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ("simc","profile","start","output"): p.add_argument("--"+name,type=Path,required=True)
    p.add_argument("--family",choices=("structure","burst"),default="structure")
    p.add_argument("--rounds",type=int,default=2)
    p.add_argument("--discovery-seed",type=int,default=20261018)
    p.add_argument("--holdout-seed",type=int,default=20261019)
    args=p.parse_args(); simc=args.simc.resolve(); out=args.output.resolve(); out.mkdir(parents=True,exist_ok=True)
    if hashlib.sha256(simc.read_bytes()).hexdigest()!=ENGINE_SHA256: raise ValueError("engine hash mismatch")
    base=args.profile.read_bytes().replace(b"\r\n",b"\n")
    if hashlib.sha256(base).hexdigest()!=PROFILE_SHA or hashlib.sha256(apl_bytes(base)).hexdigest()!=APL_SHA256: raise ValueError("profile drift")
    if args.discovery_seed==args.holdout_seed: raise ValueError("holdout seed must differ")
    refs=[run(simc,base,None,out,t,120,500,args.discovery_seed) for t in (1,5)]
    best=json.loads(args.start.read_text()); bestScore=0; results=[]; seen=set()
    family=neighbors if args.family=="structure" else burst_neighbors
    for round in range(args.rounds):
        for candidate in [best]+list(family(best)):
            digest=hashlib.sha256(canonical(candidate)).hexdigest()
            if digest in seen: continue
            seen.add(digest)
            rows=[run(simc,base,candidate,out,t,120,500,args.discovery_seed) for t in (1,5)]
            ratios=[a["dps"]/b["dps"] for a,b in zip(rows,refs)]
            result={"policy":candidate,"ratios":ratios,"minimumRatio":min(ratios),"measurements":rows}
            results.append(result)
            if result["minimumRatio"]>bestScore: best,bestScore=candidate,result["minimumRatio"]
        (out/"discovery.json").write_text(json.dumps({"round":round,"reference":refs,"candidates":results,"bestScore":bestScore},indent=2)+"\n")
        print("ROUND",round,"BEST",bestScore,flush=True)
    frozen=out/"candidate.json"
    if frozen.exists() and canonical(json.loads(frozen.read_text()))!=canonical(best): raise ValueError("frozen selection changed")
    frozen.write_text(json.dumps(best,indent=2)+"\n")
    comparisons=[]
    for targets in (1,2,5):
        for duration in (120,300):
            reference=run(simc,base,None,out,targets,duration,3000,args.holdout_seed)
            own=run(simc,base,best,out,targets,duration,3000,args.holdout_seed)
            delta=own["dps"]-reference["dps"]; error=(own["standardError"]+reference["standardError"])
            comparisons.append({"targets":targets,"duration":duration,"ratio":own["dps"]/reference["dps"],"delta":delta,
                                "deltaMinusThreeSESum":delta-3*error,"reference":reference,"candidate":own})
    report={"sourceCommit":SOURCE_COMMIT,"engineSha256":ENGINE_SHA256,"profileSha256":PROFILE_SHA,
            "policySha256":hashlib.sha256(canonical(best)).hexdigest(),"discoveryCandidateCount":len(results),
            "discoveryMinimumRatio":bestScore,"scenarios":comparisons,"beatsEveryReference":all(r["deltaMinusThreeSESum"]>0 for r in comparisons),
            "liveValidated":False,"automaticReplacementQualified":False}
    (out/"holdout.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps({"ratios":[r["ratio"] for r in comparisons]}),flush=True)


if __name__=="__main__": main()
