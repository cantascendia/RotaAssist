"""Own Aldrachi policy hypotheses, built from our existing Havoc action vocabulary."""
import copy


def make_policy(fel, combo_order="sweep", reaver_gate="both", meta_gate=8):
    policy=copy.deepcopy(fel)
    policy["heroProfile"]="aldrachi_reaver"
    policy["requiredTalent"]=442290
    policy["parameters"]={"family":"aldrachi_v1","comboOrder":combo_order,"reaverGate":reaver_gate,"metaGate":meta_gate}
    # Remove Fel-Scarred-only surge conditions; retain our own baseline envelope.
    rules=[r for r in policy["rules"] if not any("demonsurge" in c[0] for c in r["conditions"])]
    for rule in rules:
        if rule["action"]=="metamorphosis": rule["conditions"][0][2]=meta_gate
        if rule["action"]=="the_hunt": rule["conditions"].append(["buff.reavers_glaive.up","==",0])
    reaver={"action":"reavers_glaive","spellID":442294,"cost":0,"form":None,
            "conditions":[["buff.reavers_glaive.up",">",0]]}
    if reaver_gate in ("both","rending"): reaver["conditions"].append(["buff.rending_strike.up","==",0])
    if reaver_gate=="both": reaver["conditions"].append(["buff.glaive_flurry.up","==",0])
    sweep=[{"action":action,"spellID":id,"cost":35,"form":form,
            "conditions":[["buff.glaive_flurry.up",">",0]]}
           for action,id,form in (("death_sweep",210152,"meta"),("blade_dance",188499,"normal"))]
    strike=[{"action":action,"spellID":id,"cost":40,"form":form,
             "conditions":[["buff.rending_strike.up",">",0]]}
            for action,id,form in (("annihilation",201427,"meta"),("chaos_strike",162794,"normal"))]
    policy["rules"]=[reaver]+(sweep+strike if combo_order=="sweep" else strike+sweep)+rules
    return policy
