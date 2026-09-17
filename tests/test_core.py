from pathlib import Path
import math, json, xml.etree.ElementTree as ET
import pytest
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]

@pytest.fixture
def env():
 l=LuaRuntime(unpack_returned_tuples=True)
 c=l.execute((ROOT/'src/Config.lua').read_text());r=l.execute((ROOT/'src/Rules.lua').read_text());g=l.execute((ROOT/'src/Core.lua').read_text())
 c.Tech=l.execute((ROOT/'src/Tech.lua').read_text());c.Catalog=l.execute((ROOT/'src/Catalog.lua').read_text())
 for name in ['RunSystems','ResearchWeb','Economy']:c[name]=l.execute((ROOT/('src/'+name+'.lua')).read_text())
 s=g.new(c,r,r.cleanProfile(None));return l,c,r,g,s

def table(l,**kw):return l.table_from(kw)
def run(c,r,g,s,seconds):
 for _ in range(round(seconds*10)):g.step(s,c,r,.1)
def start(env):
 l,c,r,g,s=env;assert g.start(s,c,r);return l,c,r,g,s
def mining(env,wave=1):
 l,c,r,g,s=env
 if s.phase!='running':g.start(s,c,r)
 s.wave=wave;s.waveElapsed=c.WaveDuration;s.enemies=l.table();s.projectiles=l.table();g.step(s,c,r,.1)
 assert s.stage=='mining' and s.breakLeft==30 and s.supply
 return l,c,r,g,s
def accept(env,id=None):
 l,c,r,g,s=env;assert g.act(s,c,r,'supply',table(l,token=s.supply.token,id=id or s.supply.options[1]))
def enemy(l,id=1,kind='crawler',x=1000,hp=1000,y=420):
 return table(l,id=id,kind=kind,x=x,y=y,hp=hp,maxHp=hp,speed=0,attack=100,burn=0,spawnAt=0,attackAt=-100,hitAt=-100)

def test_menu_and_start_no_combat_mining(env):
 l,c,r,g,s=env;run(c,r,g,s,10);assert s.phase=='menu' and s.ore==0
 g.start(s,c,r);run(c,r,g,s,1);assert s.ore==120 and s.totalMined==0 and len(s.robots)==0
 assert not g.start(s,c,r)

@pytest.mark.parametrize('action,value',[('buy','fake'),('research','fake'),('supply','ammo'),('decision','leave'),('loadout','laser'),('move',1),('pause','yes'),('pause',None),('abandon',None)])
def test_invalid_actions_atomic(env,action,value):
 l,c,r,g,s=start(env);old=s.ore;assert not g.act(s,c,r,action,value);assert s.ore==old

def test_buy_cost_cap_and_full_repair(env):
 l,c,r,g,s=start(env);assert not g.act(s,c,r,'buy','repair');assert g.act(s,c,r,'buy','drill');assert s.ore==20
 assert r.price('drill',1,c)==170 and not g.act(s,c,r,'buy','drill')
 s.ore=100000
 for _ in range(2):assert g.act(s,c,r,'buy','barrel')
 assert not g.act(s,c,r,'buy','barrel') and g.stats(s,c).shots==3

def test_pause_explicit_idempotent_freezes_all(env):
 l,c,r,g,s=start(env);run(c,r,g,s,15);assert g.act(s,c,r,'pause',True);assert g.act(s,c,r,'pause',True)
 before=(s.elapsed,s.waveElapsed,s.ore,s.hull,len(s.projectiles));run(c,r,g,s,10)
 assert before==(s.elapsed,s.waveElapsed,s.ore,s.hull,len(s.projectiles))
 assert not g.act(s,c,r,'buy','drill');assert g.act(s,c,r,'pause',False)
 run(c,r,g,s,1);assert s.elapsed>before[0]

def test_clearing_requires_dead_enemies_and_projectiles(env):
 l,c,r,g,s=start(env);s.waveElapsed=28;s.enemies=l.table_from([enemy(l,x=1330)]);g.step(s,c,r,.1)
 assert s.stage=='clearing' and not s.supply
 s.enemies=l.table();s.projectiles=l.table_from([table(l,id=90,weapon='machine',x=550,y=140,tx=1000,ty=400,age=0,duration=1,damage=1)])
 g.step(s,c,r,.1);assert s.stage=='clearing'
 run(c,r,g,s,1);assert s.stage=='mining'

