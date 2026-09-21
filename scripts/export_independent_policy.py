"""Serialize an own research policy identically for the Lua observer and SimC."""
import argparse
import hashlib
import json
import math
from pathlib import Path
from independent_policy import canonical


def lua(value):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        if not math.isfinite(value):
            raise ValueError("nonfinite policy data")
        return repr(value)
    if isinstance(value, str):
        # JSON's \u escape is not supported by Lua 5.1. Policy names are ASCII.
        if not value.isascii() or any(ord(c)<32 for c in value):
            raise ValueError("non-ASCII/control policy string")
        return json.dumps(value)
    if isinstance(value, list):
        return "{" + ",".join(map(lua, value)) + "}"
    if isinstance(value, dict):
        return "{" + ",".join("["+lua(k)+"]="+lua(v) for k,v in sorted(value.items())) + "}"
    raise ValueError("unsupported policy value")


def export(policy):
    digest = hashlib.sha256(canonical(policy)).hexdigest()
    return ("-- Generated own research policy. Observation only; not performance qualified.\n"
            "-- 自主策略研究：仅观测，未通过性能替换门槛。\n"
            "local _, NS = ...\nlocal policy = " + lua(policy) + "\n"
            'policy.policySha256 = "' + digest + '"\n'
            "NS.RA.IndependentPolicy = policy\n")


if __name__ == "__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("policy", type=Path)
    p.add_argument("output", type=Path)
    args=p.parse_args()
    args.output.write_text(export(json.loads(args.policy.read_text())), encoding="utf-8")
