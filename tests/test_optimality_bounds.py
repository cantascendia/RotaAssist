"""test: exact finite-table certificates, never a live-game guarantee."""
import sys
from fractions import Fraction
from pathlib import Path

import pytest
from hypothesis import given, settings, strategies as st

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from optimality_bounds import certify


def table(rows,probabilities=None):
    data={'schema':'rotaassist.return-bounds.v1','observation':'same public history',
          'alternatives':['burst_now','hold'],
          'worlds':[{'id':str(i),'returns':dict(zip(['burst_now','hold'],row))} for i,row in enumerate(rows)]}
    if probabilities is not None: data['probabilities']=probabilities
    return data


def test_indistinguishable_futures_do_not_have_a_common_best_choice():
    r=certify(table([[[100,100],[0,0]],[[100,100],[180,180]]]))
    assert r['uniformlyOptimal']==[]
    assert r['minimaxRegretAlternative']=='burst_now'
    assert r['regretUpper']=={'burst_now':'80','hold':'100'}
    assert r['exactArgmaxIntersection']==[]
    assert r['expected'] is None and r['maximumDPSProven'] is False


def test_interval_dominance_compares_within_world_and_excludes_self():
    r=certify(table([[[100,120],[80,90]],[[10,12],[0,9]]]))
    assert r['uniformlyOptimal']==['burst_now']
    assert r['regretUpper']['burst_now']=='0'
    assert r['exactArgmaxIntersection'] is None


def test_explicit_prior_changes_expected_choice_not_the_uniform_proof():
    r=certify(table([[[100,100],[0,0]],[[100,100],[180,180]]],['4/5','1/5']))
    assert r['uniformlyOptimal']==[]
    assert r['expected']['optimalWithinBounds']==['burst_now']
    assert r['expected']['intervals']['hold']==['36','36']
    assert r['maximumDPSProven'] is False


@pytest.mark.parametrize('edit',[
    lambda d:d['worlds'][0]['returns'].pop('hold'),
    lambda d:d['worlds'][0]['returns'].__setitem__('hold',[2,1]),
    lambda d:d['worlds'][0]['returns'].__setitem__('hold',[True,1]),
    lambda d:d['worlds'][0]['returns'].__setitem__('hold',[float('nan'),1]),
    lambda d:d.__setitem__('probabilities',['1/3']),
    lambda d:d.__setitem__('probabilities',['-1']),
    lambda d:d.__setitem__('alternatives',['hold','hold']),
])
def test_invalid_coverage_and_numeric_evidence_are_rejected(edit):
    d=table([[[1,1],[0,0]]]); edit(d)
    with pytest.raises(ValueError): certify(d)


@given(st.lists(st.tuples(st.integers(-100,100),st.integers(-100,100)),min_size=1,max_size=8))
@settings(max_examples=100,deadline=None)
def test_exact_table_matches_exhaustive_argmax_and_regret(rows):
    r=certify(table([[[a,a],[b,b]] for a,b in rows]))
    regrets={name:max(max(a,b)-row[j] for row in rows for a,b in [row])
             for j,name in enumerate(['burst_now','hold'])}
    assert r['regretUpper']=={k:str(v) for k,v in regrets.items()}
    assert r['uniformlyOptimal']==[a for a,v in regrets.items() if v==0]
    assert r['exactArgmaxIntersection']==r['uniformlyOptimal']


@given(st.integers(-20,20),st.integers(0,10),st.integers(-20,20),st.integers(0,10))
@settings(max_examples=60,deadline=None)
def test_reported_interval_regret_bounds_every_compatible_integer_payoff(a,width_a,b,width_b):
    r=certify(table([[[a,a+width_a],[b,b+width_b]]]))
    for x in range(a,a+width_a+1):
        for y in range(b,b+width_b+1):
            assert max(x,y)-x<=Fraction(r['regretUpper']['burst_now'])
            assert max(x,y)-y<=Fraction(r['regretUpper']['hold'])
