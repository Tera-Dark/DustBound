-- Pure server-authoritative simulation; clocks advance ONLY while unpaused.
local Core={}
local function metric(s,name,value)
 s.metrics=s.metrics or {};if #s.metrics<64 then s.metrics[#s.metrics+1]={name=name,value=value or 1,mode=s.mode or "standard",wave=s.wave or 0} end
end
Core.metric=metric
local function emit(s,kind,data) if #s.events<96 then data=data or {};data.kind=kind;s.events[#s.events+1]=data end end
local function notice(s,t) s.notice=t;s.noticeLeft=5 end
function Core.new(C,R,profile)
 profile=profile or R.cleanProfile(nil)
 return {phase="menu",stage="combat",profile=profile,loadout=profile.loadout,mode="standard",runId=0,metrics={},timing={combat=0,clearing=0,mining=0,supply=0,pause=0},events={},offerId=0,serial=0,
 elapsed=0,wave=0,rerolls=0,hull=C.InitialHull,maxHull=C.InitialHull,ore=0,totalMined=0,kills=0,enemies={},projectiles={},robots={},upgrades={},effects={},bonus={},allocation="balanced",paused=false}
end
function Core.stats(s,C)
 local u,b=s.upgrades,s.bonus or {}
 local robots=C.Robots+(b.robots or 0)+(s.extraRobots or 0)
 local cycle=C.RobotCycle/(1+(b.robotSpeed or 0))
 local cargo=C.RobotCargo*(1+(u.drill or 0)*.3)*(1+(b.mining or 0))
 local fire=(1+(u.rate or 0)*.18)*(1+(b.fire or 0))
 if s.allocation=="mining" then cargo=cargo*1.4;fire=fire*.8 elseif s.allocation=="defense" then cargo=cargo*.8;fire=fire*1.25 end
 if (s.effects.drill or 0)>0 then cargo=cargo*1.6 end
 if (s.effects.ammo or 0)>0 then fire=fire*1.45 end
 return {mine=robots*cargo/cycle,cargo=cargo,cycle=cycle,robots=robots,fire=fire,
 damage=24*(1+(u.damage or 0)*.3)*(1+(b.damage or 0))*((s.effects.overclock or 0)>0 and 1.35 or 1),shots=1+(u.barrel or 0),regen=(u.regen or 0)*2+(b.regen or 0)}
end
function Core.start(s,C,R,mode)
 if s.phase=="running" or s.phase=="decision" then return false end
 if mode~=nil and mode~="tutorial" and mode~="standard" then return false end
 s.mode=mode or "standard";s.runId=s.profile.runSerial+1;s.profile.runSerial=s.runId
 s.timing={combat=0,clearing=0,mining=0,supply=0,pause=0};s.waveDamage={};s.waveTaken=0;s.waveKills=0;s.waveReport=nil;s.firstDeposit=false
 s.bonus=R.bonuses(s.profile,C);local b=s.bonus
 s.phase="running";s.stage="combat";s.elapsed=0;s.combatTime=0;s.wave=1;s.waveElapsed=0;s.breakLeft=0
 s.ore=C.InitialOre+(b.startOre or 0);s.totalMined=0;s.kills=0;s.runCrystals=0;s.runCores=0
 s.maxHull=C.InitialHull+(b.hull or 0);s.hull=s.maxHull;s.enemies={};s.projectiles={};s.robots={};s.upgrades={};s.effects={shield=(b.startShield or 0)*(1+(b.shieldTime or 0))};s.events={};s.result=nil
 s.paused=false;s.supply=nil;s.offerId=s.offerId+1;s.spawnClock=0;s.gunClock=0;s.secondaryClock=0;s.shotSerial=0;s.projectileSerial=0
 s.eliteWave=0;s.overtime=false;s.serial=0;s.rerolls=0;s.purchases=0;s.extraRobots=0;s.revived=false;s.allocation="balanced"
 if not R.unlocked(s.profile,C.Catalog.weapons[s.loadout]) then s.loadout="machine" end
 metric(s,"run_start");if s.profile.runs>0 then metric(s,"next_run_start") end
 notice(s,s.mode=="tutorial" and "教学 1/4 · 点击火炮伤害：花 110 矿料，观察每发 24 → 31。" or "自动防御已启动。清空虫群后进入完整 30 秒机器人整备。")
 return true