def test_supply_only_after_wave_and_halts_thirty_seconds(env):
 l,c,r,g,s=start(env);s.wave=2;s.waveElapsed=14;g.step(s,c,r,.1);assert not s.supply
 mining(env,2);before=(s.elapsed,s.breakLeft,s.ore);run(c,r,g,s,100);assert before==(s.elapsed,s.breakLeft,s.ore)
 assert g.act(s,c,r,'buy','drill') # investment allowed during supply selection

def test_mining_robot_cargo_not_continuous(env):
 l,c,r,g,s=mining(env);accept(env,'repair');ore=s.ore
 run(c,r,g,s,4);assert s.ore==ore and s.totalMined==0
 run(c,r,g,s,1);assert s.robots[1].cargo>0 and s.ore==ore
 run(c,r,g,s,1.2);assert s.ore>ore and s.totalMined>0
 assert s.robots[1].trips==1

def test_break_exactly_thirty_unpaused_seconds(env):
 l,c,r,g,s=mining(env);accept(env,'repair');run(c,r,g,s,14)
 g.act(s,c,r,'pause',True);run(c,r,g,s,30);assert s.breakLeft==pytest.approx(16)
 g.act(s,c,r,'pause',False);run(c,r,g,s,15.9);assert s.stage=='mining' and s.wave==1
 run(c,r,g,s,.1);assert s.stage=='combat' and s.wave==2 and len(s.robots)==0
 assert s.profile.bestWave==1

def test_pause_does_not_bypass_supply(env):
 l,c,r,g,s=mining(env);token=s.supply.token;g.act(s,c,r,'pause',True)
 assert not g.act(s,c,r,'supply',table(l,token=token,id='repair'))
 g.act(s,c,r,'pause',False);run(c,r,g,s,10);assert s.breakLeft==30 and s.supply.token==token

def test_supply_replay_and_reroll_stale_tokens(env):
 l,c,r,g,s=mining(env);token=s.supply.token;old=s.ore
 assert g.act(s,c,r,'reroll',token);assert s.ore==old
 assert not g.act(s,c,r,'supply',table(l,token=token,id='repair'))
 new=s.supply.token;assert not g.act(s,c,r,'supply',table(l,token=new,id='drones'))
 accept(env);assert not g.act(s,c,r,'supply',table(l,token=new,id='ore'))

def test_buffs_only_consume_relevant_phase(env):
 l,c,r,g,s=mining(env);accept(env,'ammo');s.effects.drill=30
 run(c,r,g,s,5);assert s.effects.ammo==35 and s.effects.drill==pytest.approx(25)
 run(c,r,g,s,25);before=s.effects.drill;run(c,r,g,s,1)
 assert s.effects.drill==before and s.effects.ammo==pytest.approx(34)

def test_tenth_and_twelfth_wave_include_mining(env):
 l,c,r,g,s=mining(env,10);assert s.phase=='running';accept(env);run(c,r,g,s,30);assert s.phase=='decision'
 assert g.act(s,c,r,'decision','continue');assert s.wave==11 and s.stage=='combat'
 mining(env,12);accept(env);run(c,r,g,s,30);assert s.phase=='ended' and s.result.won and s.result.overtime
 assert s.profile.bestWave==12

def test_settlement_once_and_abandon_zero_reward(env):
 l,c,r,g,s=start(env);s.ore=9000;s.runCrystals=10;s.runCores=3;r.record(s.profile,'enemies','crawler')
 assert g.act(s,c,r,'abandon','confirm');assert s.phase=='menu'
 assert s.profile.alloy==0 and s.profile.crystals==0 and s.profile.runs==0 and s.profile.codex.enemies.crawler==1
 assert not g.act(s,c,r,'abandon','confirm')
 mining(env,10);accept(env);run(c,r,g,s,30);assert g.act(s,c,r,'decision','leave')
 old=s.profile.alloy;assert not g.act(s,c,r,'decision','leave');assert s.profile.alloy==old

