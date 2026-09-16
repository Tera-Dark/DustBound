from pathlib import Path
import json
import pytest
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
def host(**options):
 lua=LuaRuntime(unpack_returned_tuples=True)
 names={**{x:x+'.lua' for x in ['Config','Rules','Core','Art','ArtData','Tech','Catalog','Panels','Motion','UI','Guide','Audio']},'ProfileStore':'ProfileStore.lua','Telemetry':'Telemetry.lua','Server':'Server.server.lua'}
 lua.globals().SOURCES=lua.table_from({k:(ROOT/'src'/v).read_text() for k,v in names.items()})
 if options.pop('strictAPI',False):lua.globals().API_CONTRACT=lua.table_from(json.loads((ROOT/'tests/roblox_api_contract.json').read_text()),recursive=True)
 lua.globals().MOCK=lua.table_from(options)
 t=lua.execute((ROOT/'tests/mock_engine.lua').read_text());p=t.join(42);return lua,t,p

def client(t,p,touch=False):
 t.enableClient(p,(ROOT/'src/Client.client.lua').read_text(),touch)
 assert p.PlayerGui.GetAttribute(p.PlayerGui,'FrontierGameReady'),p.PlayerGui.GetAttribute(p.PlayerGui,'FrontierClientError')
def healthy(t,p):
 assert not p.PlayerGui.GetAttribute(p.PlayerGui,'FrontierClientError')
 assert t.network().BootStatus.Value=='READY',t.network().BootError.Value

def modal(p):return p.PlayerGui.DustboundPanels.SafeCanvas.ModalStage.Modal

def visit(t,p,label):t.click(p,label);t.render(.2)
def to_mining(lua,t,p,wave=1):
 s=t.session(p).game;s.wave=wave;s.waveElapsed=28;s.enemies=lua.table();s.projectiles=lua.table();t.step(.2);t.render(.2);assert s.supply;return s

def by_name(node,name):
 if node.Name==name:return node
 for child in node.GetChildren(node).values():
  found=by_name(child,name)
  if found is not None:return found
 return None

def click_name(t,p,name):
 b=by_name(p.PlayerGui,name);assert b is not None and b.Active is not False,name
 t.advanceClock(.3);b.Activated.Fire(b.Activated);t.render(.2)

@pytest.mark.parametrize('touch',[False,True])
@pytest.mark.parametrize('fallback',[False,True])
def test_boot_modes_purchase_and_local_mode(touch,fallback):
 _,t,p=host(unpublished=True,constructorError=True,imageDisabled=fallback);client(t,p,touch)
 visit(t,p,'▶  开始标准远征');visit(t,p,'采矿');visit(t,p,'投入 100 矿料')
 s=t.session(p).game;assert s.phase=='running' and s.upgrades.drill==1 and s.ore==20
 assert t.counters.getDataStore==0;healthy(t,p)

@pytest.mark.parametrize('touch',[False,True])
def test_tech_target_research_and_early_function_unlock(touch):
 _,t,p=host();client(t,p,touch);s=t.session(p).game;s.profile.alloy=500;s.profile.research=100;t.action(p,'ready')
 visit(t,p,'研究中心');click_name(t,p,'Tech_energy_2');visit(t,p,'固定研究目标');assert s.profile.targetResearch=='energy_2'
 visit(t,p,'确认研究');assert s.profile.tech.energy_2 and s.profile.alloy==380 and s.profile.targetResearch==''
 visit(t,p,'×');visit(t,p,'武器工坊');click_name(t,p,'Weapon_arc');visit(t,p,'装备副武器');assert s.loadout=='arc'
 healthy(t,p)

def test_desktop_has_48_nodes_and_preserves_scroll():
 lua,t,p=host();client(t,p);visit(t,p,'研究中心');tree=modal(p).TechTree
 assert len([o for o in tree.GetChildren(tree).values() if str(o.Name).startswith('Tech_')])==48
 tree.CanvasPosition=lua.globals().Vector2.new(0,420);click_name(t,p,'Tech_fort_8')
 assert modal(p).TechTree.CanvasPosition.Y==420
 assert by_name(modal(p),'ResearchNode').Active is False

