"""Development-core checks. These do NOT assert integration with the shipping GUI/Core."""
from pathlib import Path
import pytest
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]

def setup(seed=7,run_id=1):
 l=LuaRuntime(unpack_returned_tuples=True)
 m=l.execute((ROOT/'next/RunSystems.lua').read_text())
 return l,m,m.new(seed,l.table(),run_id)

def choose(m,s):
 if s.offer:assert m.choose(s,s.offer.token,s.offer.choices[1])

def mine(m,s):
 while s.phase=='mining':m.tickMining(s,.1)

def test_twenty_waves_schedule_no_start_weapon_or_final_dead_choice():
 l,m,s=setup();assert len(s.weapons)==0
 relics=[];weapons=[]
 for wave in range(1,21):
  assert m.waveCleared(s,wave,20)
  if s.offer:
   (weapons if s.offer.kind=='weapon' else relics).append(wave)
   assert len(s.offer.choices)==3 and len(set(s.offer.choices.values()))==3
   choose(m,s)
  mine(m,s)
 assert weapons==[4,8,12,16] and relics==[1,5,9,13,17]
 assert s.phase=='ended' and s.offer is None and len(s.weapons)==4
 assert [v.slot for v in s.weapons.values()]==[2,3,4,5]

@pytest.mark.parametrize('last',[3,4,5,8,12,16,20])
def test_no_selection_after_last_wave(last):
 l,m,s=setup()
 for wave in range(1,last+1):
  assert m.waveCleared(s,wave,last)
  if wave==last:assert s.offer is None and s.phase=='ended'
  else:choose(m,s);mine(m,s)

@pytest.mark.parametrize('value',[0,-1,1.5,'1',float('nan'),float('inf')])
def test_invalid_wave_is_rejected(value):
 l,m,s=setup();assert not m.waveCleared(s,value,20)
 assert s.cleared==0 and s.phase=='combat'

def test_offer_pause_freezes_mining_and_invalid_choice_is_atomic():
 l,m,s=setup();m.waveCleared(s,1,20);before=(s.gold,s.miningLeft)
 for _ in range(20):m.tickMining(s,.25)
 assert (s.gold,s.miningLeft)==before
 assert not m.choose(s,s.offer.token,'forged')
 token=s.offer.token;choose(m,s);assert not m.choose(s,token,'battery')
 s.paused=True
 for _ in range(20):m.tickMining(s,.25)
 assert (s.gold,s.miningLeft)==before

def test_token_contains_run_identity_and_reroll_rejects_stale_token():
 l,m,s=setup(run_id=10);other=m.new(7,l.table(),11)
 m.waveCleared(s,1,20);m.waveCleared(other,1,20)
 old=s.offer.token;assert not m.choose(other,old,s.offer.choices[1])
 assert m.reroll(s,old);assert s.offer.token!=old and not m.choose(s,old,'battery')

def test_mining_only_creates_gold_on_actual_return():
 l,m,s=setup();m.waveCleared(s,1,20);s.offer=None # isolate physical mining, without relic modifiers
 before=s.gold
 for _ in range(20):m.tickMining(s,.1)
 assert s.gold==before and s.goldMined==0
 for _ in range(45):m.tickMining(s,.1)
 assert s.gold>before and s.gold-before==s.goldMined
 assert any(r.trips>0 for r in s.robots.values())

@pytest.mark.parametrize('id',['move','dig','cargo','robots'])
def test_four_upgrade_caps_are_enforced(id):
 l,m,s=setup();s.gold=1000000 # unit fixture budget, not a progression pilot
 for _ in range(m.upgrades[id].cap):assert m.buy(s,id) is True
 before=s.gold;assert m.price(s,id) is None and not m.buy(s,id)[0] and s.gold==before
 assert m.stats(s).robots<=6

def test_move_dig_cargo_are_independent_stats():
 l,m,s=setup();base=m.stats(s);s.gold=1000000
 m.buy(s,'move');one=m.stats(s);assert one.move>base.move and one.dig==base.dig and one.cargo==base.cargo
 m.buy(s,'dig');two=m.stats(s);assert two.move==one.move and two.dig>one.dig and two.cargo==one.cargo
 m.buy(s,'cargo');three=m.stats(s);assert three.move==two.move and three.dig==two.dig and three.cargo>two.cargo

def test_completed_drill_cargo_not_retroactively_inflated():
 l,m,s=setup();m.waveCleared(s,1,20);s.offer=None
 for _ in range(44):m.tickMining(s,.1)
 r=s.robots[1];assert r.state=='returning' and r.cargo==28
 s.gold=1000;m.buy(s,'cargo');assert r.cargo==28 and m.stats(s).cargo>28

def test_relic_is_permanent_for_run_and_resets_for_next_run():
 l,m,s=setup();m.waveCleared(s,1,20);id=s.offer.choices[1];assert m.choose(s,s.offer.token,id)
 before=dict(s.bonus.items());mine(m,s);m.waveCleared(s,2,20);mine(m,s)
 assert dict(s.bonus.items())==before and s.relics[id]
 fresh=m.new(7,l.table(),2);assert len(fresh.relics)==0 and len(fresh.weapons)==0

def test_research_graph_has_real_or_prerequisites_and_preserves_input():
 l,m,s=setup();old=l.execute((ROOT/'src/Tech.lua').read_text());w=l.execute((ROOT/'next/ResearchWeb.lua').read_text());new=w.build(old)
 assert len(new.order)==48 and len(old.nodes.fort_4.prereqs)==2
 assert len(new.nodes.fort_4.prereqs)==0 and set(new.nodes.fort_4.anyPrereqs.values())=={'fort_2','fort_3'}
 p=l.table_from({'tech':{'fort_3':True}},recursive=True)
 assert w.prerequisiteState(p,new.nodes.fort_4)[0]
 p.tech.fort_3=None;assert not w.prerequisiteState(p,new.nodes.fort_4)[0]
 # Cross-family alternative works without forcing all same-family predecessors.
 p.tech.industry_2=True;assert w.prerequisiteState(p,new.nodes.fort_5)[0]

def test_web_graph_has_no_cycles_or_overlapping_nodes_and_short_segments():
 l,m,s=setup();old=l.execute((ROOT/'src/Tech.lua').read_text());w=l.execute((ROOT/'next/ResearchWeb.lua').read_text());t=w.build(old)
 nodes=list(t.nodes.values());visited=set();stack=set()
 def dfs(id):
  assert id not in stack
  if id in visited:return
  stack.add(id);n=t.nodes[id]
  for pre in list(n.prereqs.values())+list(n.anyPrereqs.values()):dfs(pre)
  stack.remove(id);visited.add(id)
 for n in nodes:dfs(n.id)
 for i,a in enumerate(nodes):
  for b in nodes[i+1:]:assert abs(a.mapX-b.mapX)>=132 or abs(a.mapY-b.mapY)>=92
  for e in w.edges(t,a.id).values():
   if not e.portal:
    points=list(e.points.values())
    for p,q in zip(points,points[1:]):
     assert p[1]==q[1] or p[2]==q[2]
     assert abs(p[1]-q[1])+abs(p[2]-q[2])<=132
