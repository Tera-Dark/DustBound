import pytest
from test_core import env,start,mining,accept,run,table,enemy
from test_ui import host,client,visit,healthy

def test_tutorial_three_breaks_first_reward_only_once(env):
 l,c,r,g,s=env;g.start(s,c,r,'tutorial');breaks=0
 for _ in range(4000):
  if s.phase=='ended':break
  if s.supply:breaks+=1;accept(env)
  g.step(s,c,r,.1);s.events=l.table()
 assert s.result and s.result.won and s.result.firstClear and breaks==3
 assert s.result.bonusAlloy==180 and s.result.bonusResearch==35
 assert s.profile.bestWave==0 and s.profile.tutorialCompleted and s.profile.targetResearch=='energy_2'
 assert r.techState(s.profile,'energy_2',c)[0]=='ready'
 oldSerial=s.profile.settledSerial
 g.start(s,c,r,'tutorial');mining(env,3);accept(env);run(c,r,g,s,30)
 assert not s.result.firstClear and s.result.bonusAlloy==0 and s.result.bonusResearch==0
 assert s.result.alloy==0 and s.result.research==0
 assert s.profile.settledSerial==oldSerial+1

def test_failed_or_abandoned_tutorial_does_not_claim_reward(env):
 l,c,r,g,s=env;g.start(s,c,r,'tutorial');s.hull=0;g.step(s,c,r,.1)
 assert not s.result.won and not s.profile.tutorialCompleted
 g.start(s,c,r,'tutorial');g.act(s,c,r,'abandon','confirm');assert not s.profile.tutorialCompleted

@pytest.mark.parametrize('mode',['hacked',1,False])
def test_invalid_run_mode_rejected(env,mode):
 l,c,r,g,s=env;assert not g.act(s,c,r,'start',mode) and s.profile.runSerial==0

def test_explicit_request_ids_deduplicate_purchases():
 l,t,p=host();a=t.network().Action;s=t.session(p).game
 a.OnServerEvent.Fire(a.OnServerEvent,p,'start','standard',1);t.advanceClock(.3)
 a.OnServerEvent.Fire(a.OnServerEvent,p,'buy','drill',2);assert s.ore==20
 t.advanceClock(.3);a.OnServerEvent.Fire(a.OnServerEvent,p,'buy','drill',2);assert s.ore==20 and s.upgrades.drill==1

def test_settings_sanitize_and_presets_unlock_validation(env):
 l,c,r,g,s=env
 assert not g.act(s,c,r,'settings',table(l,key='sfx',value=float('nan')))
 assert g.act(s,c,r,'settings',table(l,key='sfx',value=10));assert s.profile.settings.sfx==1
 assert g.act(s,c,r,'settings',table(l,key='music',value=-1));assert s.profile.settings.music==0
 assert not g.act(s,c,r,'settings',table(l,key='alloy',value=100000))
 s.profile.presets[1]='arc';assert not g.act(s,c,r,'preset',table(l,slot=1,mode='equip'))
 s.profile.tech.energy_2=True;assert g.act(s,c,r,'preset',table(l,slot=1,mode='equip')) and s.loadout=='arc'

def test_timing_buckets_exclude_supply_and_pause_from_effective_time(env):
 l,c,r,g,s=mining(env);a=s.elapsed;run(c,r,g,s,4);assert s.timing.supply==pytest.approx(4)
 g.act(s,c,r,'pause',True);run(c,r,g,s,2);assert s.timing.pause==pytest.approx(2) and s.elapsed==a
 g.act(s,c,r,'pause',False);accept(env);run(c,r,g,s,5);assert s.timing.mining==pytest.approx(5) and s.elapsed==pytest.approx(a+5)

