"""0.7 integration contracts. Synthetic fixtures are isolated from the ordinary campaign pilot."""
import pytest
from campaign_pilot import setup,run
from test_ui import host,client,healthy

@pytest.mark.parametrize('last',range(3,21))
def test_completed_wave_schedule_and_free_drafts(last):
 l,c,r,g,s=setup();m=c.RunSystems;run=m.new(17,None,1)
 for wave in range(1,last+1):
  run.phase='combat';assert m.waveCleared(run,wave,last)
  expected=None if wave==last else 'weapon' if wave in (4,8,12,16) else 'relic' if wave in (1,5,9,13,17) else None
  assert (run.offer.kind if run.offer else None)==expected
  if run.offer:
   assert len(set(run.offer.choices.values()))==3
   old=run.gold;token=run.offer.token;pick=run.offer.choices[1]
   assert not m.choose(run,'stale',pick)
   assert m.choose(run,token,pick);assert run.gold==old
   assert not m.choose(run,token,pick)
 assert run.phase=='ended' and not run.offer
 assert len(run.weapons)==sum(w<last for w in (4,8,12,16))

def test_beginner_buffer_then_growth():
 l,c,r,g,s=setup()
 assert len(c.Catalog.campaign)==24
 for i in range(1,5):assert c.Catalog.campaign[i].hp==1
 for i in range(5,25):assert c.Catalog.campaign[i].hp>c.Catalog.campaign[i-1].hp
 assert c.Catalog.campaign[24].waves==20

def test_migration_is_idempotent_and_preserves_three_wallets():
 l,c,r,g,s=setup();p=r.cleanProfile(l.table_from({'schema':6,'alloy':123,'research':14,'crystals':23,'cores':2,'bestWave':12,'campaignCleared':9,'tech':{'energy_2':True}},recursive=True))
 assert (p.schema,p.alloy,p.research,p.crystals,p.cores,p.bestWave,p.campaignCleared)==(7,123,60,0,2,12,9)
 q=r.cleanProfile(p);assert q.research==60 and q.tech.energy_2

def test_alternative_and_cross_family_research_routes():
 l,c,r,g,s=setup();n=c.Tech.nodes.industry_5
 assert len(n.prereqs)==0 and len(n.anyPrereqs)==3
 for pre in n.anyPrereqs.values():
  p=r.cleanProfile(None);p.tech[pre]=True
  ready,_,mode=c.ResearchWeb.prerequisiteState(p,n);assert ready
 for id in c.Tech.order.values():
  for edge in c.ResearchWeb.edges(c.Tech,id).values():
   if not edge.portal:
    for i in range(1,len(edge.points)):
     a,b=edge.points[i],edge.points[i+1];assert a[1]==b[1] or a[2]==b[2]

def test_robot_actual_positions_deposits_only_and_four_caps():
 l,c,r,g,s=setup();m=c.RunSystems;x=m.new(1,None,1);x.world=l.table_from({'baseX':720,'mineX':1040,'spacing':45,'y':435})
 assert m.waveCleared(x,1,3);m.choose(x,x.offer.token,x.offer.choices[1]);assert x.robots[1].x==720
 old=x.gold;m.tickMining(x,.1);assert x.gold==old and x.robots[1].x>720
 for _ in range(299):m.tickMining(x,.1)
 assert x.goldMined>0 and x.gold==120+x.goldMined and x.phase=='combat'
 x.gold=1000000 # Cap validation only, not a balance pilot.
 for id,d in m.upgrades.items():
  for _ in range(d.cap):assert m.buy(x,id)
  assert m.buy(x,id)[0] is False
 assert m.stats(x).robots==6

def test_pause_offer_and_zero_hull_do_not_advance_or_resurrect():
 l,c,r,g,s=setup();assert g.start(s,c,r)
 g.act(s,c,r,'pause',True);g.step(s,c,r,.1);assert s.elapsed==0
 g.act(s,c,r,'pause',False);s.upgrades.regen=5;s.hull=0;g.step(s,c,r,.1)
 assert s.phase=='ended' and not s.result.won
 wallet=(s.profile.alloy,s.profile.research,s.profile.cores);g.step(s,c,r,.1)
 assert wallet==(s.profile.alloy,s.profile.research,s.profile.cores)

def test_robot_gold_ledger_and_main_only_start():
 l,c,r,g,s=setup();g.start(s,c,r)
 assert sum(bool(x.enabled) for x in g.snapshot(s,c,r).weaponSlots.values())==1
 for _ in range(300):g.step(s,c,r,.1)
 assert s.kills>0 and s.totalMined==0 and s.ore==120
 assert s.run.gold==120+s.run.goldMined-s.run.spent

@pytest.mark.parametrize('weapon',['machine','arc','rail','flame','mortar'])
def test_four_auxiliary_clocks_fire_independently(weapon):
 l,c,r,g,s=setup();g.start(s,c,r)
 for i in range(1,5):s.run.weapons[i]=l.table_from({'slot':i+1,'weapon':weapon,'cooldown':0})
 s.enemies[1]=l.table_from({'id':91,'kind':'tank','x':800,'y':390,'hp':100000,'maxHp':100000,'speed':0,'attack':99,'burn':0})
 g.step(s,c,r,.1)
 slots={e.slot for e in s.events.values() if e.kind=='shot'}
 assert slots=={1,2,3,4,5}
 assert all(s.run.weapons[i].cooldown>0 for i in range(1,5))

def test_three_reward_roles_and_core_first_clear_only():
 l,c,r,g,s=setup();e=c.Economy
 for i in range(1,25):
  n=c.Catalog.campaign[i];first=e.reward(n,True,True,n.waves,10);again=e.reward(n,True,False,n.waves,10)
  assert first.alloy>again.alloy>0 and first.research>again.research>0
  assert first.cores==(1 if i in (8,16,24) else 0) and again.cores==0
  failed=e.reward(n,False,False,2,10);assert failed.cores==0 and failed.alloy>0
 kinds={n.kind for n in c.Tech.nodes.values()};assert kinds=={'basic','function','ultimate'}

def test_ordinary_full_campaign_without_resource_injection():
 rows=run();assert len(rows)==24 and all(r['won'] for r in rows)

@pytest.mark.parametrize('touch',[False,True])
def test_actual_new_client_pages_battle_draft_and_mining(touch):
 l,t,p=host();client(t,p,touch);healthy(t,p)
 t.click(p,'研究网络');healthy(t,p)
 t.click(p,'返回前哨');t.click(p,'出发 · 第 1 关')
 for _ in range(600):
  t.step(.1);t.render(.1)
  s=t.session(p).game
  if s.supply:break
 assert s.supply and s.supply.kind=='relic'
 # Three equal captions: first choice is fine; server checks the offer token/id.
 t.click(p,'免费选择')
 for _ in range(80):t.step(.1);t.render(.1)
 assert s.totalMined>0
 t.click(p,'采矿投资');healthy(t,p);t.click(p,'返回战场')
 t.click(p,'设置');healthy(t,p);t.click(p,'返回');healthy(t,p)
 assert not s.paused
