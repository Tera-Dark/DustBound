"""Campaign authority, progression, reward economy, gallery and large-map regressions."""
import pytest
from test_ui import host,client,visit,click_name,by_name,modal,healthy
from campaign_pilot import setup,play,run

def test_all_24_nodes_ramp_without_wave_or_stat_backtracking():
 l,c,r,g,s=setup();last=None
 for i in range(1,25):
  n=c.Catalog.campaign[i]
  assert n.id==i and n.node==(i-1)%8+1 and n.planet==(i-1)//8+1
  if last:assert 0<=n.waves-last.waves<=1 and n.hp>last.hp and n.attack>last.attack and n.density>last.density
  last=n
 assert c.Catalog.campaign[1].waves==3 and last.waves==12

@pytest.mark.parametrize('bad',[0,2,24,25,1.2,'1',float('nan'),float('inf'),-1])
def test_locked_or_malformed_mission_cannot_start(bad):
 l,c,r,g,s=setup();before=s.profile.runSerial
 assert not g.start(s,c,r,l.table_from({'node':bad}))
 assert s.phase=='menu' and s.profile.runSerial==before

def test_first_clear_unlocks_once_and_repeat_has_lower_reward():
 l,c,r,g,s=setup();first=play(l,c,r,g,s,1)
 assert s.profile.campaignCleared==1 and s.result.firstClear
 repeat=play(l,c,r,g,s,1)
 assert not s.result.firstClear and s.profile.campaignCleared==1
 assert 0<repeat['alloy']<first['alloy'] and 0<repeat['research']<first['research']
 assert g.start(s,c,r,l.table_from({'node':2}))

def test_failure_keeps_progress_rewards_but_no_core_and_no_unlock():
 l,c,r,g,s=setup();assert g.start(s,c,r,l.table_from({'node':1}))
 s.wave=2;s.kills=13;s.hull=0;g.step(s,c,r,.1)
 assert s.result and not s.result.won and s.result.alloy>0 and s.result.research>0 and s.result.cores==0
 assert s.profile.campaignCleared==0
 old=(s.profile.alloy,s.profile.research);g.step(s,c,r,.1)
 assert old==(s.profile.alloy,s.profile.research)

def test_immediate_surrender_has_no_reward():
 l,c,r,g,s=setup();g.start(s,c,r,l.table_from({'node':1}));s.hull=0;g.step(s,c,r,.1)
 assert s.result.alloy==s.result.research==s.result.crystals==s.result.cores==0

def test_refinery_affects_campaign_data_and_preview():
 l,c,r,g,s=setup();g.start(s,c,r,l.table_from({'node':1}))
 before=g.snapshot(s,c,r).dataPreview;s.upgrades.refinery=2
 assert g.snapshot(s,c,r).dataPreview==int(before*1.4)

def test_legacy_five_migration_preserves_wallet_tech_and_new_progress():
 l,c,r,g,s=setup();p=r.cleanProfile(l.table_from({'schema':5,'alloy':888,'tech':{'energy_2':True},'loadout':'arc'},recursive=True))
 assert p.schema==6 and p.campaignCleared==0 and p.alloy==888 and p.tech.energy_2 and p.loadout=='arc'
 p.campaignCleared=12;q=r.cleanProfile(p);assert q.campaignCleared==12

@pytest.mark.parametrize('progress,expected',[(99,24),(-5,0),(2.9,2),('24',0),(float('nan'),0)])
def test_campaign_save_sanitization(progress,expected):
 l,c,r,g,s=setup();p=r.cleanProfile(l.table_from({'campaignCleared':progress}));assert p.campaignCleared==expected

def test_continuous_24_node_pilot_without_injected_resources_or_replays():
 rows=run();assert len(rows)==24 and all(x['won'] for x in rows)
 assert sum(len(x['researchBefore']) for x in rows)>=20

def test_unresearched_late_node_is_meaningfully_harder():
 l,c,r,g,s=setup();s.profile.campaignCleared=23 # isolation only: unlock, NOT resources/stat grants
 row=play(l,c,r,g,s,24);assert not row['won'] and row['wave']<12 and row['alloy']>0

