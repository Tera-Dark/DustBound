"""0.5.3 native UI + real option wiring regressions; mock, not engine usability tests."""
import pytest
from test_core import env,table
from test_ui import host,client,visit,healthy,by_name,click_name,modal,to_mining
from test_performance import motion_fixture

BOOLS=['screenShake','flashEffects','enemyHealth','showTips','compactNumbers','autoPause','muteUnfocused','masterMuted','confirmReroll','hotkeys']

@pytest.mark.parametrize('key',BOOLS)
def test_new_settings_are_whitelisted_and_reject_non_booleans(env,key):
    l,c,r,g,s=env
    assert g.act(s,c,r,'settings',table(l,key=key,value=False))
    assert s.profile.settings[key] is False
    assert not g.act(s,c,r,'settings',table(l,key=key,value=1))
    assert not g.act(s,c,r,'settings',table(l,key=key,value='true'))
    assert s.profile.settings[key] is False

def test_old_schema_five_keeps_existing_preferences_and_adds_safe_defaults(env):
    l,c,r,g,s=env
    p=r.cleanProfile(l.table_from({'schema':5,'alloy':543,'tech':{'energy_2':True},'settings':{'sfx':.2,'reducedMotion':True,'damageNumbers':False,'autoPause':'true','masterMuted':17}},recursive=True))
    assert p.schema==6 and p.alloy==543 and p.tech.energy_2
    assert p.settings.sfx==.2 and p.settings.reducedMotion and not p.settings.damageNumbers
    assert not p.settings.autoPause and not p.settings.masterMuted
    assert p.settings.screenShake and p.settings.flashEffects and p.settings.enemyHealth

def test_default_settings_are_not_shared_between_profiles(env):
    l,c,r,g,s=env;a=r.cleanProfile(None);b=r.cleanProfile(None)
    a.settings.screenShake=False;assert b.settings.screenShake

def test_reset_requires_confirmation_and_never_erases_progress(env):
    l,c,r,g,s=env;s.profile.alloy=999;s.profile.tech.energy_2=True
    g.start(s,c,r);g.act(s,c,r,'pause',True)
    g.act(s,c,r,'settings',table(l,key='masterMuted',value=True))
    assert not g.act(s,c,r,'settings_reset','anything')
    assert s.profile.settings.masterMuted
    assert g.act(s,c,r,'settings_reset','confirm')
    assert not s.profile.settings.masterMuted and s.profile.settings.sfx==.65
    assert s.profile.alloy==999 and s.profile.tech.energy_2 and s.paused

def test_new_preferences_persist_through_cloud_cleaning():
    l,t,p=host(cloud=True)
    for key,value in [('screenShake',False),('masterMuted',True),('autoPause',True),('compactNumbers',True)]:
        t.action(p,'settings',table(l,key=key,value=value))
    t.leave(p);p=t.join(42);cfg=t.session(p).profile.data.settings
    assert not cfg.screenShake and cfg.masterMuted and cfg.autoPause and cfg.compactNumbers

def test_compact_numbers_never_round_up_affordability(env):
    l,c,r,g,s=env
    assert r.number(9999,True)=='9999'
    assert r.number(19999,True)=='19.9K'
    assert r.number(1250000,True)=='1.2M'
    assert r.number(19999,False)=='19999'

@pytest.mark.parametrize('touch',[False,True])
def test_settings_open_on_general_with_advanced_out_of_the_way(touch):
    l,t,p=host(strictAPI=True);client(t,p,touch);visit(t,p,'设置')
    assert by_name(modal(p),'ShowTips') and by_name(modal(p),'AutoPause')
    assert by_name(modal(p),'Performance') is None
    click_name(t,p,'SettingsTab_display');click_name(t,p,'ScreenShake')
    assert not t.session(p).game.profile.settings.screenShake
    assert by_name(modal(p),'ScreenShake').Text=='— 关闭'
    click_name(t,p,'SettingsTab_audio');click_name(t,p,'MasterMuted')
    assert t.session(p).game.profile.settings.masterMuted
    click_name(t,p,'SettingsTab_advanced');assert by_name(modal(p),'Performance')
    healthy(t,p)

