"""Performance regressions verified as operations/invariants, NOT measured Roblox FPS."""
from pathlib import Path
import pytest
from test_ui import host,client,visit,healthy,by_name,click_name,modal,to_mining
ROOT=Path(__file__).resolve().parents[1]

def setup_art(**kw):
    l,t,p=host(**kw);client(t,p)
    l.globals().Art=t.module('Art');l.globals().Data=t.module('ArtData')
    return l,t,p

def test_stripe_decode_matches_original_full_atlas_byte_for_byte():
    l,t,p=setup_art()
    assert l.execute('''
      local palette={};local source=Data
      for i=1,#source.palette,8 do palette[(i-1)/8]=string.char(tonumber(source.palette:sub(i,i+1),16),tonumber(source.palette:sub(i+2,i+3),16),tonumber(source.palette:sub(i+4,i+5),16),tonumber(source.palette:sub(i+6,i+7),16)) end
      local old={}
      for i=1,#source.rle,6 do old[#old+1]=string.rep(palette[tonumber(source.rle:sub(i+4,i+5),16)],tonumber(source.rle:sub(i,i+3),16)) end
      local chunks={};local checkpoints=0;local writes=0
      local n=Art.decode(source,function(y,rows,bytes)
        assert(y==writes*32 and rows==32 and #bytes==131072)
        writes=writes+1;chunks[#chunks+1]=bytes
      end,function(progress) assert(progress>=0 and progress<=1);checkpoints=checkpoints+1 end)
      return n==1024*1024 and writes==32 and checkpoints>=32 and table.concat(chunks)==table.concat(old)
    ''')

def test_rle_run_crosses_stripe_without_losing_rgba_pixels():
    l,t,p=setup_art()
    assert l.execute('''
      local chunks={}
      Art.decode({size=64,palette="ff0000ff00000000",rle="08340007cc01"},function(y,rows,bytes) chunks[#chunks+1]=bytes end)
      return table.concat(chunks)==string.rep(string.char(255,0,0,255),2100)..string.rep(string.char(0,0,0,0),1996)
    ''')

@pytest.mark.parametrize('rle',['','000000','000101','000200'])
def test_corrupt_rle_rejected_not_written_as_complete_image(rle):
    l,t,p=setup_art();l.globals().bad=rle
    assert l.execute('''local ok=pcall(function() Art.decode({size=1,palette="ff0000ff",rle=bad},function() end) end);return not ok''')

def test_loading_yields_and_reuses_single_decoded_atlas():
    l,t,p=setup_art(strictAPI=True)
    assert t.counters.pixelWrites==32 and t.counters.yields>=32
    before=t.counters.pixelWrites;t.module('Art').init()
    assert t.counters.pixelWrites==before
    assert p.PlayerGui.GetAttribute(p.PlayerGui,'FrontierLoadProgress')==1

def test_image_api_failure_keeps_fallback_ready_and_yields_construction():
    l,t,p=setup_art(imageDisabled=True,strictAPI=True)
    assert t.module('Art').mode=='fallback' and t.counters.pixelWrites==0
    assert t.counters.yields>10
    assert t.module('Art').yieldFrame is None
    healthy(t,p)

def test_ready_requires_render_handoff_not_merely_a_network_snapshot():
    l,t,p=host(clientFrames=0)
    t.enableClient(p,(ROOT/'src/Client.client.lua').read_text(),False)
    assert not p.PlayerGui.GetAttribute(p.PlayerGui,'FrontierGameReady')
    t.render(1/60);assert not p.PlayerGui.GetAttribute(p.PlayerGui,'FrontierGameReady')
    t.render(1/60);assert p.PlayerGui.GetAttribute(p.PlayerGui,'FrontierGameReady')
    healthy(t,p)

def test_boot_progress_uses_real_work_stage_not_elapsed_time():
    l,t,p=host(noServer=True);t.boot(p,(ROOT/'src/Boot.client.lua').read_text())
    pg=p.PlayerGui;pg.SetAttribute(pg,'FrontierLoadProgress',.37)
    t.step(.3)
    assert by_name(pg.FrontierBoot,'Progress').Size.xs==pytest.approx(.37)
    t.step(5)
    assert by_name(pg.FrontierBoot,'Progress').Size.xs==pytest.approx(.37)

def test_boot_stops_polling_after_ready_and_runtime_error_still_surfaces():
    l,t,p=host();t.boot(p,(ROOT/'src/Boot.client.lua').read_text())
    pg=p.PlayerGui;pg.SetAttribute(pg,'FrontierGameReady',True)
    assert not pg.FrontierBoot.Enabled
    before=t.counters.bootAssignments;t.step(2)
    assert t.counters.bootAssignments==before
    t.network().BootError.Value='synthetic server error';t.network().BootStatus.Value='ERROR'
    assert pg.FrontierBoot.Enabled and by_name(pg.FrontierBoot,'Diagnostics').Visible

def test_planner_retains_controls_and_scroll_position_while_values_update():
    l,t,p=host(strictAPI=True);client(t,p);visit(t,p,'▶  开始标准远征')
    s=to_mining(l,t,p);visit(t,p,'接收补给');visit(t,p,'情报 / 经营台')
    body=by_name(modal(p),'PlanningDetails');cargo=by_name(body,'Cargo')
    body.CanvasPosition=l.globals().Vector2.new(0,180)
    before=t.counters.destroyed;text=cargo.Text
    for _ in range(30): t.step(.1);t.render(.1)
    assert t.counters.destroyed==before
    assert l.eval('function(a,b) return a==b end')(body,by_name(modal(p),'PlanningDetails'))
    assert body.CanvasPosition.Y==180 and cargo.Text!=text
    healthy(t,p)