def test_mobile_tech_is_branch_list_not_scaled_48_grid():
 _,t,p=host();client(t,p,True);visit(t,p,'研究中心');tree=modal(p).TechTree
 assert len([o for o in tree.GetChildren(tree).values() if str(o.Name).startswith('Tech_')])==8
 assert p.PlayerGui.DustboundHUD.Canvas.Stage.Size.xo>=960
 click_name(t,p,'NextBranch');assert by_name(modal(p),'BranchName').Text=='补给后勤'

def test_mobile_paged_investment_navigation():
 _,t,p=host();client(t,p,True);visit(t,p,'▶  开始标准远征')
 card=by_name(p.PlayerGui,'UpgradeCard');assert card.Name is not None
 click_name(t,p,'NextUpgrade');assert '射击速度' in card.FindFirstChild(card,'Name').Text
 click_name(t,p,'PreviousUpgrade');assert '火炮伤害' in card.FindFirstChild(card,'Name').Text

@pytest.mark.parametrize('category,label,entry',[('weapons','武器','磁轨枪'),('supplies','补给','超载核心'),('enemies','怪物','矿巢守卫')])
def test_codex_search(category,label,entry):
 _,t,p=host();client(t,p,True);visit(t,p,'远征图鉴');click_name(t,p,'Codex_'+category)
 inp=modal(p).CodexSearch;inp.Text=entry;inp.FocusLost.Fire(inp.FocusLost);t.render(.2)
 buttons=[o for o in modal(p).CodexList.GetChildren(modal(p).CodexList).values() if o.ClassName=='TextButton']
 assert len(buttons)==1 and entry in buttons[0].Text
 click_name(t,p,buttons[0].Name);assert by_name(modal(p),'EntryTitle').Text==entry;healthy(t,p)

@pytest.mark.parametrize('touch',[False,True])
def test_pause_settings_persist_and_resume(touch):
 _,t,p=host();client(t,p,touch);visit(t,p,'3 波教学 · 推荐');t.step(10);t.render(.2)
 visit(t,p,'Ⅱ');s=t.session(p).game;assert s.paused
 elapsed=s.elapsed;visit(t,p,'设置');visit(t,p,'轻量动效：关闭');visit(t,p,'伤害数字：显示');click_name(t,p,'Less_sfx')
 assert s.profile.settings.reducedMotion and not s.profile.settings.damageNumbers and s.profile.settings.sfx==pytest.approx(.45)
 t.step(3);assert s.elapsed==elapsed
 visit(t,p,'×');assert t.findGui(p,'远征已暂停') is not None
 visit(t,p,'继续远征');assert not s.paused;t.step(.2);assert s.elapsed>elapsed;healthy(t,p)

def test_supply_invest_drawer_and_robot_progress():
 lua,t,p=host();client(t,p,True);visit(t,p,'3 波教学 · 推荐');s=to_mining(lua,t,p)
 visit(t,p,'暂看投资');visit(t,p,'采矿');visit(t,p,'投入 100 矿料');assert s.upgrades.drill==1
 t.step(3);assert s.breakLeft==30
 visit(t,p,'选择补给');visit(t,p,'接收补给');assert s.supply is None
 for _ in range(61):t.step(.1);t.render(.016)
 assert s.totalMined>0
 visit(t,p,'情报 / 经营台');assert by_name(modal(p),'PlanningDetails') is not None
 visit(t,p,'定位建议投资');healthy(t,p)

def test_abandon_confirmation_zero_rewards():
 _,t,p=host();client(t,p);visit(t,p,'▶  开始标准远征');s=t.session(p).game;s.ore=9999
 visit(t,p,'Ⅱ');visit(t,p,'返回主菜单');visit(t,p,'取消，回到暂停菜单');assert s.phase=='running'
 visit(t,p,'返回主菜单');visit(t,p,'确认放弃并返回');assert s.phase=='menu' and s.profile.alloy==0
 healthy(t,p)

