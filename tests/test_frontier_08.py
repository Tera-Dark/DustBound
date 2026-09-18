"""0.8 engine-independent rules and native GUI contract regression.
The GUI host is a mock, NOT a Roblox renderer, physics host or FPS benchmark.
"""
from pathlib import Path
import json, pytest
from campaign_pilot import setup, play, research
from test_ui import host,client,healthy,by_name,click_name
ROOT=Path(__file__).resolve().parents[1]

def depart(t,p):
    click_name(t,p,'StartGame');click_name(t,p,'Depart')

@pytest.mark.parametrize('fallback',[False,True])
@pytest.mark.parametrize('touch',[False,True])
def test_home_has_start_and_subsystems_not_level_wall(fallback,touch):
    l,t,p=host(shippingOnly=True,strictAPI=True,imageDisabled=fallback);client(t,p,touch)
    assert by_name(p.PlayerGui,'HomeCommand') is not None
    assert by_name(p.PlayerGui,'StartGame') is not None
    assert by_name(p.PlayerGui,'Node1') is None
    for n in ['Nav_Campaign','Nav_Research','Nav_Codex','Nav_Options']:assert by_name(p.PlayerGui,n) is not None
    assert by_name(p.PlayerGui,'RadialGround') is None
    click_name(t,p,'StartGame')
    assert by_name(p.PlayerGui,'Node1').Active
    assert not by_name(p.PlayerGui,'Node2').Active
    assert not by_name(p.PlayerGui,'PlanetTab2').Active
    healthy(t,p)

@pytest.mark.parametrize('fallback',[False,True])
def test_native_navigation_all_pages(fallback):
    l,t,p=host(shippingOnly=True,strictAPI=True,imageDisabled=fallback);client(t,p,True)
    for name,element in [('Nav_Research','ResearchNetwork'),('Nav_Home','StartGame'),('Nav_Codex','CodexCards')]:
        click_name(t,p,name);assert by_name(p.PlayerGui,element) is not None;healthy(t,p)
    click_name(t,p,'Close');click_name(t,p,'Nav_Options');before=t.session(p).game.profile.settings.sfx
    click_name(t,p,'Less_sfx');assert t.session(p).game.profile.settings.sfx<before
    click_name(t,p,'Close');depart(t,p)
    assert by_name(p.PlayerGui,'BattleDock') is not None
    assert by_name(p.PlayerGui,'LoadoutSlot5') is not None
    click_name(t,p,'Combat');click_name(t,p,'Close');healthy(t,p)

def test_planets_unlock_only_after_previous_final_node():
    l,t,p=host();client(t,p);s=t.session(p).game
    s.profile.campaignCleared=8;t.action(p,'ready');t.render(.1)
    click_name(t,p,'StartGame');assert by_name(p.PlayerGui,'PlanetTab2').Active
    click_name(t,p,'PlanetTab2');assert by_name(p.PlayerGui,'Node9').Active
    assert not by_name(p.PlayerGui,'Node10').Active
    click_name(t,p,'Depart');assert s.campaignNode==9
    healthy(t,p)

@pytest.mark.parametrize('wave',[1,2,3,4,10,20])
def test_ground_spawns_only_on_sides_flyers_only_above(wave):
    l,c,r,g,s=setup();g.start(s,c,r);s.wave=wave;found=set()
    for i in range(1,40):
        s.enemies=l.table();s.projectiles=l.table();s.waveElapsed=i*.5;s.spawnClock=99;s.gunClock=99
        g.step(s,c,r,.01)
        for e in s.enemies.values():
            found.add(e.kind)
            if e.kind=='flyer':assert e.y<0 and 350<=e.x<=1090 and e.vy>0
            else:assert e.x<0 or e.x>1440;assert 366<=e.y<=402;assert e.vy==0
    assert 'crawler' in found
    assert ('flyer' in found)==(c.Encounters.plan(1,wave).pattern=='air')

@pytest.mark.parametrize('kind',['crawler','tank','flyer'])
def test_attack_uses_correct_lane_and_emits_visual_event(kind):
    l,c,r,g,s=setup();g.start(s,c,r);s.gunClock=99
    x,y=(720,138) if kind=='flyer' else (592,384)
    s.enemies[1]=l.table_from(dict(id=999,kind=kind,x=x,y=y,hp=1000,maxHp=1000,speed=20,attack=0,burn=0))
    old=s.hull;g.step(s,c,r,.1);assert s.hull<old
    events=[e for e in s.events.values() if e.kind=='enemyattack'];assert events and events[0].enemyKind==kind
    if kind!='flyer':assert s.enemies[1].y==384

def test_ground_does_not_drift_into_sky_while_approaching():
    l,c,r,g,s=setup();g.start(s,c,r);s.gunClock=999;s.spawnClock=-999;s.groupIndex=99
    for i,x in enumerate([40,1400],1):s.enemies[i]=l.table_from(dict(id=i,kind='tank',x=x,y=390,hp=1000,maxHp=1000,speed=50,attack=999,burn=0))
    for _ in range(100):g.step(s,c,r,.1)
    assert all(e.y==390 and e.vy==0 for e in s.enemies.values())

def mining(l,c,r,g,s):
    g.start(s,c,r);s.groupIndex=99;s.planWave=s.wave;s.waveElapsed=25;s.enemies=l.table();s.projectiles=l.table();g.step(s,c,r,.1)
    assert s.supply;g.act(s,c,r,'supply',l.table_from({'token':s.supply.token,'id':s.supply.options[1]}))

