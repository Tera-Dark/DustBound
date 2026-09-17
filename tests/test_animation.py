"""Offline presentation invariants, not engine FPS measurements."""
import pytest
from test_performance import motion_fixture

@pytest.mark.parametrize('boundary',[.25,.28,.68,.72,.95,1])
def test_robot_path_continuity(boundary):
 l,t,p=motion_fixture();l.globals().b=boundary
 assert l.execute('local A=T.module("Animation");local x,d=A.robotPath(b-1e-7,2);local y,e=A.robotPath(b%1,2);return math.abs(x-y)<.001 and math.abs(d-e)<.001')

def test_spring_rate_independence():
 l,t,p=motion_fixture()
 assert l.execute('local A=T.module("Animation");local x,v=6,0;for i=1,60 do x,v=A.spring(x,v,23,1/60) end;local y,w=A.spring(6,0,23,1);return math.abs(x-y)<1e-10 and math.abs(v-w)<1e-10')

def test_five_mounts_only_two_active():
 l,t,p=motion_fixture()
 assert l.execute('M.sync(G.snapshot(S,C0,R));return #M.weapons.slots==5 and M.weapons.activeCount==2 and M.weapons.slots[3].empty.Visible and not M.weapons.slots[5].mount.Visible')

def test_short_shot_survives_absent_snapshot_and_deduplicates():
 l,t,p=motion_fixture()
 assert l.execute('''
 M.sync(G.snapshot(S,C0,R))
 local e={kind="shot",weapon="machine",slot=2,x=1000,y=420,projectile={id=99,weapon="machine",slot=2,x=602,y=275,tx=1000,ty=398,duration=.08,born=0}}
 M.events({e});M.events({e});local n=0;for _ in pairs(M.shots) do n=n+1 end
 S.elapsed=.05;M.sync(G.snapshot(S,C0,R));local retained=M.shots[99]~=nil
 S.elapsed=.2;M.sync(G.snapshot(S,C0,R));M.update(.1)
 return n==1 and retained and M.shots[99]==nil
 ''')

def test_pause_and_restart_clear_transients():
 l,t,p=motion_fixture()
 assert l.execute('''M.sync(G.snapshot(S,C0,R));M.events({{kind="shot",weapon="machine",x=1000,y=420}});M.update(.05)
 S.paused=true;M.sync(G.snapshot(S,C0,R));local clock=M.renderTime;local recoil=M.weapons.slots[2].recoil
 for i=1,30 do M.update(.1) end
 local frozen=M.renderTime==clock and M.weapons.slots[2].recoil==recoil
 S.runId=S.runId+1;S.elapsed=0;M.sync(G.snapshot(S,C0,R))
 return frozen and #M.queue==0 and M.weapons.slots[2].recoil==0 and M.weapons.time==0''')

def test_projectile_and_event_caps():
 l,t,p=motion_fixture()
 assert l.execute('''M.sync(G.snapshot(S,C0,R));local events={}
 for i=1,400 do events[#events+1]={kind="shot",weapon="machine",slot=2,x=1000,y=420,projectile={id=i,weapon="machine",slot=2,x=602,y=275,tx=1000,ty=398,duration=1,born=0}} end
 M.events(events);local n=0;for _ in pairs(M.shots) do n=n+1 end
 for _,e in ipairs(events) do e.at=20 end;M.events(events)
 return n==80 and #M.queue==192 and M.dropped>0''')

def test_old_run_events_ignored():
 l,t,p=motion_fixture()
 assert l.execute('M.sync(G.snapshot(S,C0,R));M.events({{kind="shot",weapon="machine",runId=S.runId-1,x=1000,y=420}});return M.weapons.slots[2].shotAt==-100')
