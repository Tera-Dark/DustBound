-- 0.9 short, interruptible preparation; engine-independent, wired into the authoritative Core.
-- Only robot deposits generate earned in-run gold. The initial balance is startup capital.
local M={}
M.initialGold=120
M.maxRobots=6
M.weapons={"machine","arc","rail","flame","mortar"}
M.upgrades={
 move={name="移动速度",cost=90,growth=1.65,cap=6,step=.15},
 dig={name="挖矿速度",cost=100,growth=1.65,cap=6,step=.16},
 cargo={name="挖矿数量",cost=110,growth=1.7,cap=6,step=.2},
 robots={name="机器人数量",cost=280,growth=1.85,cap=4,step=1},
}
M.relicOrder={"battery","servo","diamondBit","cargoRack","swarm","reactor","plating","repairNet","ballisticLens","arcRelay","thermalCore","insurance"}
M.relics={
 battery={name="稳定电池",detail="整局武器射速 +10%",effects={fire=.1}},
 servo={name="伺服轴承",detail="整局机器人移动速度 +20%",effects={robotMove=.2}},
 diamondBit={name="金刚钻芯",detail="整局机器人挖矿速度 +20%",effects={robotDig=.2}},
 cargoRack={name="折叠货舱",detail="整局每次挖矿数量 +20%",effects={robotCargo=.2}},
 swarm={name="工蜂协议",detail="每台机器人使全体机器人挖矿速度 +4%",effects={digPerRobot=.04}},
 reactor={name="输出稳压器",detail="整局武器伤害 +12%",effects={damage=.12}},
 plating={name="复合装甲片",detail="整局受到伤害降低 8%",effects={mitigation=.08}},
 repairNet={name="修复纳米网",detail="整局每秒恢复 1 点耐久",effects={regen=1}},
 ballisticLens={name="弹道透镜",detail="主炮、机枪与磁轨枪伤害 +18%",effects={ballisticDamage=.18}},
 arcRelay={name="电弧中继",detail="电弧额外连锁一个目标",effects={arcTargets=1}},
 thermalCore={name="热能核心",detail="喷焰器与迫击炮伤害 +20%",effects={thermalDamage=.2}},
 insurance={name="矿运保险",detail="收队时在途金矿立即入库，省去返航等待",effects={autoUnload=1}},
}
M.waves={3,3,4,4,5,6,7,8,8,9,10,11,12,12,13,14,14,15,16,16,17,18,19,20}
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function nextRandom(s,n)
 s.seed=(s.seed*48271)%2147483647
 return s.seed%n+1
end
local function copy(raw)
 local out={};for key,value in pairs(raw or {}) do if finite(value) then out[key]=value end end;return out
end
function M.new(seed,permanent,runId)
 assert(finite(runId) and runId>=1 and runId%1==0,"authoritative runId required")
 local s={gold=M.initialGold,goldMined=0,spent=0,upgrades={move=0,dig=0,cargo=0,robots=0},weapons={},relics={},robots={},bonus=copy(permanent),
  runId=runId,seed=finite(seed) and math.floor(math.abs(seed))%2147483646+1 or 1,offerSerial=0,offer=nil,cleared=0,rerolls=0,phase="combat",paused=false,miningLeft=0}
 return s
end
function M.stats(s)
 local b=s.bonus;local u=s.upgrades
 local count=clamp(2+u.robots+(b.robots or 0),2,M.maxRobots)
 return {robots=count,
  move=220*(1+u.move*.15+(b.robotMove or 0)),
  dig=1+u.dig*.16+(b.robotDig or 0)+(b.digPerRobot or 0)*count,
  cargo=math.floor(28*(1+u.cargo*.2+(b.robotCargo or 0))),
  fire=1+(b.fire or 0),damage=1+(b.damage or 0),regen=b.regen or 0,
  mitigation=clamp(b.mitigation or 0,0,.65),arcTargets=3+(b.arcTargets or 0)}
end
function M.weaponMultiplier(s,id)
 local b=s.bonus;local multiplier=1+(b.damage or 0)+(b[id.."Damage"] or 0)
 if id=="cannon" or id=="machine" or id=="rail" then multiplier=multiplier+(b.ballisticDamage or 0) end
 if id=="flame" or id=="mortar" then multiplier=multiplier+(b.thermalDamage or 0) end
 return multiplier
end
function M.price(s,id)
 local d=M.upgrades[id];if not d then return nil end
 local level=s.upgrades[id]
 if level>=d.cap or id=="robots" and M.stats(s).robots>=M.maxRobots then return nil end
 return math.floor(d.cost*d.growth^level+.5)
