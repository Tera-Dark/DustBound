-- 0.9 authored encounter groups, early drafts, explicit mining recall. Server authoritative.
local G={}
local function dist(a,b) local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y) end
local function emit(s,kind,e) if #s.events>=160 then return end;e=e or {};e.kind=kind;e.at=s.elapsed;e.runId=s.runId;s.events[#s.events+1]=e end
local function metric(s,name,value) s.metrics[#s.metrics+1]={name=name,value=value or 1} end
local center={x=720,y=340}
local function sync(s,C)
 if not s.run then return end
 s.ore=s.run.gold;s.totalMined=s.run.goldMined;s.robots=s.run.robots;s.bonus=s.run.bonus
 s.breakLeft=s.run.miningLeft;s.rerolls=s.run.rerolls;s.ledger.spent=s.run.spent
 for id,v in pairs(s.run.upgrades) do s.upgrades[id]=v end
 local offer=s.run.offer;s.supply=offer and {token=offer.token,kind=offer.kind,options=offer.choices} or nil
end
function G.new(C,R,profile)
 C.Economy.configure(C)
 return {phase="menu",stage="combat",profile=profile or R.cleanProfile(nil),runId=0,mode="campaign",wave=0,elapsed=0,waveElapsed=0,ore=0,totalMined=0,hull=900,maxHull=900,
  enemies={},projectiles={},robots={},events={},metrics={},upgrades={},bonus={},effects={},allocation="balanced",loadout="cannon",paused=false,rerolls=0,kills=0,purchases=0,
  timing={combat=0,clearing=0,mining=0,supply=0,pause=0},ledger={spent=0,salvaged=0,airdrop=0,lostCargo=0},reports={}}
end
function G.stats(s,C)
 local u=s.upgrades;local b=s.bonus
 local r=s.run and C.RunSystems.stats(s.run) or {robots=2,move=220,dig=1,cargo=28,fire=1,regen=0,mitigation=0}
 local fire=(1+(u.rate or 0)*.18)*r.fire
 local cargo=r.cargo
 local distance=0;for i=1,r.robots do distance=distance+320+math.floor((i-1)/2)*45 end
 local cycle=2*(distance/r.robots)/r.move+2.64/r.dig
 return {robots=r.robots,move=r.move,dig=r.dig,cargo=cargo,cycle=cycle,mine=r.robots*cargo/cycle,fire=fire,damage=24*(1+(u.damage or 0)*.3)*(1+(b.damage or 0)),shots=1+(u.barrel or 0),regen=(u.regen or 0)*2+r.regen,mitigation=r.mitigation}
end
function G.start(s,C,R,data)
 if s.phase=="running" then return false end
 local id=1;if type(data)=="table" then id=data.node end
 if data~=nil and type(data)~="table" and data~="tutorial" and data~="standard" then return false end
 if not R.finite(id) or id%1~=0 or not C.Catalog.campaign[id] or id>s.profile.campaignCleared+1 then return false end
 s.profile.runSerial=s.profile.runSerial+1;s.runId=s.profile.runSerial
 s.run=C.RunSystems.new(s.runId*179+37,R.bonuses(s.profile,C),s.runId)
 s.run.world={baseX=720,mineX=1040,spacing=45,y=465,bilateral=true}
 s.phase="running";s.stage="combat";s.campaignNode=id;s.mission=C.Catalog.campaign[id];s.mode="campaign";s.wave=1;s.elapsed=0;s.waveElapsed=0;s.targetMode="nearest";s.plan=C.Encounters.plan(id,1);s.planWave=1;s.groupIndex=1;s.groupMember=0
 s.upgrades={};s.bonus=s.run.bonus;s.hull=900+(s.bonus.hull or 0);s.maxHull=s.hull;s.paused=false;s.supply=nil;s.effects={};s.result=nil
 s.enemies={};s.projectiles={};s.robots={};s.events={};s.metrics={};s.serial=0;s.projectileSerial=0;s.spawnClock=0;s.gunClock=0;s.shotSerial=0;s.kills=0;s.purchases=0;s.revived=false
 s.allocation="balanced";s.loadout="cannon";s.firstDeposit=false;s.notice="第一波清场即可选副武器。收队后已采货物会运回；可以提前迎敌，但会少采矿。"
 s.waveStats={kills=0,taken=0,damage=0,weapons={},takenBy={}};s.ledger={spent=0,salvaged=0,airdrop=0,lostCargo=0};s.reports={};s.timing={combat=0,clearing=0,mining=0,supply=0,pause=0}
 sync(s,C);metric(s,"run_start");return true
end
local function recap(s,C)
 local damage,threats={},{};local worstWave,worstTaken=0,0
 local function add(report)
  for k,v in pairs(report.weapons or {}) do damage[k]=(damage[k] or 0)+v end
  for k,v in pairs(report.takenBy or {}) do threats[k]=(threats[k] or 0)+v end
  if report.taken>worstTaken then worstWave=report.wave or s.wave;worstTaken=report.taken end
 end
 for _,report in ipairs(s.reports) do add(report) end
 if #s.reports<s.wave then add(s.waveStats) end
 local threat,amount=nil,0;for k,v in pairs(threats) do if v>amount then threat=k;amount=v end end
 local weapon,best="cannon",0;for k,v in pairs(damage) do if v>best then weapon=k;best=v end end
 local tips={runner="疾行虫造成最多承伤：试试机枪拦截或在突围波前提升射速。",flyer="空袭造成最多承伤：选择机枪，或将主炮切换为空中优先。",tank="重甲虫造成最多承伤：磁轨无视护甲，主炮可切为重甲优先。",crawler="地面虫群造成最多承伤：电弧连锁或范围火力能缓解近身压力。",overtime="清场时间过长：提升火力，避免低输出陷入消耗。"}
 return {topWeapon=weapon,weaponDamage=damage,threat=threat or "none",takenBy=threats,worstWave=worstWave,worstTaken=worstTaken,
  tip=tips[threat] or "本局没有承伤。可尝试提早收队，用更少矿量挑战下一波。"}
end
local function finish(s,C,R,won)
 if s.phase~="running" or s.profile.settledSerial>=s.runId then return end
 local first=won and s.campaignNode>s.profile.campaignCleared
 local reward=C.Economy.reward(s.mission,won,first,s.run.cleared,s.kills)
 local retention=not won and (1+(s.bonus.lossRetention or 0)) or 1
 reward.alloy=math.floor(reward.alloy*(1+(s.bonus.alloy or 0))*retention)
 reward.research=math.floor(reward.research*(1+(s.bonus.research or 0))*retention)
 for key,v in pairs(reward) do s.profile[key]=s.profile[key]+v end
 if first then s.profile.campaignCleared=s.campaignNode end
 s.profile.settledSerial=s.runId;s.profile.runs=s.profile.runs+1;if won then s.profile.wins=s.profile.wins+1 end
 s.result={won=won,mode="campaign",campaignNode=s.campaignNode,runId=s.runId,firstClear=first,alloy=reward.alloy,research=reward.research,cores=reward.cores,crystals=0,
  bonusAlloy=0,bonusResearch=0,kills=s.kills,mined=s.run.goldMined,seconds=math.floor(s.elapsed),wave=s.wave,hull=s.hull,maxHull=s.maxHull,purchases=s.purchases,timing=s.timing,ledger=s.ledger,reports=s.reports,loadout="cannon",recap=recap(s,C)}
 s.phase="ended";s.run.phase="ended";s.run.offer=nil;s.run.robots={};s.supply=nil;s.robots={};s.enemies={};s.projectiles={};s.paused=false
 metric(s,"run_end",s.elapsed);emit(s,"end",{won=won})
end
function G.rerollCost(s,C)
 if not s.run then return 0 end
 return C.RunSystems.rerollPrice(s.run)
end
function G.act(s,C,R,action,data)
 if action=="start" then return G.start(s,C,R,data) end
 if action=="settings" and type(data)=="table" then
  local def=R.SettingDefaults[data.key];local value=data.value
  if type(def)=="boolean" and type(value)=="boolean" then s.profile.settings[data.key]=value;return true end
  if type(def)=="number" and R.finite(value) then s.profile.settings[data.key]=R.clamp(value,0,1);return true end
  return false
 end
 if action=="settings_reset" and data=="confirm" then s.profile.settings=R.cleanSettings(nil);return true end
 if action=="target" and type(data)=="string" and (data=="" or C.Tech.nodes[data]) then s.profile.targetResearch=data;return true end
 if action=="research" and s.phase~="running" and type(data)=="string" then local ok,msg=R.research(s.profile,data,C);s.notice=msg;return ok end
 if action=="refund_talent" and s.phase~="running" and type(data)=="string" then
  local n=C.Tech.nodes[data]
  if not n or n.kind~="ultimate" or not s.profile.tech[data] then return false end
  s.profile.tech[data]=nil;for key,v in pairs(n.cost) do s.profile[key]=s.profile[key]+v end;s.notice="终极天赋已重置，费用全额退回";return true
 end
 if action=="menu" and s.phase=="ended" then s.phase="menu";return true end
 if action=="pause" and s.phase=="running" and type(data)=="boolean" then s.paused=data;s.run.paused=data;return true end
 if action=="target_mode" and s.phase=="running" and not s.paused and not s.supply and (data=="nearest" or data=="air" or data=="armor") then s.targetMode=data;return true end
 if action=="recall" and s.phase=="running" and s.stage=="mining" and type(data)=="table" then
  local ok,events=C.RunSystems.recall(s.run,data.token)
  if ok then
   for _,e in ipairs(events) do if not s.firstDeposit then s.firstDeposit=true;metric(s,"first_robot_deposit",s.elapsed) end;emit(s,"deposit",{id=e.robot,x=720,y=435,ore=e.gold}) end
   sync(s,C);emit(s,"recall");metric(s,"early_recall")
  end
  return ok
 end
 if action=="abandon" and s.phase=="running" and data=="confirm" then s.phase="menu";s.run.phase="ended";s.run.offer=nil;s.run.robots={};s.run.paused=false;s.supply=nil;s.enemies={};s.projectiles={};s.robots={};s.paused=false;return true end
 if s.phase~="running" or s.paused then return false end
 if (s.supply or s.run.recalling) and action=="buy" then return false end
 if action=="allocate" then return false end -- No hidden mining/fire tradeoff in the simplified economy.
 if action=="buy" and type(data)=="string" then
  local ok=false
  if C.RunSystems.upgrades[data] then ok=C.RunSystems.buy(s.run,data)
  elseif data=="damage" or data=="rate" or data=="barrel" or data=="armor" or data=="repair" or data=="regen" then
   local price=R.price(data,s.upgrades[data] or 0,C)
   if not price or s.run.gold<price or data=="repair" and s.hull>=s.maxHull then return false end
   s.run.gold=s.run.gold-price;s.run.spent=s.run.spent+price;s.upgrades[data]=(s.upgrades[data] or 0)+1;ok=true
   if data=="armor" then s.maxHull=s.maxHull+120;s.hull=math.min(s.maxHull,s.hull+120) end
   if data=="repair" then s.hull=math.min(s.maxHull,s.hull+180*(1+(s.bonus.repair or 0))) end
  end
  if ok then s.purchases=s.purchases+1;s.ledger.spent=s.run.spent;emit(s,"upgrade",{id=data});sync(s,C) end
  return ok
 end
 if action=="supply" and type(data)=="table" then local ok=C.RunSystems.choose(s.run,data.token,data.id);sync(s,C);if ok then emit(s,"accepted");metric(s,"supply_accept") end;return ok end
 if action=="reroll" then local ok=C.RunSystems.reroll(s.run,data);sync(s,C);return ok end
 return false
end
local function hurt(s,amount,kind)
 local applied=math.min(s.hull,amount*(1-math.min(.65,s.bonus.mitigation or 0)))
 s.hull=math.max(0,s.hull-applied);s.waveStats.taken=s.waveStats.taken+applied
 s.waveStats.takenBy=s.waveStats.takenBy or {};kind=kind or "overtime";s.waveStats.takenBy[kind]=(s.waveStats.takenBy[kind] or 0)+applied
 if s.hull<=0 and (s.bonus.revive or 0)>0 and not s.revived then s.revived=true;s.hull=s.maxHull*.15 end
 emit(s,"basehit",{amount=applied,enemyKind=kind})
end
local function hit(s,C,R,e,amount,pierce,weapon)
 if e.dead then return end
 local def=C.Catalog.enemies[e.kind]
 local applied=math.min(e.hp,amount*(pierce and 1 or 1-(def.armor or 0)))
 e.hp=e.hp-applied;e.hitAt=s.elapsed
 s.waveStats.damage=s.waveStats.damage+applied;s.waveStats.weapons[weapon]=(s.waveStats.weapons[weapon] or 0)+applied
 emit(s,"hit",{x=e.x,y=e.y,amount=math.floor(amount)})
 if e.hp<=0 then e.dead=true;s.kills=s.kills+1;s.waveStats.kills=s.waveStats.kills+1;R.record(s.profile,"enemies",e.kind);emit(s,"kill",{id=e.id,x=e.x,y=e.y,ore=0}) end
end
local function spawn(s,C,group,member)
 if #s.enemies>=C.EnemyCap then return false end
 s.serial=s.serial+1;local n=s.serial;local kind=group.kind
 local side=group.side~=0 and group.side or (member%2==0 and -1 or 1)
 local x,y
 if kind=="flyer" then x=480+(n*103)%480;y=-60-(member%2)*12
 else x=side<0 and -30-(member%3)*12 or 1470+(member%3)*12;y=366+(member%3)*18 end
 local d=C.Catalog.enemies[kind];local hp=(d.hp+s.wave*d.hpWave)*s.mission.hp
 if s.mission.boss and s.wave==s.mission.waves and n%9==0 then hp=hp*1.4 end
 s.enemies[#s.enemies+1]={id=n,kind=kind,x=x,y=y,hp=hp,maxHp=hp,speed=d.speed+s.wave*.3,attack=0,spawnAt=s.elapsed,attackAt=-100,hitAt=-100,burn=0,vx=0,vy=0}
 return true
end
local function projectile(s,C,id,slot,target,amount)
 local mount=C.WeaponMounts[slot];local d=C.Catalog.weapons[id];s.projectileSerial=s.projectileSerial+1
 local p={id=s.projectileSerial,weapon=id,slot=slot,x=mount.x,y=mount.y,tx=target.x,ty=target.y,born=s.elapsed,age=0,duration=math.max(.1,dist(mount,target)/((d.flight or 1100)*(1+(s.bonus.projectileSpeed or 0)))),damage=amount,target=target.id}
 s.projectiles[#s.projectiles+1]=p;emit(s,"shot",{weapon=id,slot=slot,x=target.x,y=target.y,projectile={id=p.id,weapon=id,slot=slot,x=p.x,y=p.y,tx=p.tx,ty=p.ty,born=p.born,duration=p.duration}})
end
local function fire(s,C,R,id,slot,stats)
 local d=C.Catalog.weapons[id];local target=nil;local mount=C.WeaponMounts[slot]
 local bestScore=-math.huge
 for _,e in ipairs(s.enemies) do if not e.dead and dist(mount,e)<d.range then
  local score=-dist(e,center)
  if id=="cannon" then
   if s.targetMode=="air" and e.kind=="flyer" then score=score+10000 end
   if s.targetMode=="armor" and (C.Catalog.enemies[e.kind].armor or 0)>0 then score=score+10000 end
  elseif id=="machine" then
   if e.kind=="flyer" or e.kind=="runner" then score=score+10000 end
  elseif id=="rail" then score=score+(C.Catalog.enemies[e.kind].armor or 0)*10000
  elseif id=="mortar" then score=e.hp
  elseif id=="arc" then
   for _,other in ipairs(s.enemies) do if not other.dead and dist(e,other)<220 then score=score+1000 end end
  end
  if score>bestScore then target=e;bestScore=score end
 end end
 if not target then return false end
 local amount=24*(1+(s.upgrades.damage or 0)*.3)*C.RunSystems.weaponMultiplier(s.run,id)*d.multiplier*(slot>1 and 1+(s.bonus.auxDamage or 0) or 1)
 if id=="arc" then
  local used={};local last=target
  for _=1,3+(s.bonus.arcTargets or 0) do
   if not last then break end;used[last.id]=true;hit(s,C,R,last,amount,false,id);emit(s,"shot",{weapon=id,slot=slot,x=last.x,y=last.y})
   local nextTarget=nil;for _,e in ipairs(s.enemies) do if not e.dead and not used[e.id] and dist(last,e)<220 then nextTarget=e;break end end;last=nextTarget
  end
 elseif id=="flame" then
  local dx,dy=target.x-mount.x,target.y-mount.y;local norm=math.sqrt(dx*dx+dy*dy)
  emit(s,"shot",{weapon=id,slot=slot,x=target.x,y=target.y})
  for _,e in ipairs(s.enemies) do local range=dist(mount,e)
   if not e.dead and range<d.range and ((e.x-mount.x)*dx+(e.y-mount.y)*dy)/math.max(1,range*norm)>.7 then hit(s,C,R,e,amount,false,id);e.burn=3;e.burnDamage=amount*.25 end
  end
 else
  local shots=id=="cannon" and stats.shots or 1
  for _=1,shots do s.shotSerial=s.shotSerial+1;projectile(s,C,id,slot,target,amount*((s.bonus.fifthShot or 0)>0 and id=="cannon" and s.shotSerial%5==0 and 1.75 or 1)) end
 end
 R.record(s.profile,"weapons",id);return true
end
function G.step(s,C,R,dt)
 if s.phase~="running" or not R.finite(dt) or dt<=0 then return end;dt=math.min(dt,.25)
 local timer=s.paused and "pause" or s.supply and "supply" or s.stage;s.timing[timer]=(s.timing[timer] or 0)+dt
 if s.paused or s.supply then return end
 if s.hull<=0 then finish(s,C,R,false);return end
 s.elapsed=s.elapsed+dt
 if s.stage=="mining" then
  local events=C.RunSystems.tickMining(s.run,dt)
  for _,e in ipairs(events) do if not s.firstDeposit then s.firstDeposit=true;metric(s,"first_robot_deposit",s.elapsed) end;emit(s,"deposit",{id=e.robot,x=720,y=435,ore=e.gold}) end
  sync(s,C)
  if s.run.phase=="combat" then s.wave=s.wave+1;s.stage="combat";s.waveElapsed=0;s.spawnClock=0;s.gunClock=0;s.waveStats={kills=0,taken=0,damage=0,weapons={},takenBy={}};s.plan=C.Encounters.plan(s.campaignNode,s.wave);s.planWave=s.wave;s.groupIndex=1;s.groupMember=0 end
  return
 end
 local stats=G.stats(s,C);s.hull=math.min(s.maxHull,s.hull+stats.regen*dt)
 s.waveElapsed=s.waveElapsed+dt;s.spawnClock=s.spawnClock+dt
 if s.planWave~=s.wave then s.plan=C.Encounters.plan(s.campaignNode,s.wave);s.planWave=s.wave;s.groupIndex=1;s.groupMember=0 end
 local budget=8
 while s.groupIndex<=#s.plan.groups and budget>0 do
  local group=s.plan.groups[s.groupIndex]
  if s.waveElapsed<group.at or #s.enemies>=C.EnemyCap then break end
  if not spawn(s,C,group,s.groupMember+1) then break end
  s.groupMember=s.groupMember+1;budget=budget-1
  if s.groupMember>=group.count then s.groupIndex=s.groupIndex+1;s.groupMember=0 end
 end
 if s.waveElapsed>=s.plan.duration and s.groupIndex>#s.plan.groups then s.stage="clearing" end
 for _,e in ipairs(s.enemies) do if not e.dead then
  local d=C.Catalog.enemies[e.kind];local flying=e.kind=="flyer"
  local goal=flying and {x=720,y=210} or {x=720,y=e.y}
  local range=flying and 72 or 128;local distance=dist(e,goal)
  local step=math.min(math.max(0,distance-range),e.speed*dt);e.vx=(goal.x-e.x)/math.max(1,distance)*e.speed;e.vy=(goal.y-e.y)/math.max(1,distance)*e.speed
  if distance<=range then e.vx=0;e.vy=0 end
  e.x=e.x+(goal.x-e.x)/math.max(1,distance)*step;e.y=e.y+(goal.y-e.y)/math.max(1,distance)*step;e.attack=e.attack-dt
  if e.burn>0 then e.burn=math.max(0,e.burn-dt);hit(s,C,R,e,e.burnDamage*dt,false,"flame") end
  if not e.dead and dist(e,goal)<=range+.1 and e.attack<=0 then e.attack=d.interval;e.attackAt=s.elapsed;emit(s,"enemyattack",{id=e.id,enemyKind=e.kind,x=e.x,y=e.y,tx=720,ty=340});hurt(s,(d.attack+s.wave*d.attackWave)*s.mission.attack,e.kind) end
 end end
 for i=#s.projectiles,1,-1 do local p=s.projectiles[i];p.age=p.age+dt
  local target=nil;for _,e in ipairs(s.enemies) do if not e.dead and e.id==p.target then target=e;break end end
  if target then p.tx=target.x;p.ty=target.y end
  if p.age>=p.duration then
   local point={x=p.tx,y=p.ty}
   if p.weapon=="rail" then
    local dx,dy=p.tx-p.x,p.ty-p.y;local length=math.max(1,math.sqrt(dx*dx+dy*dy));local count=0
    local candidates={}
    for _,e in ipairs(s.enemies) do if not e.dead then local ex,ey=e.x-p.x,e.y-p.y;local along=(ex*dx+ey*dy)/length
     if along>=0 and along<=C.Catalog.weapons.rail.range and math.abs(ex*dy-ey*dx)/length<38 then candidates[#candidates+1]={enemy=e,along=along} end
    end end
    table.sort(candidates,function(a,b) return a.along<b.along end)
    for _,candidate in ipairs(candidates) do hit(s,C,R,candidate.enemy,p.damage,true,p.weapon);count=count+1;if count>=3 then break end end
   else
    if target then hit(s,C,R,target,p.damage,false,p.weapon) end
    local radius=p.weapon=="mortar" and 150 or p.weapon=="cannon" and 65*(1+(s.bonus.splash or 0)) or 0
    if radius>0 then for _,e in ipairs(s.enemies) do if e~=target and not e.dead and dist(point,e)<radius then hit(s,C,R,e,p.damage*(p.weapon=="mortar" and .7 or .25),false,p.weapon) end end end
   end
   emit(s,"impact",{x=p.tx,y=p.ty,weapon=p.weapon,projectileId=p.id});table.remove(s.projectiles,i)
  end
 end
 s.gunClock=s.gunClock-dt*stats.fire
 if s.gunClock<=0 and fire(s,C,R,"cannon",1,stats) then s.gunClock=1.1 end
 for _,w in ipairs(s.run.weapons) do w.cooldown=w.cooldown-dt*stats.fire
  if w.cooldown<=0 and fire(s,C,R,w.weapon,w.slot,stats) then w.cooldown=C.Catalog.weapons[w.weapon].interval end
 end
 for i=#s.enemies,1,-1 do if s.enemies[i].dead then table.remove(s.enemies,i) end end
 if s.waveElapsed>100 then hurt(s,dt*10) end
 if s.hull<=0 then finish(s,C,R,false);return end
 if s.stage=="clearing" and #s.enemies==0 and #s.projectiles==0 then
  s.profile.bestWave=math.max(s.profile.bestWave,s.wave);C.RunSystems.waveCleared(s.run,s.wave,s.mission.waves)
  local best,bestDamage="cannon",0;for id,amount in pairs(s.waveStats.weapons) do if amount>bestDamage then best=id;bestDamage=amount end end
  metric(s,"wave_clear",s.waveElapsed);s.reports[#s.reports+1]={wave=s.wave,kills=s.waveStats.kills,taken=s.waveStats.taken,best=best,damage=s.waveStats.damage,weapons=s.waveStats.weapons,takenBy=s.waveStats.takenBy}
  if s.run.phase=="ended" then finish(s,C,R,true) else s.stage="mining";sync(s,C);if s.supply then emit(s,"supply") end end
 end
end
-- One authoritative price contract, including permanent robot-count caps.
function G.prices(s,C,R)
 local prices={}
 for _,id in ipairs(C.ActiveUpgradeIds) do
  local price
  if C.RunSystems.upgrades[id] then if s.run then price=C.RunSystems.price(s.run,id) end
  else price=R.price(id,s.upgrades[id] or 0,C) end
  prices[id]=price or false
 end
 return prices
end
function G.investments(s,C,R)
 local out={};local stats=G.stats(s,C);local prices=G.prices(s,C,R)
 local function n(v) return string.format("%.2f",v):gsub("0+$", ""):gsub("%.$", "") end
 for _,id in ipairs(C.ActiveUpgradeIds) do
  local level=s.upgrades[id] or 0;local price=prices[id];local before,after,unit,detail
  if id=="move" then before=stats.move;after=before+33;unit="像素/秒"
  elseif id=="dig" then before=2.64/stats.dig;after=2.64/(stats.dig+.16);unit="秒/次（越低越快）"
  elseif id=="cargo" then before=stats.cargo;after=math.floor(28*(1+(level+1)*.2+(s.bonus.robotCargo or 0)));unit="金矿/趟"
  elseif id=="robots" then before=stats.robots;after=math.min(6,before+1);unit="台工蜂"
  elseif id=="damage" then before=s.run and 24*(1+level*.3)*C.RunSystems.weaponMultiplier(s.run,"cannon") or stats.damage;after=before*(1+(level+1)*.3)/(1+level*.3);unit="主炮伤害/发"
  elseif id=="rate" then before=C.Catalog.weapons.cannon.interval/stats.fire;after=before*(1+level*.18)/(1+(level+1)*.18);unit="主炮间隔（秒）"
  elseif id=="barrel" then before=stats.shots;after=before+1;unit="枚/轮"
  elseif id=="armor" then before=s.maxHull;after=before+120;unit="耐久上限；同时修复 120"
  elseif id=="repair" then before=s.hull;after=math.min(s.maxHull,before+180*(1+(s.bonus.repair or 0)));unit="耐久（实际恢复 "..n(after-before).."）"
  elseif id=="regen" then before=stats.regen;after=before+2;unit="耐久/秒" end
  local reason=not price and "已达上限" or id=="repair" and s.hull>=s.maxHull and "耐久已满" or s.phase~="running" and "远征中可用" or s.paused and "已暂停" or s.supply and "请先完成免费选择" or s.run and s.run.recalling and "工蜂回收中" or s.ore<price and "金矿不足" or ""
  if before then detail=n(before).." → "..n(after).." "..unit else detail="本次远征生效" end
  out[id]={price=price,level=level,before=before,after=after,detail=detail,reason=reason,canBuy=reason==""}
 end
 return out
end
function G.snapshot(s,C,R)
 sync(s,C);local stats=G.stats(s,C);local u={};for _,id in ipairs(C.ActiveUpgradeIds) do u[id]=s.upgrades[id] or 0 end
 local robots={};for _,r in ipairs(s.robots) do robots[#robots+1]={id=r.id,x=r.x,y=r.y or 435,state=r.state,progress=r.progress,cargo=r.cargo,trips=r.trips,delay=r.delay or 0,mineX=r.mineX,baseX=r.baseX,t=r.state=="outbound" and r.progress*.28 or r.state=="drilling" and .28+r.progress*.44 or .72+r.progress*.28} end
 local slots=s.run and C.RunSystems.slotSnapshot(s.run) or {{slot=1,enabled=true,weapon="cannon"},{slot=2,enabled=false},{slot=3,enabled=false},{slot=4,enabled=false},{slot=5,enabled=false}}
 return {phase=s.phase,stage=s.stage,profile=R.cleanProfile(s.profile),loadout="cannon",weaponSlots=slots,mode="campaign",runId=s.runId,campaignNode=s.campaignNode,mission=s.mission,
  wave=s.wave,waveElapsed=s.waveElapsed,elapsed=s.elapsed,breakLeft=s.breakLeft or 0,ore=math.floor(s.ore),totalMined=s.totalMined,hull=s.hull,maxHull=s.maxHull,
  enemies=s.enemies,projectiles=s.projectiles,robots=robots,upgrades=u,stats=stats,paused=s.paused,supply=s.supply,rerolls=s.rerolls,rerollMax=s.run and C.RunSystems.rerollLimit(s.run) or 3,rerollCost=G.rerollCost(s,C),
  prices=G.prices(s,C,R),investments=G.investments(s,C,R),targetMode=s.targetMode or "nearest",
  encounter=s.phase=="running" and C.Encounters.intel(s.campaignNode,s.wave) or nil,
  nextEncounter=s.phase=="running" and s.wave<s.mission.waves and C.Encounters.intel(s.campaignNode,s.wave+1) or nil,
  prepare=s.run and s.stage=="mining" and C.RunSystems.forecast(s.run) or nil,relics=s.run and s.run.relics or {},effects={},allocation="balanced",notice=s.notice or "",result=s.result,kills=s.kills,purchases=s.purchases,runCrystals=0,runCores=0,dataPreview=0,
  ledger=s.ledger,reports=s.reports,timing=s.timing,firstDeposit=s.firstDeposit,overtime=false}
end
return G
