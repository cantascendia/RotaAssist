"""Produce scoped proof examples and audit existing, real simulator evidence."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from optimality_bounds import certify

ROOT=Path(__file__).resolve().parents[1]


def write(path,data):
    path.write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')


def main():
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('--output',type=Path,required=True)
    args=p.parse_args(); args.output.mkdir(parents=True,exist_ok=True)
    example={'schema':'rotaassist.return-bounds.v1','observation':'synthetic: identical public history',
             'alternatives':['burst_now','hold'],
             'worlds':[{'id':'fight_ends_soon','returns':{'burst_now':[100,100],'hold':[0,0]}},
                       {'id':'adds_arrive','returns':{'burst_now':[100,100],'hold':[180,180]}}]}
    write(args.output/'synthetic-worlds.json',example)
    report={'dataOrigin':'synthetic illustration; not WoW damage or a measured encounter',
            'uniform':certify(example)}
    example['probabilities']=['4/5','1/5']; report['explicitPrior']=certify(example)
    dominance={'schema':'rotaassist.return-bounds.v1','observation':'synthetic dominance example',
               'alternatives':['burst_now','hold'],'worlds':[
                   {'id':'high_return','returns':{'burst_now':[100,120],'hold':[80,90]}},
                   {'id':'low_return','returns':{'burst_now':[10,12],'hold':[0,9]}}]}
    write(args.output/'synthetic-dominance.json',dominance)
    report['intervalDominance']=certify(dominance)
    write(args.output/'synthetic-certificates.json',report)

    holdout=ROOT/'research/adaptive-burst/holdout.json'
    prior=json.loads(holdout.read_text(encoding='utf-8-sig')); rows=[]; verified=set()
    for hero in prior['heroes']:
        for comparison in hero['comparisons']:
            for role in ('reference','previous'):
                item=comparison[role]; raw=Path(item['raw'])
                if hashlib.sha256(raw.read_bytes()).hexdigest()!=item['rawSha256']:
                    raise ValueError('raw artifact drift: '+str(raw))
                metrics=json.loads(raw.read_text(encoding='utf-8'))['sim']['players'][0]['collected_data']['dps']
                if (metrics['mean']!=item['dps'] or metrics['mean_std_dev']!=item['standardError']
                    or metrics['count']!=item['samples']):
                    raise ValueError('summary does not match raw metrics: '+str(raw))
                profile=Path(item['command'][1])
                if hashlib.sha256(profile.read_bytes()).hexdigest()!=item['profileSha256']:
                    raise ValueError('input profile drift: '+str(profile))
                verified.add(str(raw))
            reference,previous=comparison['reference'],comparison['previous']
            rows.append({'hero':hero['hero'],'scenario':comparison['scenario'],
                         'duration':comparison['duration'],'shippedPolicySha256':hero['previousPolicySha256'],
                         'referenceMeanDps':reference['dps'],'shippedMeanDps':previous['dps'],
                         'ratio':previous['dps']/reference['dps'],
                         'meanGap':reference['dps']-previous['dps'],
                         'gapMinusThreeSESum':reference['dps']-previous['dps']-
                             3*(reference['standardError']+previous['standardError'])})
    write(args.output/'existing-benchmark-audit.json',{
        'sourceSha256':hashlib.sha256(holdout.read_bytes()).hexdigest(),
        'uniqueRawReportsVerified':len(verified),'comparisons':rows,
        'rawMetricsAndInputProfilesVerified':True,
        'boundary':'Existing offline SimC means. Three-SE screen is descriptive, not a simultaneous confidence theorem or live-game proof.',
        'maximumDPSProven':False})

    # Export actual shipped-policy witnesses, using fully readable readiness to
    # isolate rule ambiguity. These are abstract policy inputs, not combat logs.
    code=r'''local h=require("tests.helpers")
local RA,ns=h.loadAddon()
for _,path in ipairs({"Data/IndependentPolicy","Data/IndependentAldrachi","Engine/IndependentDecision","Engine/IndependentConsensus"}) do
    assert(h.loadAddonFile("addon/"..path..".lua","RotaAssist",ns))
end
local function dump(policy)
    local s={facts={},known={},ready={},charges={},bounds={fury={min=0,max=120},active_enemies={min=1}}}
    for _,r in ipairs(policy.rules) do s.known[r.spellID]=true; s.ready[r.spellID]=true end
    local r=RA:GetModule("IndependentConsensus"):Evaluate(policy,s)
    io.write("RESULT\t"..policy.heroProfile.."\t"..r.status.."\t"..tostring(r.policyInvariant).."\n")
    for index,w in ipairs(r.counterexamples) do
        io.write("WORLD\t"..index.."\t"..w.action.."\n")
        for i=1,w.count do local b=w.bounds[i]
            io.write(table.concat({"BOUND",b.key,tostring(b.min),tostring(b.max),tostring(b.minOpen),tostring(b.maxOpen)},"\t").."\n")
        end
    end
end
dump(RA.IndependentPolicy)
for _,policy in pairs(RA.IndependentPolicies) do dump(policy) end
'''
    result=subprocess.run([r'C:\Program Files (x86)\Lua\5.1\lua.exe','-e',code],cwd=ROOT,capture_output=True,text=True)
    if result.returncode: raise RuntimeError(result.stderr)
    (args.output/'shipped-policy-witnesses.tsv').write_text(result.stdout,encoding='utf-8')
    print(json.dumps({'rawReportsVerified':len(verified),'comparisons':len(rows),
                      'positiveGapScreens':sum(r['gapMinusThreeSESum']>0 for r in rows),
                      'ratiosByHero':{name:[min(r['ratio'] for r in rows if r['hero']==name),
                                           max(r['ratio'] for r in rows if r['hero']==name)]
                                      for name in sorted({r['hero'] for r in rows})}},indent=2))


if __name__=='__main__': main()