@pytest.mark.parametrize('touch',[False,True])
def test_tutorial_result_direct_research_workshop_next_run(touch):
 lua,t,p=host();client(t,p,touch);visit(t,p,'3 波教学 · 推荐');s=to_mining(lua,t,p,3)
 visit(t,p,'接收补给');t.step(30);t.render(.2)
 assert s.phase=='ended' and s.result.firstClear and s.profile.tutorialCompleted
 visit(t,p,'研究');visit(t,p,'确认研究');assert s.profile.tech.energy_2
 visit(t,p,'×');visit(t,p,'换装');visit(t,p,'装备副武器');assert s.loadout=='arc'
 visit(t,p,'×');visit(t,p,'再开标准远征');assert s.phase=='running' and s.mode=='standard';healthy(t,p)

def test_cloud_read_failure_is_blocked_until_explicit_guest():
 _,t,p=host(cloud=True,constructorError=True);client(t,p)
 s=t.session(p);assert s.profile.blocked
 t.action(p,'start','standard');assert s.game.phase=='menu'
 visit(t,p,'确认进入不保存的试玩');assert s.profile.mode=='guest' and not s.profile.persistent
 visit(t,p,'3 波教学 · 推荐');assert s.game.phase=='running';healthy(t,p)

def test_cloud_saved_settings_loadout_target_and_presets():
 lua,t,p=host(cloud=True);client(t,p);s=t.session(p).game;s.profile.alloy=500;s.profile.research=100
 t.action(p,'research','energy_2');t.action(p,'loadout','arc');t.action(p,'target','fort_3')
 t.action(p,'settings',lua.table_from({'key':'sfx','value':.2}));t.action(p,'preset',lua.table_from({'slot':1,'mode':'save'}))
 t.leave(p);p2=t.join(42);r=t.session(p2).profile
 assert r.persistent and r.data.loadout=='arc' and r.data.settings.sfx==.2 and r.data.targetResearch=='fort_3' and r.data.presets[1]=='arc'

def test_settings_diagnostics_and_audio_are_real_calls():
 lua,t,p=host();client(t,p);visit(t,p,'设置');visit(t,p,'试听反馈音')
 service=lua.globals().game.GetService(lua.globals().game,'SoundService')
 audio=service.DustboundAudio
 assert audio.SFX_upgrade.playCount>0
 assert t.session(p).telemetry.counts.ui_ready==1
 assert t.session(p).telemetry.counts.open_settings>=1

@pytest.mark.parametrize('touch',[False,True])
def test_api_contract_all_panels_and_battle(touch):
 lua,t,p=host(strictAPI=True);client(t,p,touch)
 for name in ['研究中心','武器工坊','远征图鉴','设置']:visit(t,p,name);healthy(t,p);visit(t,p,'×')
 visit(t,p,'3 波教学 · 推荐');visit(t,p,'投入 110 矿料')
 for _ in range(310):t.step(.1);t.render(.016)
 visit(t,p,'接收补给')
 for _ in range(65):t.step(.1);t.render(.016)
 visit(t,p,'Ⅱ');visit(t,p,'查看图鉴');healthy(t,p)

def test_unpublished_cloud_optin_stays_local():
 _,t,p=host(cloud=True,unpublished=True);client(t,p);visit(t,p,'3 波教学 · 推荐')
 assert t.session(p).profile.mode=='local' and t.session(p).game.phase=='running'

def test_dynamic_safe_areas_and_fullscreen_shade():
 _,t,p=host();client(t,p)
 assert p.PlayerGui.DustboundHUD.ScreenInsets=='CoreUISafeInsets'
 assert p.PlayerGui.DustboundPanels.ScreenInsets=='CoreUISafeInsets'
 assert p.PlayerGui.DustboundShade.ScreenInsets=='None'
 assert p.PlayerGui.DustboundShade.ModalBackdrop.Size.xs==1

def test_independent_boot_without_server():
 _,t,p=host(noServer=True);t.boot(p,(ROOT/'src/Boot.client.lua').read_text());assert p.PlayerGui.FrontierBoot.Enabled
