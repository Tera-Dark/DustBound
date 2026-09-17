local C=require('../src/Config')
C.Tech=require('../src/Tech');C.Catalog=require('../src/Catalog')
local R=require('../src/Rules');local G=require('../src/Core')
local checks=0
local function check(v,message) checks=checks+1;assert(v,message) end
math.randomseed(400)
for i=1,1000 do
 local ore=math.random(0,100000)
 local alloy,data=R.settlement(i%2==0,ore,math.random(0,10000),math.random(0,1000),i%4,false)
 check(alloy>=0 and alloy<=ore and data>=0 and data%1==0,'settlement bounds')
 local p=R.cleanProfile({alloy=-10,armor=2,tech={fake_1=true,fort_8='true'},codex={enemies={crawler=0/0}}})
 check(p.schema==6 and p.tech.fort_2 and not p.tech.fort_8 and p.alloy==0 and (p.codex.enemies.crawler or 0)==0,'nested migration')
 local s=G.new(C,R,p);G.start(s,C,R)
 G.step(s,C,R,.1);check(s.ore==C.InitialOre and s.totalMined==0,'no combat mining')
 local ok=G.act(s,C,R,'buy',i%2==0 and 'drill' or 'damage')
 check(ok and s.ore>=0 and s.ore<C.InitialOre,'purchase consumes ore')
 G.act(s,C,R,'pause',true);local before=s.elapsed;G.step(s,C,R,.1)
 check(s.elapsed==before,'explicit pause freezes clocks')
 G.act(s,C,R,'pause',false);s.waveElapsed=C.WaveDuration;s.enemies={};s.projectiles={};G.step(s,C,R,.1)
 check(s.stage=='mining' and s.breakLeft==30 and s.supply~=nil,'clear enters full break')
 G.act(s,C,R,'supply',{token=s.supply.token,id=s.supply.options[1]})
 for _=1,300 do G.step(s,C,R,.1);s.events={} end
 check(s.wave==2 and s.stage=='combat' and s.totalMined>0,'robots and cadence')
 G.act(s,C,R,'abandon','confirm');check(s.phase=='menu' and s.profile.alloy==0 and s.profile.runs==0,'no abandon farming')
end
print('PASS: '..checks..' native Luau property assertions')