def test_projectiles_defer_damage_until_arrival(env):
 l,c,r,g,s=start(env);e=enemy(l);s.enemies=l.table_from([e]);s.spawnClock=-100;s.secondaryClock=100
 g.step(s,c,r,.1);assert len(s.projectiles)==1 and e.hp==1000
 run(c,r,g,s,.3);assert e.hp==1000
 run(c,r,g,s,.5);assert e.hp<1000
 assert s.profile.codex.weapons.cannon==1

def test_machine_projectile_deferred(env):
 l,c,r,g,s=start(env);e=enemy(l);s.enemies=l.table_from([e]);s.gunClock=100;s.spawnClock=-100
 g.step(s,c,r,.1);assert e.hp==1000 and s.projectiles[1].weapon=='machine'
 run(c,r,g,s,.3);assert e.hp<1000

@pytest.mark.parametrize('weapon,tech',[('arc','energy_2'),('rail','ballistics_4'),('flame','energy_4'),('mortar','expedition_3')])
def test_weapon_unlock_real_damage(env,weapon,tech):
 l,c,r,g,s=env;assert not g.act(s,c,r,'loadout',weapon);s.profile.tech[tech]=True
 assert g.act(s,c,r,'loadout',weapon);g.start(s,c,r)
 es=[enemy(l,id=i+1,x=900+i*10) for i in range(3)];s.enemies=l.table_from(es);s.gunClock=100;s.spawnClock=-100
 run(c,r,g,s,2);assert all(e.hp<1000 for e in es) if weapon!='machine' else es[0].hp<1000
 assert s.profile.codex.weapons[weapon]>0
 if weapon=='flame':assert es[0].burn>0

def test_spitter_acid_travels_before_base_damage(env):
 l,c,r,g,s=start(env);e=enemy(l,kind='spitter',x=925);e.attack=0;s.enemies=l.table_from([e]);s.gunClock=100;s.secondaryClock=100;s.spawnClock=-100
 g.step(s,c,r,.1);assert s.hull==900 and s.projectiles[1].weapon=='acid'
 run(c,r,g,s,.9);assert s.hull<900

def test_all_enemy_types_spawn_at_safe_edges(env):
 l,c,r,g,s=start(env);s.wave=10;s.gunClock=100;s.secondaryClock=100
 seen=set()
 for _ in range(280):
  g.step(s,c,r,.1)
  for e in s.enemies.values():seen.add(e.kind);assert e.x<=1347
  s.enemies=l.table();s.projectiles=l.table()
 assert {'crawler','runner','tank','spitter','elite','warden'}<=seen

def test_tech_48_nodes_no_cycles_and_real_effects(env):
 l,c,r,g,s=env;nodes=c.Tech.nodes;assert len(list(nodes.keys()))==48
 visiting=set();done=set()
 def visit(id):
  assert id not in visiting
  if id in done:return
  visiting.add(id)
  for dep in nodes[id].prereqs.values():assert nodes[dep];visit(dep)
  visiting.remove(id);done.add(id)
 for id in nodes.keys():visit(id)
 source=(ROOT/'src/Core.lua').read_text()+(ROOT/'src/Rules.lua').read_text()
 for n in nodes.values():
  for key in n.effects.keys():
   if key.startswith('unlock'):continue # consumed through Catalog.tech / profile membership
   assert '.'+key in source, key

def test_research_atomic_prereq_wave_and_rare_currency_gates(env):
 l,c,r,g,s=env;p=s.profile;p.alloy=100000;p.research=10000;p.crystals=100;p.cores=100
 assert r.techState(p,'fort_2',c)[0]=='locked'
 ok,msg=r.research(p,'fort_1',c);assert ok and p.tech.fort_1 and p.alloy==100000-78
 assert not r.research(p,'fort_1',c)[0];assert not r.research(p,'fort_2',c)[0]
 p.bestWave=12
 for tier in range(2,9):
  id='fort_'+str(tier)
  for pre in c.Tech.nodes[id].prereqs.values():p.tech[pre]=True
  before=(p.alloy,p.research,p.crystals,p.cores)
  assert r.research(p,id,c)[0]
  assert p.alloy==before[0]-c.Tech.nodes[id].cost.alloy
 assert r.techState(p,'fort_8',c)[0]=='owned'

