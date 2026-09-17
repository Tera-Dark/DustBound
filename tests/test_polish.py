"""0.5.1 regression tests. Pure Lua + mock GUI, NOT Roblox Studio playtesting."""
from pathlib import Path
import pytest
from test_core import env, start, mining, accept, run, table, enemy
from test_ui import host, client, visit, healthy, by_name, click_name, modal, to_mining

ROOT = Path(__file__).resolve().parents[1]

def guide(l):
    return l.execute((ROOT/'src/Guide.lua').read_text())

def test_recommendation_skips_capped_and_full_hull_repairs(env):
    l,c,r,g,s=start(env)
    s.ore=100000
    for key in c.Upgrades.keys(): s.upgrades[key]=c.Upgrades[key].cap
    s.upgrades.regen=0
    rec=guide(l).recommend(g.snapshot(s,c,r),c,r)
    assert rec.id=='regen' and rec.info.can

def test_recommendation_no_affordable_upgrade_still_explains_gap(env):
    l,c,r,g,s=start(env);s.ore=0
    rec=guide(l).recommend(g.snapshot(s,c,r),c,r)
    assert not rec.info.can and rec.info.gap>0 and '还差' in rec.info.reason

def test_recommendation_all_capped_does_not_require_another_purchase(env):
    l,c,r,g,s=start(env)
    for key in c.Upgrades.keys(): s.upgrades[key]=c.Upgrades[key].cap
    rec=guide(l).recommend(g.snapshot(s,c,r),c,r)
    assert not rec.info.can and '保留矿料' in rec.reason

def test_supply_default_avoids_full_hull_repair(env):
    l,c,r,g,s=mining(env)
    ss=g.snapshot(s,c,r);h=guide(l)
    assert h.supplyChoice(ss,c,r)=='drill'
    assert h.supply('repair',ss,c,r).score==0
    assert '耐久已满' in h.supply('repair',ss,c,r).tip

def test_supply_heal_preview_respects_tech_and_missing_hull(env):
    l,c,r,g,s=mining(env);s.hull=s.maxHull-27
    text=guide(l).supply('repair',g.snapshot(s,c,r),c,r).detail
    assert '27' in text

def test_last_tutorial_supply_does_not_recommend_combat_buff(env):
    l,c,r,g,s=env;g.start(s,c,r,'tutorial');mining(env,3)
    ss=g.snapshot(s,c,r);h=guide(l)
    assert h.supplyChoice(ss,c,r)=='ore'
    for key in ('ammo','shield','overclock'):
        assert h.supply(key,ss,c,r).score==0 and '最后' in h.supply(key,ss,c,r).tip

def test_wave_ten_supply_explains_overtime_only_use(env):
    l,c,r,g,s=mining(env,10)
    assert '追加' in guide(l).supply('ammo',g.snapshot(s,c,r),c,r).tip

def test_supply_preview_does_not_mutate_economy(env):
    l,c,r,g,s=mining(env);ss=g.snapshot(s,c,r);h=guide(l);ore=s.ore
    for key in c.Catalog.supplies.keys(): h.supply(key,ss,c,r)
    assert s.ore==ore and s.supply and s.totalMined==0

def test_buffs_identify_waiting_and_active_phase(env):
    l,c,r,g,s=mining(env);s.effects.ammo=35;s.effects.drill=30
    h=guide(l);text=h.buffs(g.snapshot(s,c,r),c)
    assert '钻机加速 30s·待机' in text and '强化弹药 35s·待机' in text
    accept(env,'drill');text=h.buffs(g.snapshot(s,c,r),c)
    assert '钻机加速 30s·待机' not in text and '强化弹药 35s·待机' in text

def test_run_ledger_tracks_purchases_rerolls_airdrops_and_resets(env):
    l,c,r,g,s=start(env)
    assert g.act(s,c,r,'buy','damage');assert s.ledger.spent==110
    mining(env);s.ore=500
    assert g.act(s,c,r,'reroll',s.supply.token)
    # First reroll exposes ore; no fabricated pickup accounting.
    accept(env,'ore');assert s.ledger.airdrop==180 and s.totalMined==0
    g.act(s,c,r,'abandon','confirm');g.start(s,c,r)
    assert s.ledger.spent==0 and s.ledger.airdrop==0 and len(s.reports)==0

def test_salvage_ledger_tracks_actual_reward(env):
    l,c,r,g,s=start(env);s.spawnClock=-100
    s.enemies=l.table_from([enemy(l,hp=1,x=950)])
    run(c,r,g,s,2)
    assert s.kills==1 and s.ledger.salvaged==8

def test_wave_reports_preserved_and_lost_cargo_not_income(env):
    l,c,r,g,s=mining(env)
    assert len(s.reports)==1 and s.reports[1].wave==1
    accept(env);run(c,r,g,s,30)
    assert s.ledger.lostCargo>0 and s.totalMined>0
    assert s.ore==pytest.approx(120+s.totalMined)

def test_five_second_warning_once_and_paused_timer_frozen(env):
    l,c,r,g,s=mining(env);accept(env)
    s.breakLeft=5.1;s.events=l.table()
    run(c,r,g,s,1)
    count=sum(e.kind=='readywave' for e in s.events.values())
    assert count==1
    g.act(s,c,r,'pause',True);left=s.breakLeft
    run(c,r,g,s,3);assert s.breakLeft==left

