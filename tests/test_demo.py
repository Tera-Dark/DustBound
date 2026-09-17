from test_ui import host,client,visit,click_name,modal,by_name,healthy

def test_grid_has_short_axis_aligned_edges_and_cross_prerequisite_markers():
 l,t,p=host();client(t,p);visit(t,p,'研究中心');tree=modal(p).TechTree
 edges=[o for o in tree.GetChildren(tree).values() if str(o.Name).startswith('Dependency_')]
 assert len(edges)==41
 assert all(o.Rotation==0 and o.Size.xo<=58 for o in edges)
 assert by_name(tree,'CrossPrerequisite') is not None
 c=t.module('Config');m=t.module('TechMap')
 for branch in c.Tech.branches.values():
  points=[m.position(c.Tech.nodes[f'{branch.id}_{i}']) for i in range(1,9)]
  assert len(set(y for x,y in points))==1 and all(points[i+1][0]-points[i][0]==176 for i in range(7))

def test_ready_jump_and_precise_resource_gap():
 l,t,p=host();client(t,p);visit(t,p,'研究中心')
 assert by_name(modal(p),'FindReadyTech').Active is False
 assert '缺' in by_name(modal(p),'TechStatus').Text
 s=t.session(p).game;s.profile.alloy=500;s.profile.research=100;t.action(p,'ready');t.render(.3)
 click_name(t,p,'FindReadyTech');assert by_name(modal(p),'TechInspector_fort_1') is not None
 healthy(t,p)

def test_lobby_campaign_resumes_next_unfinished_node():
 l,t,p=host();client(t,p);s=t.session(p).game;s.profile.campaignCleared=9;t.action(p,'ready');t.render(.3)
 visit(t,p,'▶  星球远征 · 24 关')
 assert '2-02' in by_name(modal(p),'MissionTitle').Text
 healthy(t,p)

def test_mobile_codex_reduces_portrait_scroll_cost():
 l,t,p=host();client(t,p,True);visit(t,p,'远征图鉴')
 assert by_name(modal(p),'Illustration_cannon').Size.yo<=142 or by_name(modal(p),'Illustration_cannon').Size.yo==72
 body=by_name(modal(p),'EntryText');assert body.Position.yo==158
