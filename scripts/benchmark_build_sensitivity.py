"""Negative control: one own hero policy is not a universal Havoc build policy."""
import argparse
import hashlib
import json
import urllib.request
from pathlib import Path
from search_independent_policy import run
from simc_bench import ENGINE_SHA256,SOURCE_COMMIT


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ("simc","output","evidence"):
        parser.add_argument("--"+name,type=Path,required=True)
    args=parser.parse_args(); args.output.mkdir(parents=True,exist_ok=True); args.evidence.mkdir(parents=True,exist_ok=True)
    simc=args.simc.resolve()
    if hashlib.sha256(simc.read_bytes()).hexdigest()!=ENGINE_SHA256: raise ValueError("engine mismatch")
    policy=json.loads(Path("research/independent-policy/candidate.json").read_text())
    results=[]
    for suffix,hero in (("","fel_scarred"),("_Aldrachi_Reaver","aldrachi_reaver")):
        name="MID2_Demon_Hunter_Havoc"+suffix+".simc"
        url=f"https://raw.githubusercontent.com/simulationcraft/simc/{SOURCE_COMMIT}/profiles/MID2/{name}"
        base=urllib.request.urlopen(url,timeout=30).read().replace(b"\r\n",b"\n")
        folder=args.output.resolve()/hero; folder.mkdir(parents=True,exist_ok=True)
        (folder/"official.simc").write_bytes(base)
        for targets in (1,5):
            stock=run(simc,base,None,folder,targets,120,2000,20261002)
            forced=run(simc,base,policy,folder,targets,120,2000,20261002)
            results.append({"heroProfile":hero,"targets":targets,"sourceUrl":url,
                "sourceProfileSha256":hashlib.sha256(base).hexdigest(),"stockDps":stock["dps"],
                "forcedPolicyDps":forced["dps"],"ratio":forced["dps"]/stock["dps"],
                "runtimeHeroCompatible":hero==policy["heroProfile"],"measurements":{"stock":stock,"forced":forced}})
    report={"negativeControl":True,"liveValidated":False,"userCharacterMeasured":False,
        "engineSha256":ENGINE_SHA256,"sourceCommit":SOURCE_COMMIT,"scenarios":results,
        "note":"Compare policies within each row only. The two upstream builds may also differ in gear."}
    (args.evidence/"build-sensitivity.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps([{k:v for k,v in r.items() if k!="measurements"} for r in results],indent=2))


if __name__=="__main__": main()