end
local function finish(s,C,R,won)
 if s.phase~="running" and s.phase~="decision" then return false end
 if s.runId<=s.profile.settledSerial then return false end
 local a,d=R.settlement(won,s.ore,s.totalMined,s.kills,s.upgrades.refinery or 0,s.overtime,s.bonus)
 local crystals=math.floor(s.runCrystals*(1+(s.bonus.crystals or 0)))
 local cores=s.runCores+(won and s.overtime and (s.bonus.coreBonus or 0) or 0)
 local firstClear=s.mode=="tutorial" and won and not s.profile.tutorialCompleted
 -- Tutorial is a fixed first-clear grant, not an efficient ore-farming mode.
 if s.mode=="tutorial" then a=0;d=0;crystals=0;cores=0 end
 local bonusA,bonusD=0,0
 if firstClear then
  bonusA=C.TutorialReward.alloy;bonusD=C.TutorialReward.research;a=a+bonusA;d=d+bonusD
  s.profile.tutorialCompleted=true;s.profile.targetResearch=not s.profile.tech.energy_2 and "energy_2" or not s.profile.tech.ballistics_1 and "ballistics_1" or not s.profile.tech.industry_1 and "industry_1" or "";metric(s,"tutorial_complete")
 end
 s.profile.settledSerial=s.runId
 s.profile.alloy=s.profile.alloy+a;s.profile.research=s.profile.research+d;s.profile.crystals=s.profile.crystals+crystals;s.profile.cores=s.profile.cores+cores
 s.profile.runs=s.profile.runs+1;if won then s.profile.wins=s.profile.wins+1 end
 s.result={won=won,mode=s.mode,runId=s.runId,firstClear=firstClear,bonusAlloy=bonusA,bonusResearch=bonusD,timing=s.timing,alloy=a,research=d,crystals=crystals,cores=cores,kills=s.kills,mined=math.floor(s.totalMined),seconds=math.floor(s.elapsed),overtime=s.overtime,purchases=s.purchases}
 s.phase="ended";s.supply=nil;s.enemies={};s.projectiles={};s.robots={};s.paused=false;metric(s,"run_end",s.elapsed);emit(s,"end",{won=won});return true
