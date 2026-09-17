"""Audit fixes: executable bug reproductions and operation-count budgets (not Roblox FPS)."""
import pytest
from campaign_pilot import setup
from test_ui import host,client,healthy,by_name


def prep_mining(l,c,r,g,s):
 g.start(s,c,r);s.waveElapsed=25;s.enemies=l.table();s.projectiles=l.table();g.step(s,c,r,.1)
 assert s.supply

@pytest.mark.parametrize('value',[None,False,'1',0,float('nan')])
def test_malformed_node_does_not_default_to_one(value):
 l,c,r,g,s=setup();assert not g.start(s,c,r,l.table_from({'node':value}));assert s.profile.runSerial==0

def test_abandon_cannot_resurrect_robots_in_snapshot():
 l,c,r,g,s=setup();prep_mining(l,c,r,g,s)
 assert len(s.run.robots)>0
 assert g.act(s,c,r,'abandon','confirm')
 ss=g.snapshot(s,c,r);assert len(ss.robots)==0 and len(s.run.robots)==0 and not ss.supply

def test_offer_blocks_all_investments_atomically():
 l,c,r,g,s=setup();prep_mining(l,c,r,g,s)
 s.run.gold=9999
 for id in ['move','dig','cargo','robots','damage','repair','rate','armor']:
  before=s.run.gold;assert not g.act(s,c,r,'buy',id);assert s.run.gold==before

def test_paid_reroll_ledger_matches_wallet():
 l,c,r,g,s=setup();prep_mining(l,c,r,g,s)
 for _ in range(2):assert g.act(s,c,r,'reroll',s.supply.token)
 assert s.run.spent==80 and s.ore==40 and s.ledger.spent==80

def test_permanent_robot_bonus_caps_the_displayed_price():
 l,c,r,g,s=setup();s.profile.tech.industry_3=True;s.profile.tech.industry_6=True;g.start(s,c,r);s.run.gold=9999
 assert g.act(s,c,r,'buy','robots');assert g.act(s,c,r,'buy','robots')
 ss=g.snapshot(s,c,r);assert ss.stats.robots==6 and ss.prices.robots is False
 assert not g.act(s,c,r,'buy','robots')

def enemy(l,id,x,y,hp=1000):
 return l.table_from({'id':id,'kind':'tank','x':x,'y':y,'hp':hp,'maxHp':hp,'speed':0,'attack':999,'burn':0})

def test_rail_cannot_hit_beyond_its_range_and_uses_nearest_three():
 l,c,r,g,s=setup();g.start(s,c,r);s.gunClock=99
 # Sorted-in-reverse storage order must not select the farthest three.
 for i,x in enumerate([1800,1100,1000,900,800],1):s.enemies[i]=enemy(l,i,x,340)
 s.projectiles[1]=l.table_from({'id':1,'weapon':'rail','x':720,'y':340,'tx':1100,'ty':340,'born':0,'age':0,'duration':.1,'damage':10,'target':2})
 g.step(s,c,r,.1)
 assert s.enemies[1].hp==1000 and s.enemies[2].hp==1000
 assert all(s.enemies[i].hp==990 for i in [3,4,5])

def test_mortar_targets_highest_health_in_range():
 l,c,r,g,s=setup();g.start(s,c,r);s.gunClock=99
 s.run.weapons[1]=l.table_from({'slot':2,'weapon':'mortar','cooldown':0})
 s.enemies[1]=enemy(l,1,800,390,100);s.enemies[2]=enemy(l,2,1000,390,1000)
 g.step(s,c,r,.1);assert s.projectiles[1].target==2

def test_research_classification_uses_current_effects():
 l,c,r,g,s=setup();assert c.Tech.nodes.energy_2.kind=='basic'
 assert c.Tech.nodes.industry_3.kind=='function' and c.Tech.nodes.industry_8.kind=='ultimate'
 assert l.eval('function(a,b) return a==b end')(c.Supplies,c.Catalog.supplies)

@pytest.mark.parametrize('touch',[False,True])
def test_offer_settings_can_resume_and_accept(touch):
 l,t,p=host(strictAPI=True);client(t,p,touch);t.click(p,'出发 · 第 1 关')
 s=t.session(p).game;s.waveElapsed=25;s.enemies=l.table();s.projectiles=l.table();t.step(.2);t.render(.1)
 assert s.supply
 # Simulate focus auto-pause while draft is visible; modal must expose resume.
 t.action(p,'pause',True);t.render(.1);t.click(p,'继续远征');t.click(p,'免费选择');healthy(t,p)
 assert not s.paused and not s.supply