def test_retained_allocation_button_uses_latest_state_not_captured_state():
    l,t,p=host();client(t,p);visit(t,p,'▶  开始标准远征');click_name(t,p,'Planner')
    initial=by_name(modal(p),'Allocation')
    for mode in ['mining','defense','balanced']:
        click_name(t,p,'Allocation');assert t.session(p).game.allocation==mode
        assert l.eval('function(a,b) return a==b end')(initial,by_name(modal(p),'Allocation'))
    healthy(t,p)

@pytest.mark.parametrize('paused',[False,True])
def test_idle_render_frames_do_not_rebuild_or_animate_hidden_battlefield(paused):
    l,t,p=host();client(t,p)
    if paused:visit(t,p,'▶  开始标准远征');visit(t,p,'Ⅱ')
    for _ in range(30):t.render(1/60)
    before=t.counters.assignments;objects=t.counters.instances
    for _ in range(180):t.render(1/60)
    assert t.counters.instances==objects
    assert t.counters.assignments-before<80

def test_packet_burst_coalesces_hud_paints_until_next_render():
    l,t,p=host();client(t,p);visit(t,p,'▶  开始标准远征')
    label=by_name(p.PlayerGui,'Ore');previous=label.Text
    s=t.session(p).game
    for value in [701,702,703]:
        s.ore=value;t.advanceClock(.3);t.action(p,'ready')
    assert label.Text==previous
    t.render(.2);assert label.Text=='矿料 703'

def test_f6_diagnostics_toggle_does_not_pause_game():
    l,t,p=host(strictAPI=True);client(t,p);visit(t,p,'▶  开始标准远征')
    t.key('F6',True)
    assert p.PlayerGui.DustboundPerformance.Enabled
    for _ in range(70):t.render(1/60)
    text=by_name(p.PlayerGui.DustboundPerformance,'Readout').Text
    assert 'P95' in text and '近 180 帧' in text
    assert not t.session(p).game.paused
    t.key('F6',True);assert not p.PlayerGui.DustboundPerformance.Enabled

def test_settings_diagnostics_refresh_does_not_rebuild_settings():
    l,t,p=host();client(t,p);visit(t,p,'设置');click_name(t,p,'SettingsTab_advanced')
    body=by_name(modal(p),'SettingsDetails');before=t.counters.destroyed
    for _ in range(130):t.render(1/60)
    assert t.counters.destroyed==before
    assert 'P95' in by_name(body,'Performance').Text
    click_name(t,p,'ToggleDiagnostics');assert p.PlayerGui.DustboundPerformance.Enabled

def test_zero_viewport_recovery_builds_once_and_becomes_ready():
    l,t,p=host(width=0,height=0);t.enableClient(p,(ROOT/'src/Client.client.lua').read_text(),False)
    assert not p.PlayerGui.GetAttribute(p.PlayerGui,'FrontierGameReady')
    l.globals().workspace.CurrentCamera.ViewportSize=l.globals().Vector2.new(1440,810)
    for _ in range(20):t.render(1/60)
    assert p.PlayerGui.GetAttribute(p.PlayerGui,'FrontierGameReady');healthy(t,p)

def motion_fixture():
    l,t,p=host();client(t,p);l.globals().T=t;l.globals().P=p
    l.execute('''
      local U=T.module("UI");local C=T.module("Config");local Art=T.module("Art")
      local root=Instance.new("Frame")
      local function f() return U.frame(root,"fixture",0,0,10,10,nil,1) end
      M=T.module("Motion").new({C=C,Art=Art,colors=U.colors,frame=U.frame,corner=U.corner,enemiesLayer=f(),robotLayer=f(),fxLayer=f(),turret=f(),base=f(),muzzle=f(),auxiliary=f(),reduced=function() return false end,numbers=function() return true end})
      S=T.session(P).game;G=T.module("Core");R=T.module("Rules");C0=C
      G.start(S,C,R)
      S.enemies={{id=1,kind="crawler",x=1100,y=410,hp=29,maxHp=29,speed=28,spawnAt=0,hitAt=-100,attackAt=-100}}
    ''')
    return l,t,p

def test_visual_clock_does_not_rewind_when_packet_arrives_between_ticks():
    l,t,p=motion_fixture()
    assert l.execute('''
      M.sync(G.snapshot(S,C0,R));M.update(.05);local before=M.time
      S.elapsed=.03;M.sync(G.snapshot(S,C0,R));M.update(.01)
      local advanced=M.time>=before
      S.runId=S.runId+1;S.elapsed=0;M.sync(G.snapshot(S,C0,R))
      return advanced and M.time==0
    ''')

def test_prewarm_reserves_are_bounded_and_distinct():
    l,t,p=motion_fixture()
    assert l.execute('''M.prewarm();return #M.pool.crawlerBody==2 and #M.pool.tankBody==1 and #M.fxPool.Frame==8 and #M.fxPool.TextLabel==8 and M.robots[1]~=M.robots[2]''')

def test_leg_pose_is_not_recomputed_on_every_high_refresh_frame():
    l,t,p=motion_fixture();l.execute('M.sync(G.snapshot(S,C0,R));M.update(.01)')
    before=t.counters.assignments;l.execute('M.update(.005)');small=t.counters.assignments-before
    before=t.counters.assignments;l.execute('M.update(.034)');pose=t.counters.assignments-before
    assert pose>small+40
