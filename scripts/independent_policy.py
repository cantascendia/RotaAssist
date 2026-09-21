"""Own declarative Havoc policy: shared source for SimC experiments and Lua export."""
from __future__ import annotations

import json


def make_policy(meta_gate=8, break_gate=4, generator_limit=70, aura_first=False,
                hunt_first=False, break_fury=35, burst_aware=False, retreat=False,
                empowered_aura_expiry=None, retreat_off_gcd=False):
    def rule(action, spell, cost=0, conditions=(), form=None):
        return {"action": action, "spellID": spell, "cost": cost,
                "conditions": list(conditions), "form": form}

    rules = [rule("metamorphosis", 191427, conditions=[
        ["cooldown.eye_beam.remains", ">", meta_gate],
        ["cooldown.blade_dance.remains", ">", 0]])]
    hunt = rule("the_hunt", 370965)
    aura = rule("immolation_aura", 258920, conditions=[["charges", ">=", 2]])
    if aura_first:
        rules.insert(0, aura)
    else:
        rules.append(aura)
    if hunt_first:
        rules.append(hunt)
    rules.extend([
        rule("eye_beam", 198013, 30),
        rule("essence_break", 258860, conditions=[
            ["cooldown.eye_beam.remains", ">", break_gate], ["fury", ">=", break_fury]]),
        rule("death_sweep", 210152, 35, form="meta"),
        rule("blade_dance", 188499, 35, form="normal"),
    ])
    if not hunt_first:
        rules.append(hunt)
    rules.extend([
        rule("felblade", 232893, conditions=[["fury", "<=", generator_limit]]),
        rule("annihilation", 201427, 40, form="meta"),
        rule("chaos_strike", 162794, 40, form="normal"),
        rule("immolation_aura", 258920),
        rule("felblade", 232893),
    ])
    if burst_aware:
        # Own hypothesis: consume pending empowered casts before opening another
        # window; prioritize attacks while the target damage window is active.
        burst = [
            rule("essence_break", 258860, conditions=[
                ["action.death_sweep.demonsurge_available", ">", 0], ["fury", ">=", break_fury]]),
            rule("essence_break", 258860, conditions=[
                ["action.annihilation.demonsurge_available", ">", 0], ["fury", ">=", break_fury]]),
            rule("death_sweep", 210152, 35, conditions=[["debuff.essence_break.up", ">", 0]], form="meta"),
            rule("annihilation", 201427, 40, conditions=[["debuff.essence_break.up", ">", 0]], form="meta"),
            rule("death_sweep", 210152, 35, conditions=[["action.death_sweep.demonsurge_available", ">", 0]], form="meta"),
            rule("annihilation", 201427, 40, conditions=[["action.annihilation.demonsurge_available", ">", 0]], form="meta"),
            rule("immolation_aura", 258920, conditions=[["action.immolation_aura.demonsurge_available", ">", 0]]),
            rule("felblade", 232893, conditions=[["buff.inertia_trigger.up", ">", 0]]),
        ]
        rules = burst + rules
        if empowered_aura_expiry is not None:
            burst[6]["conditions"].append(["buff.demonsurge.remains", "<", empowered_aura_expiry])
    if retreat:
        rules.insert(0, rule("vengeful_retreat", 198793, conditions=[
            ["buff.initiative.up", "==", 0], ["cooldown.eye_beam.remains", "<", 2]]))
        if retreat_off_gcd:
            rules[0]["offGCD"] = True
    params = dict(meta_gate=meta_gate, break_gate=break_gate, generator_limit=generator_limit,
                  aura_first=aura_first, hunt_first=hunt_first, break_fury=break_fury,
                  burst_aware=burst_aware, retreat=retreat,
                  empowered_aura_expiry=empowered_aura_expiry, retreat_off_gcd=retreat_off_gcd)
    return {"schema": "rotaassist.independent-policy.v1", "specID": 577,
            "heroProfile": "fel_scarred", "parameters": params, "rules": rules}


def simc_lines(policy):
    """Items/consumables stay identical in the external benchmark envelope."""
    lines = ["actions=auto_attack", "actions+=/call_action_list,name=items"]
    for rule in policy["rules"]:
        conditions = [f"({field}{op}{value})" for field, op, value in rule["conditions"]]
        # Explicit form predicates are part of both evaluators' semantics.
        if rule["form"]:
            conditions.append("buff.metamorphosis.up" if rule["form"] == "meta" else "buff.metamorphosis.down")
        line = "actions+=/" + rule["action"]
        if rule.get("offGCD"):
            line += ",use_off_gcd=1"
        if conditions:
            line += ",if=" + "&".join(conditions)
        lines.append(line)
    return lines


def canonical(policy):
    return json.dumps(policy, sort_keys=True, separators=(",", ":")).encode()