end
local function newRobot(s,id)
 local w=s.world or {};local base=w.baseX or 385
 local side=w.bilateral and (id%2==0 and 1 or -1) or 1
 local offset=w.bilateral and math.floor((id-1)/2)*(w.spacing or 45) or (id-1)*(w.spacing or 84)
 local mine=base+side*(math.abs((w.mineX or 755)-base)+offset)
 return {id=id,x=base,baseX=base,y=(w.y or 456)+(id-3.5)*12,mineX=mine,state="outbound",progress=0,cargo=0,trips=0,delay=(id-1)*.25}
end
function M.buy(s,id)
 if s.paused or s.offer or s.recalling or (s.phase~="combat" and s.phase~="mining") then return false,"当前不可投资" end
 local price=M.price(s,id)
 if not price then return false,"项目不存在或已达上限" end
 if s.gold<price then return false,"金矿不足" end
 s.gold=s.gold-price;s.spent=s.spent+price;s.upgrades[id]=s.upgrades[id]+1
 if id=="robots" and s.phase=="mining" then
  for i=#s.robots+1,M.stats(s).robots do s.robots[i]=newRobot(s,i) end
 end
 return true
end
local function pool(s,kind)
 if kind=="weapon" then return {table.unpack(M.weapons)} end
 local out={};for _,id in ipairs(M.relicOrder) do if not s.relics[id] then out[#out+1]=id end end;return out
end
local function offer(s,kind)
 local choices=pool(s,kind);local selected={}
 if kind=="weapon" and s.cleared==1 then choices={"machine","arc","rail"} end
 for _=1,math.min(3,#choices) do selected[#selected+1]=table.remove(choices,nextRandom(s,#choices)) end
 if #selected==0 then s.offer=nil;return end
 s.offerSerial=s.offerSerial+1;s.offer={kind=kind,token=tostring(s.runId)..":"..s.offerSerial,choices=selected}
end
function M.miningDuration(wave) return wave<=2 and 18 or 14 end
function M.draftKind(wave,lastWave)
 if wave>=lastWave then return nil end
 if wave==1 or wave==4 or wave==8 or wave==12 then return "weapon" end
 if wave==2 or wave==5 or wave==9 or wave==13 or wave==17 then return "relic" end
 return nil
end
function M.waveCleared(s,wave,lastWave)
 if s.phase~="combat" or s.offer or not finite(wave) or wave%1~=0 or wave~=s.cleared+1 then return false end
 if not finite(lastWave) or lastWave%1~=0 or lastWave<wave or lastWave>20 then return false end
 s.cleared=wave
 -- Gold has no further in-run use at completion: no final mining wait or dead-end reward selection.
 if wave==lastWave then s.phase="ended";s.robots={};return true end
 s.phase="mining";s.miningLeft=M.miningDuration(wave);s.miningDuration=s.miningLeft;s.recalling=false;s.robots={};s.prepareToken=tostring(s.runId)..":mining:"..wave
 for i=1,M.stats(s).robots do s.robots[i]=newRobot(s,i) end
 local draft=M.draftKind(wave,lastWave)
 if draft=="weapon" and #s.weapons<4 then offer(s,"weapon") elseif draft=="relic" then offer(s,"relic") end
 return true
end
function M.choose(s,token,id)
 if s.paused or s.phase~="mining" or not s.offer or s.offer.token~=token then return false end
 local valid=false;for _,choice in ipairs(s.offer.choices) do if choice==id then valid=true;break end end
 if not valid then return false end
 if s.offer.kind=="weapon" then
  if #s.weapons>=4 then return false end
  -- A duplicate weapon occupies its own physical slot, not a free upgrade to every copy.
  s.weapons[#s.weapons+1]={weapon=id,slot=#s.weapons+2,cooldown=0}
 else
  if s.relics[id] then return false end
  s.relics[id]=true
  for key,value in pairs(M.relics[id].effects) do s.bonus[key]=(s.bonus[key] or 0)+value end
 end
 s.offer=nil;return true
end
function M.rerollLimit(s) return 3+math.min(2,s.bonus.freeRerolls or 0) end
function M.rerollPrice(s)
 local free=1+math.min(2,s.bonus.freeRerolls or 0)
 return s.rerolls<free and 0 or math.floor((80+40*(s.rerolls-free))*(1-clamp(s.bonus.rerollDiscount or 0,0,.75)))
end
function M.reroll(s,token)
 if s.paused or not s.offer or s.offer.token~=token or s.rerolls>=M.rerollLimit(s) then return false end
 local price=M.rerollPrice(s);if s.gold<price then return false end
 local kind=s.offer.kind;s.gold=s.gold-price;s.spent=s.spent+price;s.rerolls=s.rerolls+1;offer(s,kind);return true
end
local function deposit(s,r,events)
 if r.cargo<=0 then return end
 s.gold=s.gold+r.cargo;s.goldMined=s.goldMined+r.cargo
 events[#events+1]={kind="deposit",robot=r.id,gold=r.cargo}
 r.cargo=0;r.trips=r.trips+1
end
-- Snapshot-only prediction: constant current stats, no extra investments.
-- Counts completed digs, including cargo that will return after the timer expires.
function M.forecast(s)
 local stats=M.stats(s);local cargo,future,eta=0,0,0
 for _,r in ipairs(s.robots) do
  cargo=cargo+r.cargo
  local distance=math.abs(r.mineX-r.baseX);local travel=distance/stats.move;local dig=2.64/stats.dig
  eta=math.max(eta,math.abs(r.x-r.baseX)/stats.move)
  local first
  if r.state=="outbound" then first=(r.delay or 0)+math.abs(r.mineX-r.x)/stats.move+dig
  elseif r.state=="drilling" then first=(1-r.progress)*dig
  else first=math.abs(r.x-r.baseX)/stats.move+travel+dig end
  if not s.recalling and first<=(s.miningLeft or 0)+1e-8 then
   future=future+(1+math.floor(((s.miningLeft or 0)-first+1e-8)/(2*travel+dig)))*stats.cargo
  end
 end
 return {token=s.prepareToken,retainedCargo=cargo,futureOre=future,returnEta=(s.bonus.autoUnload or 0)>0 and 0 or eta,remaining=s.miningLeft or 0,duration=s.miningDuration or 0,recalling=s.recalling==true}
end
local function beginRecall(s,events)
 s.recalling=true;s.miningLeft=0
 for _,r in ipairs(s.robots) do r.state="returning";r.progress=0;r.delay=0 end
 if (s.bonus.autoUnload or 0)>0 then
  for _,r in ipairs(s.robots) do deposit(s,r,events) end
  s.robots={};s.phase="combat";s.recalling=false
 end
end
function M.recall(s,token)
 if s.phase~="mining" or s.offer or s.paused or s.recalling or token~=s.prepareToken then return false,{} end
 local events={};beginRecall(s,events);return true,events
end
local function tickRecall(s,dt,events)
 local allHome=true;local stats=M.stats(s)
 for _,r in ipairs(s.robots) do
  local dx=r.baseX-r.x;local step=math.min(math.abs(dx),stats.move*dt)
  r.x=r.x+(dx>=0 and step or -step)
  r.progress=1-math.abs(r.x-r.baseX)/math.max(1,math.abs(r.mineX-r.baseX))
  if math.abs(r.x-r.baseX)<1e-6 then r.x=r.baseX;deposit(s,r,events) else allHome=false end
 end
 if allHome then s.robots={};s.phase="combat";s.recalling=false end
end
function M.tickMining(s,dt)
 local events={}
 if s.phase~="mining" or s.paused or s.offer or not finite(dt) or dt<=0 then return events end
 dt=math.min(dt,.25)
 if s.recalling then tickRecall(s,dt,events);return events end
 dt=math.min(dt,s.miningLeft);local stats=M.stats(s)
 for _,r in ipairs(s.robots) do
  local delayed=math.min(dt,r.delay or 0);r.delay=math.max(0,(r.delay or 0)-delayed)
  local remaining=dt-delayed
  for _=1,4 do
   if remaining<=1e-9 then break end
   if r.state=="drilling" then
    local rate=stats.dig/2.64;local consumed=math.min(remaining,(1-r.progress)/rate)
    r.progress=math.min(1,r.progress+consumed*rate);remaining=remaining-consumed
    if r.progress>=1-1e-9 then r.cargo=stats.cargo;r.state="returning";r.progress=0 end
   else
    local target=r.state=="outbound" and r.mineX or r.baseX;local distance=math.abs(target-r.x)
    local consumed=math.min(remaining,distance/stats.move);local delta=consumed*stats.move
    r.x=r.x+(target>=r.x and delta or -delta);remaining=remaining-consumed
    r.progress=r.state=="outbound" and (r.x-r.baseX)/(r.mineX-r.baseX) or (r.mineX-r.x)/(r.mineX-r.baseX)
    if math.abs(r.x-target)<1e-6 then
     r.x=target;r.progress=0
     if r.state=="outbound" then r.state="drilling" else deposit(s,r,events);r.state="outbound" end
    end
   end
  end
 end
 s.miningLeft=math.max(0,s.miningLeft-dt)
 if s.miningLeft<1e-8 then
  beginRecall(s,events)
 end
 return events
end
function M.slotSnapshot(s)
 local out={{slot=1,enabled=true,weapon="cannon"}}
 for slot=2,5 do local w=s.weapons[slot-1];out[slot]={slot=slot,enabled=w~=nil,weapon=w and w.weapon or false} end
 return out
end
return M