def test_research_does_not_run_during_expedition(env):
 l,c,r,g,s=start(env);s.profile.alloy=1000;s.profile.research=100
 assert not g.act(s,c,r,'research','fort_1')

@pytest.mark.parametrize('id,attribute,expected',[('fort_1','maxHull',990),('logistics_1','ore',160)])
def test_research_applied_next_start(env,id,attribute,expected):
 l,c,r,g,s=env;s.profile.tech[id]=True;g.start(s,c,r);assert s[attribute]==expected

def test_robot_count_speed_yield_and_remote_unload(env):
 l,c,r,g,s=env
 for id in ['industry_1','industry_3','industry_4','industry_6','industry_8']:s.profile.tech[id]=True
 mining(env);assert len(s.robots)==4 and g.stats(s,c).cycle<6 and g.stats(s,c).cargo>28
 accept(env);s.breakLeft=.1;s.robots[1].cargo=17;old=s.ore;g.step(s,c,r,.1);assert s.ore>=old+17

def test_repair_shield_revive_and_reroll_tech(env):
 l,c,r,g,s=env
 for id in ['fort_6','fort_8','energy_7','logistics_3','logistics_7']:s.profile.tech[id]=True
 g.start(s,c,r);s.ore=1000;s.hull=100;g.act(s,c,r,'buy','repair');assert s.hull==325
 s.hull=1;s.effects.shield=35;e=enemy(l,x=650,kind='elite');e.attack=0;s.enemies=l.table_from([e]);g.step(s,c,r,.1)
 assert s.revived and s.hull==s.maxHull*.15
 s.hull=1;e.attack=0;g.step(s,c,r,.1);assert s.phase=='ended' and not s.result.won
 mining(env);assert g.rerollCost(s)==0;s.rerolls=1;assert g.rerollCost(s)==0;s.rerolls=2;assert g.rerollCost(s)==56

def test_unlock_supplies_discovered_and_functional(env):
 l,c,r,g,s=env;s.profile.tech.logistics_4=True;s.profile.tech.logistics_8=True;mining(env)
 s.supply.options=l.table_from(['drones','overclock','ore']);accept(env,'drones');assert len(s.robots)==3 and s.profile.codex.supplies.drones==1

@pytest.mark.parametrize('bad',[float('nan'),float('inf'),-50,'oops'])
def test_profile_sanitizes_nested_and_legacy(env,bad):
 l,c,r,g,s=env;p=r.cleanProfile(table(l,alloy=bad,armor=2,drill=1,power=2,tech=table(l,fort_8='true',fake_1=True),codex=table(l,enemies=table(l,crawler=bad))))
 assert p.alloy==0 and p.schema==6 and p.tech.fort_1 and p.tech.fort_2 and p.tech.industry_1 and p.tech.ballistics_2
 assert not p.tech.fort_8 and not p.tech.fake_1 and (p.codex.enemies.crawler or 0)==0
 q=r.cleanProfile(p);assert q.tech.fort_2 and not q.tech.industry_2

def test_snapshot_nested_copy(env):
 l,c,r,g,s=start(env);s.profile.tech.fort_1=True;s.effects.ammo=35
 snap=g.snapshot(s,c,r);snap.profile.tech.fort_1=False;snap.effects.ammo=0
 assert s.profile.tech.fort_1 and s.effects.ammo==35

@pytest.mark.parametrize('dt',[float('nan'),float('inf'),-1,0,'bad'])
def test_invalid_dt_no_progress(env,dt):
 l,c,r,g,s=start(env);g.step(s,c,r,dt);assert s.elapsed==0

def test_embedded_atlas_rgba_and_rigs(env):
 l,c,r,g,s=env;d=l.execute((ROOT/'src/ArtData.lua').read_text())
 assert sum(int(d.rle[i:i+4],16) for i in range(0,len(d.rle),6))==1024*1024
 for key in ['robot','drillBit','crawlerBody','tankBody']:assert d.sprites[key] and d.fallback[key]

