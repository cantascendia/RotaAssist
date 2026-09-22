"""Exact, conditional return-table certificates; not a WoW damage model."""
from __future__ import annotations

import argparse
import json
from fractions import Fraction
from pathlib import Path


def rational(value):
    # Reject float rounding, NaNs, infinities and bool-as-int evidence.
    if type(value) not in (str,int):
        raise ValueError('bounds and probabilities require exact integers or rational strings')
    try:
        return Fraction(value)
    except (ValueError,ZeroDivisionError) as exc:
        raise ValueError('invalid rational') from exc


def regret(rows,alternatives):
    return {a:max([Fraction(0)]+[row[b][1]-row[a][0] for row in rows
                               for b in alternatives if b!=a]) for a in alternatives}


def certify(data):
    if not isinstance(data,dict) or data.get('schema')!='rotaassist.return-bounds.v1':
        raise ValueError('invalid schema')
    alternatives=data.get('alternatives'); worlds=data.get('worlds')
    if (not isinstance(alternatives,list) or not 1<=len(alternatives)<=64
        or any(not isinstance(a,str) or not a for a in alternatives)
        or len(set(alternatives))!=len(alternatives)):
        raise ValueError('invalid alternatives')
    if not isinstance(worlds,list) or not 1<=len(worlds)<=256:
        raise ValueError('invalid worlds')
    if not isinstance(data.get('observation'),str) or not data['observation']:
        raise ValueError('explicit common observation required')
    rows=[]; seen=set()
    for world in worlds:
        if not isinstance(world,dict) or not isinstance(world.get('id'),str) or world['id'] in seen:
            raise ValueError('invalid world identity')
        seen.add(world['id'])
        returns=world.get('returns')
        if not isinstance(returns,dict) or set(returns)!=set(alternatives):
            raise ValueError('incomplete alternative coverage')
        row={}
        for action in alternatives:
            interval=returns[action]
            if not isinstance(interval,list) or len(interval)!=2:
                raise ValueError('interval needs lower and upper bounds')
            lo,hi=map(rational,interval)
            if lo>hi: raise ValueError('inverted interval')
            row[action]=(lo,hi)
        rows.append(row)
    upper=regret(rows,alternatives)
    exact=all(lo==hi for row in rows for lo,hi in row.values())
    argmax=None
    if exact:
        argmax=[a for a in alternatives if all(row[a][0]==max(v[0] for v in row.values()) for row in rows)]
    result={'schema':'rotaassist.return-certificate.v1','proofScope':'supplied_return_table_only',
            'observation':data['observation'],'worlds':len(worlds),
            'regretUpper':{a:str(v) for a,v in upper.items()},
            'uniformlyOptimal':[a for a,v in upper.items() if v==0],
            'minimaxRegretAlternative':min(alternatives,key=upper.get),
            'exactArgmaxIntersection':argmax,'expected':None,
            'maximumDPSProven':False,'worldCoverageValidated':False,
            'boundValidityValidated':False,'policyAdmissibilityValidated':False}
    if 'probabilities' in data:
        probabilities=data['probabilities']
        if not isinstance(probabilities,list) or len(probabilities)!=len(rows):
            raise ValueError('one explicit probability per world required')
        weights=list(map(rational,probabilities))
        if any(p<0 for p in weights) or sum(weights)!=1:
            raise ValueError('probabilities must be nonnegative and sum exactly to one')
        average={a:tuple(sum(p*row[a][i] for p,row in zip(weights,rows)) for i in (0,1))
                 for a in alternatives}
        expected_upper=regret([average],alternatives)
        result['expected']={'scope':'supplied_alternatives_and_prior_only',
            'intervals':{a:[str(v) for v in pair] for a,pair in average.items()},
            'regretUpper':{a:str(v) for a,v in expected_upper.items()},
            'optimalWithinBounds':[a for a,v in expected_upper.items() if v==0]}
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input',type=Path); parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    result=certify(json.loads(args.input.read_text(encoding='utf-8-sig')))
    rendered=json.dumps(result,indent=2,ensure_ascii=False)+'\n'
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(rendered,encoding='utf-8')
    else: print(rendered,end='')


if __name__=='__main__': main()