def test_forecast_no_income_and_upgrade_explanations(env):
 from pathlib import Path
 l,c,r,g,s=mining(env);guide=l.execute((Path(__file__).resolve().parents[1]/'src/Guide.lua').read_text());ss=g.snapshot(s,c,r)
 f=guide.forecast(ss);assert f.expected>0 and f.cargo==0 and f.eta==6
 assert s.totalMined==0
 info=guide.investment('damage',ss,c,r);assert info.price==110 and info.can and '24' in info.detail
 assert guide.intel(5,c).elite and not guide.intel(4,c).elite

def test_wave_report_tracks_effective_damage(env):
 l,c,r,g,s=start(env);e=enemy(l,hp=10,x=950);s.enemies=l.table_from([e]);s.spawnClock=-100
 run(c,r,g,s,2);s.enemies=l.table();s.projectiles=l.table();s.waveElapsed=28;g.step(s,c,r,.1)
 assert s.waveReport.kills==1 and s.waveReport.damage<=10 and s.waveReport.damage>0

def test_read_retry_restores_old_profile_without_empty_write():
 l,t,p=host(cloud=True,constructorError=True);client(t,p)
 t.db['u_42']=l.table_from({'data':{'schema':4,'alloy':999,'research':83,'tech':{'fort_1':True}},'lock':None},recursive=True)
 l.globals().MOCK.constructorError=False;visit(t,p,'重试读取')
 s=t.session(p);assert not s.profile.blocked and s.game.profile.alloy==999 and s.game.profile.tech.fort_1
 assert t.db['u_42'].data.alloy==999;healthy(t,p)

@pytest.mark.parametrize('raw',[17,{'data':'corrupt'},{'data':{'schema':999,'alloy':12345}}])
def test_corrupt_or_newer_cloud_data_is_not_overwritten(raw):
 l,t,p=host(cloud=True)
 value=l.table_from(raw,recursive=True) if isinstance(raw,dict) else raw
 t.db['u_100']=value;p2=t.join(100);s=t.session(p2)
 assert s.profile.blocked and s.profile.mode=='read_error'
 if raw==17:assert t.db['u_100']==17
 elif raw['data']=='corrupt':assert t.db['u_100'].data=='corrupt'
 else:assert t.db['u_100'].data.schema==999 and t.db['u_100'].data.alloy==12345

def test_save_failure_retry_flushes_newer_mutations_and_settings():
 l,t,p=host(cloud=True);s=t.session(p);s.game.profile.alloy=500;s.game.profile.research=100
 t.failStore(True);t.action(p,'research','energy_2');assert s.profile.mode=='save_error' and s.profile.pending
 t.action(p,'settings',l.table_from({'key':'sfx','value':.2}));assert s.game.profile.settings.sfx==.2
 t.failStore(False);t.action(p,'save_retry');assert s.profile.pending is None and s.profile.mode=='cloud'
 t.leave(p);p2=t.join(42);r=t.session(p2).profile.data
 assert r.alloy==380 and r.research==80 and r.tech.energy_2 and r.settings.sfx==.2

def test_committed_write_lost_response_retry_is_idempotent():
 l,t,p=host(cloud=True);s=t.session(p);s.game.profile.alloy=500;s.game.profile.research=100
 l.globals().MOCK.commitThenError=True;t.action(p,'research','energy_2')
 assert s.profile.pending and t.db['u_42'].data.alloy==380
 t.action(p,'save_retry');assert t.db['u_42'].data.alloy==380 and t.db['u_42'].data.research==80

def test_lock_acquire_lost_response_can_retry_same_token():
 l,t,p=host(cloud=True,commitThenError=True);s=t.session(p);assert s.profile.blocked
 token=s.profile.token;assert t.db['u_42'].lock.token==token
 t.action(p,'save_retry');assert not s.profile.blocked and s.profile.token==token

def test_lost_lock_blocks_writes_not_cloud_overwrite():
 l,t,p=host(cloud=True);s=t.session(p);t.db['u_42'].lock.token='other-owner'
 s.game.profile.alloy=500;s.game.profile.research=100;t.action(p,'research','energy_2')
 assert s.profile.mode=='lock_lost' and s.profile.blocked and not s.profile.persistent
 assert t.db['u_42'].data.alloy==0