def test_export_contains_current_sources_and_boot():
 project=json.loads((ROOT/'default.project.json').read_text())
 root=ET.parse(ROOT/(project['name']+'.rbxlx')).getroot()
 sources=[e.text for e in root.findall('.//*[@name="Source"]')]
 for file in (ROOT/'src').glob('*.lua'):assert file.read_text() in sources,file.name
 assert len(sources)==len(list((ROOT/'src').glob('*.lua')))

def test_legacy_bonuses_migrate_without_double_application(env):
 l,c,r,g,s=env;s.profile=r.cleanProfile(table(l,armor=2,drill=2,power=2,alloy=77,research=22));g.start(s,c,r)
 stats=g.stats(s,c);assert s.maxHull==1080 and stats.cargo==pytest.approx(28*1.2) and stats.damage==pytest.approx(24*1.16)
 assert s.profile.alloy==77 and s.profile.research==22

def test_mitigation_regen_and_start_shield_durations(env):
 l,c,r,g,s=env
 for id in ['fort_3','fort_4','fort_7','expedition_8','energy_7']:s.profile.tech[id]=True
 g.start(s,c,r);assert s.effects.shield==pytest.approx(14.4)
 s.hull=800;e=enemy(l,x=650);e.attack=0;s.enemies=l.table_from([e]);s.spawnClock=-100;s.gunClock=100;s.secondaryClock=100
 g.step(s,c,r,.1);assert s.hull==pytest.approx(800+.07-9*.95*.4)

def test_fifth_shot_and_ballistic_velocity(env):
 l,c,r,g,s=env;s.profile.tech.ballistics_5=True;s.profile.tech.ballistics_8=True;g.start(s,c,r)
 e=enemy(l);s.enemies=l.table_from([e]);s.spawnClock=-100;s.secondaryClock=100;s.shotSerial=4;g.step(s,c,r,.1)
 p=s.projectiles[1];assert p.damage==pytest.approx(24*1.75)
 assert p.duration==pytest.approx(math.hypot(1000-558,420-22-145)/(850*1.25))

def test_crystals_cores_rewards_and_expedition_multipliers(env):
 l,c,r,g,s=env
 for id in ['expedition_1','expedition_2','expedition_4','expedition_5','expedition_6','expedition_7']:s.profile.tech[id]=True
 mining(env,12);s.overtime=True;s.runCrystals=8;s.runCores=2;s.ore=1000
 accept(env);run(c,r,g,s,30)
 assert s.result.crystals==10 and s.result.cores==3 and s.result.won
 assert s.result.alloy==math.floor(s.ore*1.1)
 a,d=r.settlement(False,1000,0,0,0,False,g.new(c,r,s.profile).bonus)
 assert a==350
 b=r.bonuses(s.profile,c);a,d=r.settlement(False,1000,0,0,0,False,b);assert a==495

def test_burn_arc_bonus_and_aux_damage(env):
 l,c,r,g,s=env
 for id in ['energy_1','energy_2','energy_6']:s.profile.tech[id]=True
 g.act(s,c,r,'loadout','arc');g.start(s,c,r)
 es=[enemy(l,id=i+1,x=900+i*10) for i in range(5)];s.enemies=l.table_from(es);s.spawnClock=-100;s.gunClock=100
 g.step(s,c,r,.1)
 assert sum(e.hp<1000 for e in es)==4
 assert es[0].hp==pytest.approx(1000-24*.45*1.08)

def test_reroll_unlock_pool_and_overclock_duration(env):
 l,c,r,g,s=env;s.profile.tech.logistics_8=True;s.profile.tech.energy_5=True;mining(env,5)
 opts=set(s.supply.options.values());assert 'overclock' in opts
 accept(env,'overclock');assert s.effects.overclock==42
 assert g.stats(s,c).damage==pytest.approx(24*1.35)

def test_no_investment_policy_is_not_guaranteed_victory(env):
 l,c,r,g,s=start(env)
 for tick in range(12000):
  if s.phase=='ended':break
  if s.phase=='decision':g.act(s,c,r,'decision','leave');continue
  if s.supply:accept(env)
  g.step(s,c,r,.1);s.events=l.table()
 assert s.phase=='ended' and not s.result.won