def test_reset_dialog_cancel_then_confirm_from_settings():
    l,t,p=host();client(t,p);visit(t,p,'设置');click_name(t,p,'ShowTips')
    click_name(t,p,'ResetSettings');click_name(t,p,'CancelSettingsReset')
    assert not t.session(p).game.profile.settings.showTips
    click_name(t,p,'ResetSettings');click_name(t,p,'ConfirmSettingsReset')
    assert t.session(p).game.profile.settings.showTips
    assert by_name(modal(p),'ShowTips').Text=='✓ 开启'

def focus(l,focused):
    u=l.globals().game.GetService(l.globals().game,'UserInputService')
    sig=u.WindowFocused if focused else u.WindowFocusReleased
    sig.Fire(sig)

def test_focus_loss_pauses_immediately_and_return_does_not_auto_resume():
    l,t,p=host(strictAPI=True);client(t,p);visit(t,p,'▶  开始标准远征')
    t.action(p,'settings',table(l,key='autoPause',value=True));t.render(.2);t.advanceClock(.3)
    focus(l,False)
    s=t.session(p).game;assert s.paused
    elapsed=s.elapsed;t.step(2);focus(l,True);t.render(.2)
    assert s.paused and s.elapsed==elapsed
    visit(t,p,'继续远征');assert not s.paused

def test_focus_loss_does_not_pause_by_default():
    l,t,p=host();client(t,p);visit(t,p,'▶  开始标准远征')
    focus(l,False);t.render(.2)
    assert not t.session(p).game.paused

def test_mute_options_stop_existing_sfx_and_restore_original_volume():
    l,t,p=host();client(t,p)
    a=t.module('Audio').new(t.module('Config'));cfg=t.module('Rules').cleanSettings(None)
    a.settings(cfg);a.play('upgrade');snd=a.pool.upgrade;stops=snd.stopCount
    a.focus(False);assert a.muted and snd.stopCount>stops
    a.update(.3,False,None);plays=snd.playCount;a.play('upgrade');assert snd.playCount==plays
    a.focus(True);a.update(.3,False,None);a.play('upgrade');assert snd.playCount==plays+1
    volume=snd.Volume;cfg.masterMuted=True;a.settings(cfg);assert a.muted
    cfg.masterMuted=False;a.settings(cfg);a.update(.3,False,None);a.play('upgrade');assert snd.Volume==volume

def test_paused_menu_audio_is_not_stopped_on_every_update():
    l,t,p=host();client(t,p)
    a=t.module('Audio').new(t.module('Config'));a.settings(t.module('Rules').cleanSettings(None))
    a.update(.2,True,None);a.play('upgrade');stops=a.pool.upgrade.stopCount
    for _ in range(20):a.update(.05,True,None)
    assert a.pool.upgrade.stopCount==stops

def test_optional_tips_hide_but_tutorial_and_danger_notices_remain():
    l,t,p=host();client(t,p);visit(t,p,'▶  开始标准远征')
    t.action(p,'settings',table(l,key='showTips',value=False));t.render(.2)
    assert not by_name(p.PlayerGui,'Guide').Visible and not by_name(p.PlayerGui,'GuideBack').Visible
    s=t.session(p).game;s.hull=200;t.step(.2);t.render(.2)
    assert '告急' in by_name(p.PlayerGui,'Notice').Text
    t.action(p,'abandon','confirm');t.action(p,'start','tutorial');t.render(.2)
    assert by_name(p.PlayerGui,'Guide').Visible

def test_shortcuts_can_be_disabled_without_disabling_mouse_or_diagnostics():
    l,t,p=host(strictAPI=True);client(t,p);visit(t,p,'▶  开始标准远征')
    t.action(p,'settings',table(l,key='hotkeys',value=False));t.render(.2)
    t.key('P',True);t.key('One',True);t.render(.2)
    assert not t.session(p).game.paused
    assert by_name(p.PlayerGui,'Tab_weapons').SelectedMark.Visible
    t.key('F6',True);assert p.PlayerGui.DustboundPerformance.Enabled
    visit(t,p,'Ⅱ');assert t.session(p).game.paused