def test_callback_replay_does_not_double_research():
 l,t,p=host(cloud=True,replayCallback=True);s=t.session(p);s.game.profile.alloy=500;s.game.profile.research=100
 t.action(p,'research','energy_2');assert s.game.profile.alloy==380 and t.db['u_42'].data.alloy==380

def test_metrics_whitelist_and_first_deposit_once():
 l,t,p=host();t.action(p,'ui_ready','keyboard');t.action(p,'ui_ready','touch');t.action(p,'start','tutorial')
 s=t.session(p);assert s.telemetry.counts.ui_ready==1 and s.telemetry.input=='keyboard'
 for _ in range(350):
  t.step(.1)
  if s.game.supply:t.action(p,'supply',l.table_from({'token':s.game.supply.token,'id':s.game.supply.options[1]}))
 assert s.telemetry.counts.first_robot_deposit==1
 assert len(s.telemetry.recent)<=48
 assert s.telemetry.counts.shot is None

def test_two_players_still_isolated():
 l,t,p=host();p2=t.join(100);t.action(p,'start','tutorial');t.action(p,'buy','drill')
 assert t.session(p).game.ore==20 and t.session(p2).game.phase=='menu'


def test_tutorial_fixed_grant_and_unproductive_investment_blocked(env):
 l,c,r,g,s=env;g.start(s,c,r,'tutorial');s.ore=999999
 assert not g.act(s,c,r,'buy','refinery') and s.ore==999999
 mining(env,3);accept(env);run(c,r,g,s,30)
 assert s.result.alloy==180 and s.result.research==35 and s.result.crystals==0 and s.result.cores==0

def test_old_arc_owner_tutorial_targets_new_research(env):
 l,c,r,g,s=env;s.profile.tech.energy_2=True;g.start(s,c,r,'tutorial')
 mining(env,3);accept(env);run(c,r,g,s,30)
 assert s.profile.targetResearch=='ballistics_1'

def test_mobile_orientation_and_adaptive_full_width():
 _,t,p=host(strictAPI=True);client(t,p,True)
 assert p.PlayerGui.ScreenOrientation=='LandscapeSensor'
 stage=p.PlayerGui.DustboundHUD.Canvas.Stage
 assert stage.Size.xo>1100
 healthy(t,p)

def test_zero_viewport_waits_without_claiming_ui_ready():
 from pathlib import Path
 l,t,p=host(width=0,height=0);t.enableClient(p,(Path(__file__).resolve().parents[1]/'src/Client.client.lua').read_text(),False)
 t.render(.1);assert p.PlayerGui.GetAttribute(p.PlayerGui,'FrontierClientPhase')=='WAITING_FOR_VIEWPORT'
 assert not t.session(p).telemetry.counts.ui_ready
 camera=l.globals().workspace.CurrentCamera;camera.ViewportSize=l.globals().Vector2.new(1440,810)
 t.render(.1);assert t.session(p).telemetry.counts.ui_ready==1;healthy(t,p)

def test_pending_modal_blocks_double_click_and_timeout_recovers():
 from test_ui import click_name,by_name
 l,t,p=host();client(t,p);visit(t,p,'设置')
 action=t.network().Action;callbacks=action.OnServerEvent.callbacks;action.OnServerEvent.callbacks=l.table()
 click_name(t,p,'Less_sfx');overlay=by_name(p.PlayerGui,'PendingRequest');assert overlay.Visible
 t.advanceClock(4);t.render(4);assert not overlay.Visible
 action.OnServerEvent.callbacks=callbacks;t.action(p,'ready');t.render(.1);healthy(t,p)


def test_dirty_profile_does_not_keep_a_current_saved_claim():
 _,t,p=host(cloud=True);store=t.module('ProfileStore');record=t.session(p).profile
 assert store.flush(p.UserId,record,False)
 store.touch(record);assert record.status=='有更新待保存'
 record.mode='save_error';record.status='保存失败';store.touch(record)
 assert record.status=='保存失败'
