"""0.9 authoritative contracts. Synthetic fixtures are not balance evidence."""
import pytest
from campaign_pilot import setup
from test_ui import host,client,healthy,click_name,by_name

def preparation(l,c):
 m=c.RunSystems;s=m.new(9,None,1);s.world=l.table_from({'baseX':720,'mineX':1040,'bilateral':True,'spacing':45})
 assert m.waveCleared(s,1,3);assert m.choose(s,s.offer.token,s.offer.choices[1]);return m,s

@pytest.mark.parametrize('seconds',[0,1,3,4.5,5,8,12,16,17.9])
def test_forecast_matches_actual_completed_ore(seconds):
 l,c,r,g,s=setup();m,x=preparation(l,c)
 for _ in range(round(seconds*10)):m.tickMining(x,.1)
 f=m.forecast(x);expected=f.retainedCargo+f.futureOre;before=x.goldMined
 for _ in range(230):m.tickMining(x,.1)
 assert x.phase=='combat';assert x.goldMined-before==expected
 assert x.gold==120+x.goldMined-x.spent

@pytest.mark.parametrize('seconds',[0,1,4.5,5,8,12,17.9])
def test_recall_only_retains_existing_cargo_and_rejects_replay(seconds):
 l,c,r,g,s=setup();m,x=preparation(l,c)
 for _ in range(round(seconds*10)):m.tickMining(x,.1)
 f=m.forecast(x);before=x.goldMined;token=x.prepareToken
 assert not m.recall(x,'stale')[0]
 x.paused=True;assert not m.recall(x,token)[0];x.paused=False
 assert m.recall(x,token)[0];assert not m.recall(x,token)[0]
 positions=[a.x for a in x.robots.values()];x.paused=True;m.tickMining(x,.25)
 assert positions==[a.x for a in x.robots.values()];x.paused=False
 for _ in range(40):m.tickMining(x,.1)
 assert x.phase=='combat' and not x.recalling
 assert x.goldMined-before==f.retainedCargo
 assert x.gold==120+x.goldMined-x.spent
 assert m.buy(x,'move') is True

def test_insurance_immediate_return_and_no_double_deposit():
 l,c,r,g,s=setup();m,x=preparation(l,c)
 for _ in range(45):m.tickMining(x,.1)
 x.bonus.autoUnload=1;f=m.forecast(x);before=x.goldMined
 assert f.retainedCargo>0;assert m.recall(x,x.prepareToken)[0]
 assert x.phase=='combat' and x.goldMined==before+f.retainedCargo
 for _ in range(40):m.tickMining(x,.1)
 assert x.goldMined==before+f.retainedCargo

@pytest.mark.parametrize('mode,expected',[('nearest',1),('air',2),('armor',3)])
def test_target_mode_changes_authoritative_projectile(mode,expected):
 l,c,r,g,s=setup();g.start(s,c,r)
 for i,(kind,x,y) in enumerate([('crawler',610,380),('flyer',710,40),('tank',1050,380)],1):
  s.enemies[i]=l.table_from(dict(id=i,kind=kind,x=x,y=y,hp=1000,maxHp=1000,speed=0,attack=999,burn=0))
 assert g.act(s,c,r,'target_mode',mode);g.step(s,c,r,.1)
 assert s.projectiles[1].target==expected
 assert not g.act(s,c,r,'target_mode','invalid')
 g.act(s,c,r,'pause',True);assert not g.act(s,c,r,'target_mode','air')

def test_spawn_cap_queues_instead_of_dropping_groups():
 l,c,r,g,s=setup();g.start(s,c,r);c.EnemyCap=1;s.gunClock=999
 for _ in range(250):g.step(s,c,r,.1)
 assert s.serial==1 and s.stage=='combat'
 # Remove fixture enemies one at a time, retaining all overdue authored groups.
 for _ in range(s.plan.count-1):s.enemies=l.table();g.step(s,c,r,.1)
 assert s.serial==s.plan.count and s.groupIndex>len(s.plan.groups)
 assert s.stage=='clearing'

def test_offer_and_terminal_wave_guard_and_recap():
 l,c,r,g,s=setup();g.start(s,c,r)
 for _ in range(450):
  g.step(s,c,r,.1)
  if s.supply:break
 assert s.wave==1 and s.supply.kind=='weapon' and s.elapsed<40
 assert not g.act(s,c,r,'recall',l.table_from({'token':s.run.prepareToken}))
 assert set(s.supply.options.values())=={'machine','arc','rail'}
 g.act(s,c,r,'supply',l.table_from({'token':s.supply.token,'id':'arc'}))
 assert g.act(s,c,r,'recall',l.table_from({'token':s.run.prepareToken}))
 g.step(s,c,r,.1);assert s.wave==2
 s.hull=0;g.step(s,c,r,.1)
 assert s.result.recap and s.result.recap.weaponDamage.cannon>0
 wallet=s.profile.alloy;g.step(s,c,r,.1);assert wallet==s.profile.alloy

def test_full_hull_repair_preview_and_authority_agree():
 l,c,r,g,s=setup();g.start(s,c,r);s.run.gold=10000
 ss=g.snapshot(s,c,r);assert not ss.investments.repair.canBuy and ss.investments.repair.reason=='耐久已满'
 assert not g.act(s,c,r,'buy','repair');assert s.run.gold==10000
 s.hull-=50;ss=g.snapshot(s,c,r);assert ss.investments.repair.after-ss.investments.repair.before==50
 assert g.act(s,c,r,'buy','repair');assert s.hull==s.maxHull

@pytest.mark.parametrize('fallback',[False,True])
def test_native_target_recall_and_shop_contract(fallback):
 l,t,p=host(strictAPI=True,imageDisabled=fallback,shippingOnly=True);client(t,p)
 click_name(t,p,'StartGame');click_name(t,p,'Depart');s=t.session(p).game
 click_name(t,p,'Aim_air');assert s.targetMode=='air'
 click_name(t,p,'Combat');assert not by_name(p.PlayerGui,'Buy_repair').Active
 assert '→' in by_name(p.PlayerGui,'Buy_damage').Text
 click_name(t,p,'Close')
 s.groupIndex=99;s.waveElapsed=25;t.step(.3);t.render(.1)
 click_name(t,p,'Choose_'+s.supply.options[1]);t.step(1);t.render(.1)
 click_name(t,p,'Recall');assert by_name(p.PlayerGui,'RecallQuote')
 click_name(t,p,'ConfirmRecall');t.step(.3);t.render(.1)
 assert s.run.recalling or s.wave==2
 healthy(t,p)
