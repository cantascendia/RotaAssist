"""Diagnose rc.5 losses by removing reference-only actions, without policy tuning."""
import argparse
import hashlib
import json
from pathlib import Path

from independent_policy import canonical
from search_independent_policy import run
from simc_bench import ENGINE_SHA256, validated_profile


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ("simc", "profile", "policy", "output", "report"):
        p.add_argument("--"+name, type=Path, required=True)
    args=p.parse_args()
    engine=args.simc.resolve()
    if hashlib.sha256(engine.read_bytes()).hexdigest()!=ENGINE_SHA256:
        raise ValueError("engine pin mismatch")
    base,base_hash,_=validated_profile(args.profile,"stock")
    policy=json.loads(args.policy.read_text())
    removals={"full":(),"no_retarget":("retarget_auto_attack",),
              "no_fragment_pickup":("pick_up_fragment",),
              "neither":("retarget_auto_attack","pick_up_fragment")}
    expected={"retarget_auto_attack":2,"pick_up_fragment":1}
    report={"engineSha256":ENGINE_SHA256,"stockProfileSha256":base_hash,
            "policySha256":hashlib.sha256(canonical(policy)).hexdigest(),
            "purpose":"diagnostic ablation; no policy selection or performance qualification",
            "scenarios":[]}
    for targets in (1,5):
        for duration in (120,300):
            row={"targets":targets,"duration":duration,"seed":20260925,"references":{}}
            for label,actions in removals.items():
                lines=base.decode().splitlines()
                for action in actions:
                    prefix="actions+=/"+action+","
                    if sum(line.startswith(prefix) for line in lines)!=expected[action]:
                        raise ValueError("reference intervention anchor drift: "+action)
                    lines=[line for line in lines if not line.startswith(prefix)]
                effective=("\n".join(lines)+"\n").encode()
                folder=args.output.resolve()/label; folder.mkdir(parents=True,exist_ok=True)
                result=run(engine,effective,None,folder,targets,duration,5000,20260925)
                row["references"][label]={k:result[k] for k in ("dps","standardError","samples","rawSha256","profileSha256","warnings")}
            folder=args.output.resolve()/"own"; folder.mkdir(parents=True,exist_ok=True)
            result=run(engine,base,policy,folder,targets,duration,5000,20260925)
            row["own"]={k:result[k] for k in ("dps","standardError","samples","rawSha256","profileSha256")}
            row["ownVsFullPercent"]=(result["dps"]/row["references"]["full"]["dps"]-1)*100
            row["ownVsNeitherPercent"]=(result["dps"]/row["references"]["neither"]["dps"]-1)*100
            report["scenarios"].append(row)
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps([{k:r[k] for k in ("targets","duration","ownVsFullPercent","ownVsNeitherPercent")} for r in report["scenarios"]],indent=2))


if __name__=="__main__": main()