def test_back_returns_to_parent_but_close_dismisses_stack():
    l,t,p=host();client(t,p);visit(t,p,'武器工坊');click_name(t,p,'Weapon_arc');click_name(t,p,'GoUnlock')
    assert by_name(modal(p),'Back')
    click_name(t,p,'Back');assert by_name(modal(p),'WeaponList')
    click_name(t,p,'GoUnlock');click_name(t,p,'Close')
    assert not p.PlayerGui.DustboundPanels.SafeCanvas.ModalStage.Visible

def test_paid_reroll_is_not_charged_until_confirmed():
    l,t,p=host();client(t,p);visit(t,p,'▶  开始标准远征');s=to_mining(l,t,p)
    s.ore=500;t.action(p,'ready');t.render(.2)
    click_name(t,p,'Reroll');assert s.rerolls==1 and s.ore==500
    click_name(t,p,'Reroll');assert s.rerolls==1 and s.ore==500
    assert by_name(modal(p),'ConfirmReroll')
    click_name(t,p,'CancelReroll');assert s.rerolls==1
    click_name(t,p,'Reroll');click_name(t,p,'ConfirmReroll')
    assert s.rerolls==2 and s.ore==420
    healthy(t,p)

def test_stale_paid_reroll_confirmation_cannot_charge():
    l,t,p=host();client(t,p);visit(t,p,'▶  开始标准远征');s=to_mining(l,t,p)
    s.ore=500;t.action(p,'ready');t.render(.2);click_name(t,p,'Reroll');click_name(t,p,'Reroll')
    s.supply.token+=1;t.action(p,'ready');t.render(.3)
    assert not by_name(modal(p),'ConfirmReroll').Active and s.ore==500

def test_advanced_view_retains_live_diagnostics_after_settings_change():
    l,t,p=host();client(t,p);visit(t,p,'设置');click_name(t,p,'SettingsTab_display');click_name(t,p,'EnemyHealth')
    click_name(t,p,'SettingsTab_advanced');count=t.counters.destroyed
    for _ in range(180):t.render(1/60)
    assert t.counters.destroyed==count and 'P95' in by_name(modal(p),'Performance').Text

def test_motion_preferences_affect_real_visibility_and_base_position():
    l,t,p=motion_fixture()
    assert l.execute('''
      local defaults=R.cleanSettings(nil)
      defaults.enemyHealth=false;defaults.flashEffects=false;defaults.screenShake=false
      local U=T.module("UI");local root=Instance.new("Frame")
      local function f() return U.frame(root,"fixture",0,0,10,10,nil,1) end
      local base=f();local muzzle=f()
      local test=T.module("Motion").new({C=C0,Art=T.module("Art"),colors=U.colors,frame=U.frame,corner=U.corner,enemiesLayer=f(),robotLayer=f(),fxLayer=f(),turret=f(),base=base,muzzle=muzzle,auxiliary=f(),reduced=function() return false end,numbers=function() return true end,options=function() return defaults end})
      test.sync(G.snapshot(S,C0,R));test.events({{kind="basehit",amount=1},{kind="impact",x=1,y=1,weapon="cannon"}});test.recoil=3;test.update(.01)
      return not test.actors[1].hp.Visible and not test.actors[1].flash.Visible and not muzzle.Visible and test.shake==0 and base.Position.xo==242
    ''')

@pytest.mark.parametrize('width,height',[(1440,810),(844,390),(667,375)])
def test_main_cta_and_navigation_do_not_overlap(width,height):
    l,t,p=host(width=width,height=height);client(t,p,width<1000)
    rail=by_name(p.PlayerGui,'NavigationRail');play=by_name(p.PlayerGui,'PlayCard')
    assert rail.Position.xo+rail.Size.xo<play.Position.xo
    assert by_name(p.PlayerGui,'Start').Size.yo>=70
    assert by_name(p.PlayerGui,'Start').GetAttribute(by_name(p.PlayerGui,'Start'),'Primary')
    healthy(t,p)
