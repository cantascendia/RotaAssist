"""Compose mutually exclusive elapsed-time phases from two own policies."""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
from independent_policy import canonical


def compose(early,late,switch=120):
    if isinstance(switch,bool) or not isinstance(switch,(int,float)) or not math.isfinite(switch) or switch<=0:
        raise ValueError("switch must be positive finite seconds")
    for key in ("schema","specID","heroProfile"):
        if early[key]!=late[key]: raise ValueError("incompatible policy context")
    combined=copy.deepcopy(early)
    combined["rules"]=[]
    for source,op in ((early,"<"),(late,">=")):
        for original in source["rules"]:
            rule=copy.deepcopy(original)
            rule["conditions"].insert(0,["time",op,switch])
            combined["rules"].append(rule)
    if len(combined["rules"])>64 or any(len(r["conditions"])>16 for r in combined["rules"]):
        raise ValueError("composed policy exceeds runtime limits")
    combined["parameters"]={"composition":"elapsed_time_phases_v1","switchSeconds":switch,
        "earlySha256":hashlib.sha256(canonical(early)).hexdigest(),
        "lateSha256":hashlib.sha256(canonical(late)).hexdigest()}
    return combined


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ("early","late","output"):
        parser.add_argument("--"+name,required=True,type=Path)
    args=parser.parse_args()
    policy=compose(json.loads(args.early.read_text()),json.loads(args.late.read_text()))
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps({"candidates":[{"policy":policy}],"predeclaredSwitchSeconds":120},indent=2)+"\n")


if __name__=="__main__": main()