@pytest.mark.parametrize('touch',[False,True])
def test_campaign_ui_navigation_launch_lock_and_rewards(touch):
 l,t,p=host();client(t,p,touch);visit(t,p,'▶  星球远征 · 24 关');click_name(t,p,'Planet_3')
 assert by_name(modal(p),'LaunchMission').Active is False
 assert by_name(modal(p),'MissionReward') is not None
 click_name(t,p,'Planet_1');click_name(t,p,'LaunchMission')
 s=t.session(p).game;assert s.mode=='campaign' and s.campaignNode==1
 healthy(t,p)

@pytest.mark.parametrize('fallback',[False,True])
def test_gallery_lazy_load_reuse_and_native_fallback(fallback):
 l,t,p=host(imageDisabled=fallback,strictAPI=True);client(t,p)
 before=t.counters.pixelWrites;visit(t,p,'远征图鉴');t.step(.1);t.render(.1)
 gallery=t.module('Gallery');assert gallery.mode==('fallback' if fallback else 'embedded')
 assert t.counters.pixelWrites==before+(0 if fallback else 16)
 art=by_name(modal(p),'GalleryArtwork');assert art is not None
 if not fallback:assert art.ImageContent is not None
 click_name(t,p,'Entry_rail');t.step(.1);assert t.counters.pixelWrites==before+(0 if fallback else 16)
 healthy(t,p)

def test_tech_map_all_dependency_edges_and_desktop_drag():
 l,t,p=host(strictAPI=True);client(t,p);visit(t,p,'研究中心');
 for _ in range(6):click_name(t,p,'ZoomIn')
 tree=modal(p).TechTree;c=t.module('Config')
 expected=sum(sum(c.Tech.nodes[pre].column==n.column for pre in n.prereqs.values()) for n in c.Tech.nodes.values())
 edges=[x for x in tree.GetChildren(tree).values() if str(x.Name).startswith('Dependency_')]
 assert len(edges)==expected
 l.globals().Tree=tree
 assert l.execute('''local u=game:GetService("UserInputService")
 Tree.CanvasPosition=Vector2.new(100,100)
 Tree.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position={X=300,Y=300}})
 u.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position={X=270,Y=270}})
 local moved=Tree.CanvasPosition.X>100
 u.InputEnded:Fire({UserInputType=Enum.UserInputType.MouseButton1})
 local x=Tree.CanvasPosition.X;u.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position={X=0,Y=0}})
 return moved and Tree.CanvasPosition.X==x''')
 healthy(t,p)

def test_tech_cards_do_not_overlap_at_any_zoom():
 l,t,p=host();c=t.module('Config');m=t.module('TechMap');nodes=list(c.Tech.nodes.values())
 for i,a in enumerate(nodes):
  ax,ay=m.position(a)
  for b in nodes[i+1:]:
   bx,by=m.position(b)
   assert abs(ax-bx)>=132 or abs(ay-by)>=92,(a.id,b.id)

def test_schema_six_cloud_roundtrip_preserves_campaign_progress():
 l,t,p=host(cloud=True);client(t,p);s=t.session(p).game
 s.profile.campaignCleared=8
 t.action(p,'settings',l.table_from({'key':'screenShake','value':False}))
 t.leave(p);p2=t.join(42)
 assert t.session(p2).game.profile.campaignCleared==8
 assert t.session(p2).game.profile.settings.screenShake is False

def test_fit_restores_whole_tree_after_focusing_outer_node():
 l,t,p=host();client(t,p);visit(t,p,'研究中心');click_name(t,p,'Tech_fort_8');click_name(t,p,'FocusTech');click_name(t,p,'FitTree')
 tree=modal(p).TechTree
 assert tree.CanvasPosition.X==pytest.approx(0) and tree.CanvasPosition.Y==pytest.approx(0)

def test_gallery_embedded_bytes_match_runtime_atlas():
 from PIL import Image
 from pathlib import Path
 l,t,p=host();l.globals().expected=Image.open(Path(__file__).resolve().parents[1]/'assets/expedition-gallery-runtime.png').convert('RGBA').tobytes()
 l.globals().T=t
 assert l.execute('local chunks={};T.module("Art").decode(T.module("GalleryData"),function(y,rows,bytes) chunks[#chunks+1]=bytes end);return table.concat(chunks)==expected')