def test_bilateral_mining_has_physical_cargo_and_conserved_gold():
    l,c,r,g,s=setup();mining(l,c,r,g,s)
    assert s.robots[1].mineX<720<s.robots[2].mineX
    saw_drill=saw_return=False
    for _ in range(170):
        g.step(s,c,r,.1)
        for robot in s.robots.values():
            assert min(robot.baseX,robot.mineX)-.001<=robot.x<=max(robot.baseX,robot.mineX)+.001
            saw_drill|=robot.state=='drilling'
            saw_return|=robot.state=='returning' and robot.cargo>0
        assert s.ore==120+s.totalMined-s.ledger.spent
    assert saw_drill and saw_return and s.totalMined>0
    assert s.robots[1].trips>0 and s.robots[2].trips>0

@pytest.mark.parametrize('reason',['pause','offer'])
def test_mining_frozen_for_pause_and_offers(reason):
    l,c,r,g,s=setup();g.start(s,c,r);s.groupIndex=99;s.planWave=s.wave;s.waveElapsed=25;g.step(s,c,r,.1)
    if reason=='pause':g.act(s,c,r,'supply',l.table_from({'token':s.supply.token,'id':s.supply.options[1]}));g.act(s,c,r,'pause',True)
    before=(s.breakLeft,s.robots[1].x,s.ore)
    for _ in range(40):g.step(s,c,r,.1)
    assert before==(s.breakLeft,s.robots[1].x,s.ore)

@pytest.mark.parametrize('fallback',[False,True])
def test_robot_and_flyer_visuals_and_reduced_motion(fallback):
    l,t,p=host(imageDisabled=fallback,strictAPI=True);client(t,p);depart(t,p);s=t.session(p).game
    s.wave=3;s.waveElapsed=5;s.gunClock=99;s.spawnClock=99;s.serial=5;t.step(.2);t.render(.1)
    assert by_name(p.PlayerGui,'Sprite_flyerBody') is not None
    assert by_name(p.PlayerGui,'Sprite_flyerWing') is not None
    s.wave=1;s.groupIndex=99;s.planWave=s.wave;s.waveElapsed=25;s.enemies=l.table();s.projectiles=l.table();t.step(.2);t.render(.1)
    click_name(t,p,'Choose_'+s.supply.options[1])
    for _ in range(25):t.step(.1);t.render(.1)
    for key in ['MiningRig','Tread','RobotState','DigTrack','DrillDust1']:assert by_name(p.PlayerGui,key) is not None
    t.action(p,'settings',l.table_from({'key':'reducedMotion','value':True}));t.render(.1)
    assert by_name(p.PlayerGui,'DrillDust1').Visible is False
    healthy(t,p)

def test_offer_can_pause_settings_and_resume_without_spending_choice():
    l,t,p=host();client(t,p);depart(t,p);s=t.session(p).game
    s.groupIndex=99;s.planWave=s.wave;s.waveElapsed=25;s.enemies=l.table();s.projectiles=l.table();t.step(.2);t.render(.1)
    click_name(t,p,'Settings');assert s.paused
    click_name(t,p,'Close');assert not s.paused
    old=s.ore;click_name(t,p,'Choose_'+s.supply.options[1]);assert not s.supply and s.ore==old
    healthy(t,p)

def test_paid_reroll_ui_and_stale_token():
    l,t,p=host();client(t,p);depart(t,p);s=t.session(p).game
    s.groupIndex=99;s.planWave=s.wave;s.waveElapsed=25;s.enemies=l.table();s.projectiles=l.table();t.step(.2);t.render(.1)
    click_name(t,p,'Reroll');old=s.supply.token;click_name(t,p,'Reroll');assert s.supply.token==old and s.ore==120
    click_name(t,p,'ConfirmReroll');assert s.supply.token!=old and s.ore==40
    healthy(t,p)

def test_menu_idle_no_instance_churn():
    l,t,p=host();client(t,p)
    for _ in range(60):t.render(1/60)
    before=(t.counters.instances,t.counters.destroyed,t.counters.assignments)
    for _ in range(180):t.render(1/60)
    assert t.counters.instances==before[0] and t.counters.destroyed==before[1]
    assert t.counters.assignments-before[2]<80
    healthy(t,p)

def test_saved_profile_ownership_keeps_old_ids_and_currency():
    l,c,r,g,s=setup();raw=l.table_from({'alloy':123,'research':45,'cores':2,'campaignCleared':8,'tech':{'fort_1':True,'industry_3':True}},recursive=True)
    p=r.cleanProfile(raw);new=g.new(c,r,p)
    assert new.profile.tech.fort_1 and new.profile.tech.industry_3
    assert (new.profile.alloy,new.profile.research,new.profile.cores)==(123,45,2)
    assert new.profile.campaignCleared==8

def test_release_has_frontier_and_new_art_embedded():
    project=json.loads((ROOT/'default.project.json').read_text())
    assert 'Frontier' in project['tree']['ReplicatedStorage']['FrontierShared']
    atlas=json.loads((ROOT/'assets/atlas-layout.json').read_text())
    assert 'flyerBody' in atlas and 'flyerWing' in atlas
    import xml.etree.ElementTree as ET
    tree=ET.parse(ROOT/'Dustbound-0.9.0-FIRST-CONTACT.rbxlx')
    sources=[x.text or '' for x in tree.iter() if x.get('name')=='Source']
    assert (ROOT/'src/Frontier.lua').read_text() in sources
    assert (ROOT/'src/Core.lua').read_text() in sources