def test_cloud_read_failure_has_real_retry_and_explicit_guest_controls():
 l,t,p=host(cloud=True,constructorError=True);client(t,p)
 assert t.session(p).profile.blocked
 assert by_name(p.PlayerGui,'RetryLoad') and by_name(p.PlayerGui,'Guest')
 t.click(p,'确认访客试玩（不保存）');healthy(t,p)
 assert t.session(p).profile.mode=='guest' and not t.session(p).profile.persistent

@pytest.mark.parametrize('fallback',[False,True])
def test_idle_ui_has_no_instance_churn_and_bounded_assignments(fallback):
 l,t,p=host(imageDisabled=fallback);client(t,p)
 for _ in range(60):t.render(1/60)
 before=(t.counters.instances,t.counters.destroyed,t.counters.assignments)
 for _ in range(180):t.render(1/60)
 assert t.counters.instances==before[0] and t.counters.destroyed==before[1]
 assert t.counters.assignments-before[2]<80
 healthy(t,p)

def test_gold_updates_preserve_investment_buttons():
 l,t,p=host();client(t,p);t.click(p,'出发 · 第 1 关');t.click(p,'采矿投资')
 s=t.session(p).game;b=by_name(p.PlayerGui,'Buy_robots');old=t.counters.destroyed
 for i in range(10):
  s.run.gold+=100;t.action(p,'ready');t.render(.1)
 assert t.counters.destroyed==old
 assert l.eval('function(a,b) return a==b end')(b,by_name(p.PlayerGui,'Buy_robots'))
 assert b.Active;healthy(t,p)

def test_ready_report_happens_after_render_not_initial_network():
 from pathlib import Path
 l,t,p=host(clientFrames=0);t.enableClient(p,(Path(__file__).parents[1]/'src/Client.client.lua').read_text(),False)
 assert not t.session(p).telemetry.uiReady
 t.render(1/60);assert not p.PlayerGui.GetAttribute(p.PlayerGui,'FrontierGameReady')
 t.render(1/60);assert p.PlayerGui.GetAttribute(p.PlayerGui,'FrontierGameReady') and t.session(p).telemetry.uiReady

@pytest.mark.parametrize('fallback',[False,True])
def test_shipped_module_graph_and_all_current_pages(fallback):
 from test_ui import click_name
 l,t,p=host(shippingOnly=True,strictAPI=True,imageDisabled=fallback);client(t,p,True)
 for label in ['研究网络','返回前哨','远征图鉴','返回','设置']:
  t.click(p,label);healthy(t,p)
 before=t.session(p).game.profile.settings.sfx
 click_name(t,p,'Less_sfx');assert t.session(p).game.profile.settings.sfx<before
 t.click(p,'返回');t.click(p,'出发 · 第 1 关');t.click(p,'战斗投资');t.click(p,'返回战场')
 for _ in range(100):t.step(.1);t.render(.1)
 healthy(t,p)

def test_paid_reroll_requires_confirmation_and_stale_token_is_rejected():
 l,t,p=host();client(t,p);t.click(p,'出发 · 第 1 关');s=t.session(p).game
 s.waveElapsed=25;s.enemies=l.table();s.projectiles=l.table();t.step(.2);t.render(.1)
 t.click(p,'重抽 · 0 金矿');old=s.supply.token
 t.click(p,'重抽 · 80 金矿');assert s.ore==120 and s.supply.token==old
 t.click(p,'确认重抽');assert s.ore==40 and s.supply.token!=old
 healthy(t,p)

def test_wave_report_uses_effective_damage_and_per_wave_kills():
 l,c,r,g,s=setup();g.start(s,c,r)
 s.enemies[1]=enemy(l,1,800,340,1);s.gunClock=99
 s.projectiles[1]=l.table_from({'id':1,'weapon':'machine','x':720,'y':340,'tx':800,'ty':340,'born':0,'age':0,'duration':.1,'damage':1000,'target':1})
 s.waveElapsed=25;g.step(s,c,r,.1)
 assert len(s.reports)==1 and s.reports[1].kills==1 and s.reports[1].damage==1 and s.reports[1].best=='machine'

def test_talent_refund_is_saved_without_waiting_for_autosave():
 l,t,p=host(cloud=True);s=t.session(p);s.game.profile.tech.energy_8=True
 t.action(p,'refund_talent','energy_8')
 assert not t.db['u_42'].data.tech.energy_8
 assert t.db['u_42'].data.cores==1 and t.db['u_42'].data.alloy==650
