"""Compare addon cast-derived flags with actual pinned SimC debug traces, not DPS."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

from export_independent_policy import lua
from simc_bench import ENGINE_SHA256, SOURCE_COMMIT, validated_profile

ROOT=Path(__file__).resolve().parents[1]
BUFFS={"demonsurge_annihilation":0,"demonsurge_death_sweep":1,"demonsurge_consuming_fire":2}
SPELLS={"metamorphosis":191427,"eye_beam":198013,"abyssal_gaze":452497,
        "annihilation":201427,"death_sweep":210152,"immolation_aura":258920,
        "chaos_strike":162794,"blade_dance":188499}
EVENT=re.compile(r"^(\d+\.\d+) Player '([^']+)' (.*)$")
ACTION=re.compile(r"performs Action '([^']+)' \((\d+)\)")
BUFF=re.compile(r"(gains|loses) Buff '([^']+)'")


def parse_trace(text):
    flags=[0,0,0]; meta=False; rows=[]; row=None; actor=None
    for line in text.splitlines():
        match=EVENT.match(line)
        if not match: continue
        stamp,name,body=match.groups(); action=ACTION.match(body); buff=BUFF.match(body)
        if action and action[1] not in SPELLS: action=None
        if buff and buff[2] not in (*BUFFS,"metamorphosis"): buff=None
        if not action and not buff: continue
        if actor is None: actor=name
        if name!=actor: raise ValueError("mixed actors in mechanic trace")
        time=float(stamp)
        if row is None or time!=row["time"]:
            if row is not None:
                if time<row["time"]: raise ValueError("nonmonotonic trace")
                row["expected"]=flags.copy(); row["meta"]=meta; rows.append(row)
            row={"time":time,"casts":[]}
        if action:
            if int(action[2])!=SPELLS[action[1]]: raise ValueError("trace action ID drift")
            row["casts"].append(int(action[2]))
        if buff:
            active=buff[1]=="gains"
            if buff[2]=="metamorphosis": meta=active
            else: flags[BUFFS[buff[2]]]=int(active)
    if row is not None:
        row["expected"]=flags.copy(); row["meta"]=meta; rows.append(row)
    if not rows or not any(191427 in r["casts"] for r in rows): raise ValueError("missing manual Meta in trace")
    return rows


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ("simc","profile","output"): p.add_argument("--"+name,type=Path,required=True)
    args=p.parse_args(); simc=args.simc.resolve(); out=args.output.resolve(); out.mkdir(parents=True,exist_ok=True)
    if hashlib.sha256(simc.read_bytes()).hexdigest()!=ENGINE_SHA256: raise ValueError("engine hash mismatch")
    base,profile_hash,_=validated_profile(args.profile,"stock")
    profile=out/"reference.simc"; profile.write_bytes(base)
    results=[]
    for targets in (1,5):
        for seed in (20261012,20261013):
            prefix=out/f"trace-{targets}t-{seed}"; log=prefix.with_suffix(".log")
            command=[str(simc),str(profile),"iterations=1","threads=1","fixed_time=1","max_time=180",
                     "vary_combat_length=0",f"desired_targets={targets}",f"seed={seed}","debug=1",f"output={log}"]
            run=subprocess.run(command,capture_output=True,text=True,timeout=120)
            prefix.with_suffix(".stdout.txt").write_text(run.stdout+run.stderr,encoding="utf-8")
            if run.returncode: raise RuntimeError(run.stdout+run.stderr)
            rows=parse_trace(log.read_text(encoding="utf-8"))
            replay=prefix.with_suffix(".lua"); replay.write_text("return "+lua(rows)+"\n",encoding="utf-8")
            prefix.with_suffix(".json").write_text(json.dumps(rows,indent=2)+"\n")
            checked=subprocess.run([r"C:\Program Files (x86)\Lua\5.1\lua.exe","scripts/replay_havoc_surge.lua",str(replay)],
                                   cwd=ROOT,capture_output=True,text=True)
            if checked.returncode: raise RuntimeError(checked.stdout+checked.stderr)
            match=re.fullmatch(r"checked=(\d+) unknown=(\d+) samples=(\d+) model=(\d+) public=(\d+)\s*",checked.stdout)
            if not match: raise ValueError("unexpected replay output")
            result={"targets":targets,"seed":seed,"duration":180,"iterations":1,
                    "checked":int(match[1]),"unknown":int(match[2]),"samples":int(match[3]),
                    "castModelChecked":int(match[4]),"publicAbsenceChecked":int(match[5]),
                    "traceSha256":hashlib.sha256(log.read_bytes()).hexdigest(),
                    "fixtureSha256":hashlib.sha256(prefix.with_suffix('.json').read_bytes()).hexdigest(),"command":command}
            results.append(result); print(json.dumps(result),flush=True)
    report={"sourceCommit":SOURCE_COMMIT,"engineSha256":ENGINE_SHA256,"profileSha256":profile_hash,
            "runs":results,"liveValidated":False,"dpsGainMeasured":False,
            "limitation":"Simulator event replay supplies readable Meta; it does not validate live event order or restricted APIs."}
    (out/"verification.json").write_text(json.dumps(report,indent=2)+"\n")


if __name__=="__main__": main()