end
local function options(s,C,R,rerolled)
 local pool={"repair","drill","ammo","ore","shield"}
 for _,id in ipairs({"drones","overclock"}) do if R.unlocked(s.profile,C.Catalog.supplies[id]) then pool[#pool+1]=id end end
 local opts={};local offset=(s.wave-1+(rerolled or 0)*3)%#pool
 for i=1,3 do opts[i]=pool[(offset+i-1)%#pool+1] end
 return opts
end
local function makeRobots(s,C)
 s.robots={};local stats=Core.stats(s,C)
 for i=1,stats.robots do s.robots[i]={id=i,t=0,delay=(i-1)*.32,cargo=0,trips=0,x=385,y=456+(i%2)*18,state="outbound",progress=0} end
end
local function beginMining(s,C,R)
 local best,amount="cannon",0;for id,v in pairs(s.waveDamage) do if v>amount then best=id;amount=v end end
 s.waveReport={wave=s.wave,kills=s.waveKills,taken=math.floor(s.waveTaken),best=best,damage=math.floor(amount)}
 metric(s,"wave_clear",s.waveElapsed)
 s.stage="mining";s.breakLeft=C.MiningDuration;s.extraRobots=0;s.projectiles={};makeRobots(s,C)
 s.offerId=s.offerId+1;s.supply={token=s.offerId,options=options(s,C,R,0)}
 emit(s,"supply",{});notice(s,"整备补给 · 选择后开始 30 秒采矿。机器人运回时才入账。")
end
local function nextCombat(s,C)
 s.waveDamage={};s.waveTaken=0;s.waveKills=0
 s.stage="combat";s.waveElapsed=0;s.spawnClock=0;s.extraRobots=0;s.robots={};s.gunClock=0;s.secondaryClock=0
 notice(s,"第 "..s.wave.." 波开战 · 机器人已回库")
end
local function deposit(s,r)
 if r.cargo<=0 then return end
 if not s.firstDeposit then s.firstDeposit=true;metric(s,"first_robot_deposit",s.elapsed) end
 s.ore=s.ore+r.cargo;s.totalMined=s.totalMined+r.cargo
 emit(s,"deposit",{x=390,y=r.y,ore=math.floor(r.cargo),id=r.id});r.cargo=0;r.trips=r.trips+1
end
local function endMining(s,C,R)
 -- Full 30-second breaks only. Last in-transit cargo requires the final industry technology.
 for _,r in ipairs(s.robots) do if s.bonus.autoUnload then deposit(s,r) end end
 if s.mode~="tutorial" then s.profile.bestWave=math.max(s.profile.bestWave,s.wave) end
 s.robots={};s.extraRobots=0
 if s.mode=="tutorial" and s.wave>=C.TutorialWaves then finish(s,C,R,true);return end
 if s.wave==10 and not s.overtime then s.phase="decision";return end
 if s.wave>=12 then finish(s,C,R,true);return end
 s.wave=s.wave+1;nextCombat(s,C)
end
function Core.rerollCost(s)
 local free=1+(s.bonus.freeRerolls or 0)
 return s.rerolls<free and 0 or math.floor(80*(1-(s.bonus.rerollDiscount or 0)))
end
function Core.act(s,C,R,action,data)
 if type(action)~="string" then return false end
 if action=="start" then return Core.start(s,C,R,data) end
 if action=="settings" and type(data)=="table" then
  local key,v=data.key,data.value
  if (key=="reducedMotion" or key=="damageNumbers") and type(v)=="boolean" then s.profile.settings[key]=v;return true end
  if (key=="sfx" or key=="music") and R.finite(v) then s.profile.settings[key]=R.clamp(v,0,1);return true end
  return false
 end
 if action=="target" and type(data)=="string" and (data=="" or C.Tech.nodes[data]) then s.profile.targetResearch=data;metric(s,"research_target");return true end
 if action=="preset" and (s.phase=="menu" or s.phase=="ended") and type(data)=="table" and (data.slot==1 or data.slot==2) then
  if data.mode=="save" then s.profile.presets[data.slot]=s.loadout;return true end
  local id=s.profile.presets[data.slot]
  if data.mode=="equip" and R.unlocked(s.profile,C.Catalog.weapons[id]) then s.loadout=id;s.profile.loadout=id;return true end
  return false
 end
 if action=="menu" and s.phase=="ended" then s.phase="menu";s.noticeLeft=0;return true end
 if action=="abandon" and (s.phase=="running" or s.phase=="decision") and data=="confirm" then
  metric(s,"abandon",s.elapsed)
  s.phase="menu";s.enemies={};s.projectiles={};s.robots={};s.supply=nil;s.paused=false;s.events={};s.result=nil
  notice(s,"已放弃远征：不结算本局矿料、研究或稀有资源；已发现图鉴保留。");return true
 end
 if action=="research" and (s.phase=="menu" or s.phase=="ended") and type(data)=="string" then local ok,msg=R.research(s.profile,data,C);if ok then metric(s,"research_complete");if s.profile.targetResearch==data then s.profile.targetResearch="" end end;notice(s,msg);return ok end
 if action=="loadout" and (s.phase=="menu" or s.phase=="ended") and type(data)=="string" and data~="cannon" and R.unlocked(s.profile,C.Catalog.weapons[data]) then s.loadout=data;s.profile.loadout=data;return true end
 if action=="pause" and (s.phase=="running" or s.phase=="decision") and type(data)=="boolean" then if s.paused~=data then metric(s,data and "pause" or "resume") end;s.paused=data;return true end
 if action=="decision" and s.phase=="decision" and not s.paused then
  if data=="leave" then return finish(s,C,R,true) end
  if data=="continue" and not s.overtime then s.overtime=true;s.phase="running";s.wave=11;nextCombat(s,C);return true end
 end
 if s.phase~="running" or s.paused then return false end
 if action=="allocate" and (data=="balanced" or data=="mining" or data=="defense") then s.allocation=data;notice(s,data=="mining" and "采矿优先：机器人每趟产量 +40%，武器射速 −20%" or data=="defense" and "防御优先：武器射速 +25%，机器人每趟产量 −20%" or "均衡分配：标准产量与射速");return true end
 if action=="buy" and type(data)=="string" then
  if s.mode=="tutorial" and data=="refinery" then notice(s,"教学不进行精炼结算；标准远征可使用");return false end
  local level=s.upgrades[data] or 0;local price=R.price(data,level,C)
  if not price then notice(s,"升级已满级或不存在");return false end
  if data=="repair" and s.hull>=s.maxHull then notice(s,"耐久已满");return false end
  if s.ore<price then notice(s,"矿料不足：击杀回收，或整备时等待机器人运回");return false end
  s.ore=s.ore-price;s.upgrades[data]=level+1;s.purchases=s.purchases+1;if s.purchases==1 then metric(s,"first_purchase",s.elapsed) end
  if data=="armor" then s.maxHull=s.maxHull+120;s.hull=math.min(s.maxHull,s.hull+120) end
  if data=="repair" then s.hull=math.min(s.maxHull,s.hull+180*(1+(s.bonus.repair or 0))) end
  emit(s,"upgrade",{id=data});notice(s,C.Upgrades[data].name.."已升级");return true
 end
 if action=="supply" and s.supply and type(data)=="table" and data.token==s.supply.token then
  local valid=false;for _,id in ipairs(s.supply.options) do if data.id==id then valid=true end end;if not valid then return false end
  local id=data.id
  if id=="repair" then s.hull=math.min(s.maxHull,s.hull+240*(1+(s.bonus.repair or 0)))
  elseif id=="ore" then s.ore=s.ore+180
  elseif id=="drones" then s.extraRobots=1;makeRobots(s,C)
  else s.effects[id]=(id=="drill" and 30 or 35)*(1+(id=="shield" and (s.bonus.shieldTime or 0) or (s.bonus.buffTime or 0))) end
  metric(s,"supply_accept");R.record(s.profile,"supplies",id);notice(s,"已接收："..C.Catalog.supplies[id].name);s.supply=nil;emit(s,"accepted",{});return true
 end
 if action=="reroll" and s.supply and type(data)=="number" and data==s.supply.token then
  if s.rerolls>=2+(s.bonus.freeRerolls or 0) then notice(s,"本局重抽已用完");return false end
  local cost=Core.rerollCost(s);if s.ore<cost then notice(s,"矿料不足");return false end
  s.ore=s.ore-cost;s.rerolls=s.rerolls+1;s.offerId=s.offerId+1;s.supply={token=s.offerId,options=options(s,C,R,s.rerolls)};return true
 end
 return false
end
local function damage(s,C,R,e,amount,pierce,weapon)
 if e.dead then return end
 local d=C.Catalog.enemies[e.kind];amount=amount*(pierce and 1 or (1-(d.armor or 0)))
 weapon=weapon or "cannon";s.waveDamage[weapon]=(s.waveDamage[weapon] or 0)+math.min(e.hp,amount)
 e.hp=e.hp-amount;e.hitAt=s.elapsed;emit(s,"hit",{id=e.id,x=e.x,y=e.y,amount=math.floor(amount)})
 if e.hp<=0 then
  e.dead=true;s.kills=s.kills+1;s.waveKills=s.waveKills+1;R.record(s.profile,"enemies",e.kind)
  local reward=d.reward*(1+(s.upgrades.salvage or 0)*.25+(s.bonus.salvage or 0));s.ore=s.ore+reward
  s.runCrystals=s.runCrystals+(d.crystals or 0);if e.kind=="elite" and s.wave>=10 then s.runCores=s.runCores+1 end
  emit(s,"kill",{id=e.id,x=e.x,y=e.y,ore=math.floor(reward)})
 end
end
local function hurtBase(s,amount)
 local mult=1-(s.bonus.mitigation or 0)
 if (s.effects.shield or 0)>0 then mult=mult*(.5-(s.bonus.shieldReduction or 0)) end
 s.waveTaken=s.waveTaken+amount*mult
 s.hull=s.hull-amount*mult;emit(s,"basehit",{amount=math.floor(amount*mult)})
 if s.hull<=0 and s.bonus.revive and not s.revived then s.revived=true;s.hull=s.maxHull*.15;notice(s,"紧急重启已触发 · 本局仅一次");emit(s,"revive",{}) end
end
local function spawn(s,C)
 if #s.enemies>=C.EnemyCap then return end
 s.serial=s.serial+1;local n=s.serial;local kind="crawler"
 if s.wave>=2 and n%4==0 then kind="runner" end
 if s.wave>=3 and n%5==0 then kind="tank" end
 if s.wave>=4 and n%7==0 then kind="spitter" end
 if s.wave>=8 and n%9==0 then kind="warden" end
 if (s.wave==5 or s.wave==10 or s.wave==12) and s.eliteWave~=s.wave then kind="elite";s.eliteWave=s.wave end
 local d=C.Catalog.enemies[kind];local hp=d.hp+s.wave*d.hpWave
 -- Spawn inside the safe canvas edge; clients animate an emergence, never a hard-cropped half sprite.
 s.enemies[#s.enemies+1]={id=n,kind=kind,hp=hp,maxHp=hp,x=1335+(n%2)*12,y=390+(n%4)*23,attack=0,speed=d.speed+s.wave*.4,spawnAt=s.elapsed,attackAt=-100,hitAt=-100,burn=0}
end
local function projectile(s,C,R,weapon,target,amount,index)
 local d=C.Catalog.weapons[weapon];s.projectileSerial=s.projectileSerial+1
 local x,y=weapon=="cannon" and 558 or 602,weapon=="cannon" and 145 or 275
 local dx,dy=target.x-x,target.y-22-y
 local travel=math.max(.08,math.sqrt(dx*dx+dy*dy)/(d.flight*(1+(s.bonus.projectileSpeed or 0))))
 local p={id=s.projectileSerial,weapon=weapon,target=target.id,x=x,y=y,tx=target.x,ty=target.y-22,age=0,duration=travel,damage=amount,index=index or 1}
 s.projectiles[#s.projectiles+1]=p;emit(s,"shot",{weapon=weapon,x=target.x,y=target.y,index=index or 1});R.record(s.profile,"weapons",weapon)
end
local function impact(s,C,R,p)
 if p.weapon=="acid" then hurtBase(s,p.damage);emit(s,"impact",{x=585,y=300,weapon="acid"});return end
 local victim=nil;for _,e in ipairs(s.enemies) do if e.id==p.target and not e.dead then victim=e;break end end
 local x,y=victim and victim.x or p.tx,victim and victim.y or p.ty+22
 emit(s,"impact",{x=x,y=y-22,weapon=p.weapon})
 if p.weapon=="rail" then
  local count=0;for _,e in ipairs(s.enemies) do if not e.dead and math.abs(e.y-y)<85 and e.x>=x-30 then damage(s,C,R,e,p.damage,true,p.weapon);count=count+1;if count>=3 then break end end end
 else
  if victim then damage(s,C,R,victim,p.damage,false,p.weapon) end
  local radius=p.weapon=="mortar" and 145 or p.weapon=="cannon" and 65*(1+(s.bonus.splash or 0)) or 0
  if radius>0 then for _,e in ipairs(s.enemies) do if e~=victim and not e.dead and math.abs(e.x-x)<radius and math.abs(e.y-y)<100 then damage(s,C,R,e,p.damage*(p.weapon=="mortar" and .7 or .25),false,p.weapon) end end end
 end
end
local function harvest(s,C,R,dt)
 s.breakLeft=math.max(0,s.breakLeft-dt);local stats=Core.stats(s,C)
 for _,r in ipairs(s.robots) do
  if r.delay>0 then r.delay=math.max(0,r.delay-dt) else
   local old=r.t;r.t=r.t+dt/stats.cycle
   if old<.72 and r.t>=.72 then r.cargo=stats.cargo end
   if r.t>=1-1e-9 then deposit(s,r);r.t=math.max(0,r.t-1) end
  end
  local t=r.t;local mineX=755+(r.id-1)*112
  if t<.28 then r.state="outbound";r.progress=t/.28;r.x=385+(mineX-385)*r.progress
  elseif t<.72 then r.state="drilling";r.progress=(t-.28)/.44;r.x=mineX
  else r.state="returning";r.progress=(t-.72)/.28;r.x=mineX+(385-mineX)*r.progress end
 end
 if s.breakLeft<.00001 then endMining(s,C,R) end
end
function Core.step(s,C,R,dt)
 if s.phase~="running" or not R.finite(dt) or dt<=0 then return end
 dt=math.min(dt,.25)
 local timer=s.paused and "pause" or s.supply and "supply" or s.stage
 s.timing[timer]=(s.timing[timer] or 0)+dt
 if s.paused or s.supply then return end
 s.elapsed=s.elapsed+dt;s.noticeLeft=math.max(0,(s.noticeLeft or 0)-dt)
 for id,value in pairs(s.effects) do if (s.stage=="mining")==(id=="drill") then s.effects[id]=math.max(0,value-dt) end end
 local stats=Core.stats(s,C);s.hull=math.min(s.maxHull,s.hull+stats.regen*dt)
 if s.stage=="mining" then harvest(s,C,R,dt);return end
 s.combatTime=s.combatTime+dt;s.waveElapsed=s.waveElapsed+dt
 if s.waveElapsed>=C.WaveDuration then s.stage="clearing" end
 local interval=math.max(.7,2.7-s.wave*.16);s.spawnClock=s.spawnClock+dt
 if s.stage=="combat" and s.spawnClock>=interval then s.spawnClock=s.spawnClock-interval;spawn(s,C) end
 for _,e in ipairs(s.enemies) do if not e.dead then
  local d=C.Catalog.enemies[e.kind];e.x=math.max(d.range,e.x-e.speed*dt);e.attack=e.attack-dt
  if e.burn>0 then e.burn=math.max(0,e.burn-dt);damage(s,C,R,e,(e.burnDamage or 1)*dt,false,"flame") end
  if not e.dead and e.x<=d.range and e.attack<=0 then
   local atk=d.attack+s.wave*d.attackWave;e.attack=d.interval;e.attackAt=s.elapsed
   if e.kind=="spitter" then
    s.projectileSerial=s.projectileSerial+1;s.projectiles[#s.projectiles+1]={id=s.projectileSerial,weapon="acid",x=e.x,y=e.y-25,tx=585,ty=300,age=0,duration=.85,damage=atk}
   else hurtBase(s,atk) end
  end
 end end
 table.sort(s.enemies,function(a,b) return a.x<b.x end)
 -- Homing visual targets are updated on the server; damage is deferred until travel finishes.
 for i=#s.projectiles,1,-1 do local p=s.projectiles[i];p.age=p.age+dt
  for _,e in ipairs(s.enemies) do if e.id==p.target and not e.dead then p.tx=e.x;p.ty=e.y-22;break end end
  if p.age>=p.duration then impact(s,C,R,p);table.remove(s.projectiles,i) end
 end
 s.gunClock=s.gunClock-dt*stats.fire;s.secondaryClock=s.secondaryClock-dt*stats.fire
 local target=nil;for _,e in ipairs(s.enemies) do if not e.dead and e.x<=558+C.Catalog.weapons.cannon.range then target=e;break end end
 if target and s.gunClock<=0 then
  s.gunClock=C.Catalog.weapons.cannon.interval
  for i=1,stats.shots do s.shotSerial=s.shotSerial+1;local boost=s.bonus.fifthShot and s.shotSerial%5==0 and 1.75 or 1;projectile(s,C,R,"cannon",target,stats.damage*boost,i) end
 end
 local w=C.Catalog.weapons[s.loadout];local secondary=nil
 for _,e in ipairs(s.enemies) do if not e.dead and e.x<=602+w.range then
  if not secondary or (s.loadout=="mortar" and e.hp>secondary.hp) then secondary=e end
 end end
 if secondary and s.secondaryClock<=0 then
  s.secondaryClock=w.interval;local amt=stats.damage*w.multiplier*(1+(s.bonus.auxDamage or 0))
  if s.loadout=="arc" or s.loadout=="flame" then
   R.record(s.profile,"weapons",s.loadout);local n=0
   for _,e in ipairs(s.enemies) do if not e.dead and e.x<=602+w.range then
    n=n+1;emit(s,"shot",{weapon=s.loadout,x=e.x,y=e.y});damage(s,C,R,e,amt,false,s.loadout)
    if s.loadout=="flame" then e.burn=3;e.burnDamage=amt*.35 end
    if s.loadout=="arc" and n>=3+(s.bonus.arcTargets or 0) then break end
   end end
  else projectile(s,C,R,s.loadout,secondary,amt,1) end
 end
 for i=#s.enemies,1,-1 do if s.enemies[i].dead then table.remove(s.enemies,i) end end
 if s.hull<=0 then s.hull=0;finish(s,C,R,false);return end
 -- A stalled combat wave cannot run forever; mining time never triggers this safety pressure.
 if s.waveElapsed>100 then hurtBase(s,dt*15);notice(s,"虫巢增压：尽快清空剩余虫群！") end
 if s.stage=="clearing" and #s.enemies==0 and #s.projectiles==0 then beginMining(s,C,R) end
end
function Core.snapshot(s,C,R)
 local enemies={};for _,e in ipairs(s.enemies) do enemies[#enemies+1]={id=e.id,kind=e.kind,x=e.x,y=e.y,hp=e.hp,maxHp=e.maxHp,speed=e.speed,spawnAt=e.spawnAt,attackAt=e.attackAt,hitAt=e.hitAt,burn=e.burn} end
 local shots={};for _,p in ipairs(s.projectiles) do shots[#shots+1]={id=p.id,weapon=p.weapon,x=p.x,y=p.y,tx=p.tx,ty=p.ty,age=p.age,duration=p.duration,index=p.index} end
 local robots={};for _,r in ipairs(s.robots) do robots[#robots+1]={id=r.id,x=r.x,y=r.y,t=r.t,state=r.state,progress=r.progress,cargo=r.cargo,trips=r.trips,delay=r.delay} end
 local u={};for id in pairs(C.Upgrades) do u[id]=s.upgrades[id] or 0 end
 local effects={};for id,v in pairs(s.effects) do effects[id]=v end
 return {phase=s.phase,stage=s.stage,profile=R.cleanProfile(s.profile),loadout=s.loadout,mode=s.mode,runId=s.runId,waveReport=s.waveReport,timing=s.timing,firstDeposit=s.firstDeposit,purchases=s.purchases or 0,elapsed=s.elapsed,wave=s.wave,waveElapsed=s.waveElapsed or 0,breakLeft=s.breakLeft or 0,
 hull=math.max(0,s.hull),maxHull=s.maxHull,ore=math.floor(s.ore),totalMined=math.floor(s.totalMined),kills=s.kills,runCrystals=s.runCrystals or 0,runCores=s.runCores or 0,
 dataPreview=s.mode=="tutorial" and (s.profile.tutorialCompleted and 0 or C.TutorialReward.research) or select(2,R.settlement(true,s.ore,s.totalMined,s.kills,u.refinery,s.overtime,s.bonus)),upgrades=u,stats=Core.stats(s,C),
 enemies=enemies,projectiles=shots,robots=robots,supply=s.supply,paused=s.paused,result=s.result,effects=effects,allocation=s.allocation,
 notice=(s.noticeLeft or 0)>0 and s.notice or "",rerolls=s.rerolls or 0,rerollCost=Core.rerollCost(s),rerollMax=2+(s.bonus.freeRerolls or 0),overtime=s.overtime}
end
return Core