def test_regen_cannot_resurrect_zero_hull(env):
    l,c,r,g,s=start(env);s.upgrades.regen=3;s.hull=0
    g.step(s,c,r,.1)
    assert s.phase=='ended' and not s.result.won

def test_pressure_death_cannot_enter_mining(env):
    l,c,r,g,s=start(env);s.waveElapsed=101;s.hull=.1
    s.enemies=l.table();s.projectiles=l.table()
    g.step(s,c,r,.1)
    assert s.phase=='ended' and not s.result.won and s.supply is None

def test_effective_hull_damage_excludes_overkill(env):
    l,c,r,g,s=start(env);s.hull=3;s.spawnClock=-100
    e=enemy(l,x=650);e.attack=0;s.enemies=l.table_from([e])
    g.step(s,c,r,.1)
    assert s.waveTaken==3 and s.result.hull==0

def test_low_hull_warning_does_not_repeat_every_tick(env):
    l,c,r,g,s=start(env);s.hull=200;s.spawnClock=-100
    run(c,r,g,s,1)
    assert sum(e.kind=='lowhull' for e in s.events.values())==1
    s.hull=500;g.step(s,c,r,.1);s.hull=200;g.step(s,c,r,.1)
    assert sum(e.kind=='lowhull' for e in s.events.values())==2

def test_failure_settlement_explains_loss_retention(env):
    l,c,r,g,s=start(env);s.hull=0;g.step(s,c,r,.1)
    assert '35%' in guide(l).settlement(g.snapshot(s,c,r),c,r)
    assert '复盘' in guide(l).debrief(g.snapshot(s,c,r),c,r)

@pytest.mark.parametrize('touch',[False,True])
def test_help_panel_opens_and_closes_without_starting_game(touch):
    l,t,p=host(strictAPI=True);client(t,p,touch)
    click_name(t,p,'Help')
    assert by_name(modal(p),'HelpTitle6') is not None
    click_name(t,p,'HelpDone')
    assert t.session(p).game.phase=='menu';healthy(t,p)

@pytest.mark.parametrize('touch',[False,True])
def test_contextual_supply_is_selected_in_ui(touch):
    l,t,p=host(strictAPI=True);client(t,p,touch)
    visit(t,p,'3 波教学 · 推荐');s=to_mining(l,t,p)
    assert '实际修复 0' in by_name(by_name(modal(p),'Choice_repair'),'Detail').Text
    visit(t,p,'接收补给');assert s.effects.drill>0
    healthy(t,p)

def test_compact_upgrade_text_does_not_overlap_buy_button():
    l,t,p=host(width=844,height=390);client(t,p,True)
    visit(t,p,'▶  开始标准远征')
    card=by_name(p.PlayerGui,'UpgradeCard')
    d=card.FindFirstChild(card,'Detail');b=card.FindFirstChild(card,'Buy')
    assert d.Position.xo+d.Size.xo<=b.Position.xo-10

def test_combat_planner_does_not_claim_mining_income():
    l,t,p=host();client(t,p);visit(t,p,'▶  开始标准远征')
    click_name(t,p,'Planner')
    assert by_name(modal(p),'Title').Text=='战况情报'
    assert '不产生采矿收入' in by_name(modal(p),'Cargo').Text
    healthy(t,p)

def test_failed_tutorial_retry_stays_in_tutorial():
    l,t,p=host();client(t,p);visit(t,p,'3 波教学 · 推荐')
    s=t.session(p).game;s.hull=0;t.step(.2);t.render(.2)
    assert by_name(modal(p),'Again').Text=='重试三波教学'
    click_name(t,p,'Again');assert s.mode=='tutorial' and s.phase=='running'
    healthy(t,p)

def test_server_returns_specific_rejection_not_generic_error():
    l,t,p=host();t.action(p,'start','standard');t.action(p,'buy','repair')
    assert t.session(p).actionResult=='耐久已满'

@pytest.mark.parametrize('touch',[False,True])
def test_result_contains_ledger_and_debrief(touch):
    l,t,p=host(strictAPI=True);client(t,p,touch);visit(t,p,'▶  开始标准远征')
    s=t.session(p).game;t.action(p,'buy','damage');s.hull=0;t.step(.2);t.render(.2)
    assert '消费 110' in by_name(modal(p),'Ledger').Text
    assert '复盘' in by_name(modal(p),'Debrief').Text
    assert '35%' in by_name(modal(p),'SettlementRule').Text
    healthy(t,p)

def test_energy_allocation_highlight_tracks_authoritative_state():
    l,t,p=host();client(t,p);visit(t,p,'▶  开始标准远征')
    click_name(t,p,'Power_mining')
    button=by_name(p.PlayerGui,'Power_mining')
    assert t.session(p).game.allocation=='mining'
    assert button.BackgroundColor3[2]==226
    healthy(t,p)

def test_workshop_exposes_existing_second_preset_slot():
    l,t,p=host(strictAPI=True);client(t,p)
    s=t.session(p).game;s.profile.tech.energy_2=True;t.action(p,'ready')
    visit(t,p,'武器工坊');click_name(t,p,'Weapon_arc');click_name(t,p,'Equip_arc')
    click_name(t,p,'PresetSlot');click_name(t,p,'SavePreset')
    assert s.profile.presets[2]=='arc' and s.profile.presets[1]=='machine'
    click_name(t,p,'Weapon_machine');click_name(t,p,'Equip_machine');click_name(t,p,'UsePreset')
    assert s.loadout=='arc';healthy(t,p)
