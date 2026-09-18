from pathlib import Path
p=Path('src/Core.lua');s=p.read_text().replace('-- 0.7 authoritative radial battle and robot-funded run economy. No client-side rewards.', '-- 0.9 authored encounter groups, early drafts, explicit mining recall. Server authoritative.')
s=s.replace('s.wave=1;s.elapsed=0;s.waveElapsed=0','s.wave=1;s.elapsed=0;s.waveElapsed=0;s.targetMode="nearest";s.plan=C.Encounters.plan(id,1);s.planWave=1;s.groupIndex=1;s.groupMember=0')
s=s.replace('{kills=0,taken=0,damage=0,weapons={}}','{kills=0,taken=0,damage=0,weapons={},takenBy={}}')
s=s.replace('s.notice="新手提示：先用主炮防守；清场后机器人采金。武器和遗物按波次免费选择。"','s.notice="第一波清场即可选副武器。收队后已采货物会运回；可以提前迎敌，但会少采矿。"')
pos=s.index('local function finish(s,C,R,won)')
s=s[:pos]+'''local function recap(s,C)
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
'''+s[pos:]
s=s.replace('purchases=s.purchases,timing=s.timing,ledger=s.ledger,reports=s.reports,loadout="cannon"}', 'purchases=s.purchases,timing=s.timing,ledger=s.ledger,reports=s.reports,loadout="cannon",recap=recap(s,C)}')
pos=s.index(' if action=="abandon"')
s=s[:pos]+''' if action=="target_mode" and s.phase=="running" and not s.paused and not s.supply and (data=="nearest" or data=="air" or data=="armor") then s.targetMode=data;return true end
 if action=="recall" and s.phase=="running" and s.stage=="mining" and type(data)=="table" then
  local ok,events=C.RunSystems.recall(s.run,data.token)
  if ok then
   for _,e in ipairs(events) do if not s.firstDeposit then s.firstDeposit=true;metric(s,"first_robot_deposit",s.elapsed) end;emit(s,"deposit",{id=e.robot,x=720,y=435,ore=e.gold}) end
   sync(s,C);emit(s,"recall");metric(s,"early_recall")
  end
  return ok
 end
'''+s[pos:]
s=s.replace('local function hurt(s,amount)', 'local function hurt(s,amount,kind)').replace('s.waveStats.taken=s.waveStats.taken+applied','s.waveStats.taken=s.waveStats.taken+applied\n s.waveStats.takenBy=s.waveStats.takenBy or {};kind=kind or "overtime";s.waveStats.takenBy[kind]=(s.waveStats.takenBy[kind] or 0)+applied')
s=s.replace('emit(s,"basehit",{amount=amount})','emit(s,"basehit",{amount=applied,enemyKind=kind})')
a=s.index('local function spawn(s,C)');b=s.index(' local d=C.Catalog.enemies[kind]',a)
s=s[:a]+'''local function spawn(s,C,group,member)
 if #s.enemies>=C.EnemyCap then return false end
 s.serial=s.serial+1;local n=s.serial;local kind=group.kind
 local side=group.side~=0 and group.side or (member%2==0 and -1 or 1)
 local x,y
 if kind=="flyer" then x=480+(n*103)%480;y=-60-(member%2)*12
 else x=side<0 and -30-(member%3)*12 or 1470+(member%3)*12;y=366+(member%3)*18 end
'''+s[b:]
s=s.replace('burn=0,vx=0,vy=0}\nend\nlocal function projectile', 'burn=0,vx=0,vy=0}\n return true\nend\nlocal function projectile')
a=s.index(' for _,e in ipairs(s.enemies) do if not e.dead and dist(mount,e)<d.range then');b=s.index('\n if not target then return false end',a)
s=s[:a]+''' local bestScore=-math.huge
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
 end end'''+s[b:]
s=s.replace('s.waveStats={kills=0,taken=0,damage=0,weapons={},takenBy={}} end', 's.waveStats={kills=0,taken=0,damage=0,weapons={},takenBy={}};s.plan=C.Encounters.plan(s.campaignNode,s.wave);s.planWave=s.wave;s.groupIndex=1;s.groupMember=0 end')
a=s.index(' local interval=math.max(.85,2.65-s.wave*.09)');b=s.index('\n for _,e in ipairs(s.enemies) do if not e.dead then',a)
s=s[:a]+''' if s.planWave~=s.wave then s.plan=C.Encounters.plan(s.campaignNode,s.wave);s.planWave=s.wave;s.groupIndex=1;s.groupMember=0 end
 local budget=8
 while s.groupIndex<=#s.plan.groups and budget>0 do
  local group=s.plan.groups[s.groupIndex]
  if s.waveElapsed<group.at or #s.enemies>=C.EnemyCap then break end
  if not spawn(s,C,group,s.groupMember+1) then break end
  s.groupMember=s.groupMember+1;budget=budget-1
  if s.groupMember>=group.count then s.groupIndex=s.groupIndex+1;s.groupMember=0 end
 end
 if s.waveElapsed>=s.plan.duration and s.groupIndex>#s.plan.groups then s.stage="clearing" end'''+s[b:]
s=s.replace('hurt(s,(d.attack+s.wave*d.attackWave)*s.mission.attack)', 'hurt(s,(d.attack+s.wave*d.attackWave)*s.mission.attack,e.kind)')
s=s.replace('damage=s.waveStats.damage}', 'damage=s.waveStats.damage,weapons=s.waveStats.weapons,takenBy=s.waveStats.takenBy}')
# authoritative, read-only upgrade comparisons; UI never computes prices separately
pos=s.index('function G.snapshot(s,C,R)')
s=s[:pos]+'''function G.investments(s,C,R)
 local out={};local stats=G.stats(s,C);local prices=G.prices(s,C,R)
 local function n(v) return string.format("%.2f",v):gsub("0+$", ""):gsub("%.$", "") end
 for _,id in ipairs(C.ActiveUpgradeIds) do
  local level=s.upgrades[id] or 0;local price=prices[id];local before,after,unit,detail
  if id=="move" then before=stats.move;after=before+33;unit="像素/秒"
  elseif id=="dig" then before=2.64/stats.dig;after=2.64/(stats.dig+.16);unit="秒/次（越低越快）"
  elseif id=="cargo" then before=stats.cargo;after=math.floor(28*(1+(level+1)*.2+(s.bonus.robotCargo or 0)));unit="金矿/趟"
  elseif id=="robots" then before=stats.robots;after=math.min(6,before+1);unit="台工蜂"
  elseif id=="damage" then before=stats.damage;after=before*(1+(level+1)*.3)/(1+level*.3);unit="主炮伤害/发"
  elseif id=="rate" then before=1.1/stats.fire;after=before*(1+level*.18)/(1+(level+1)*.18);unit="主炮间隔（秒）"
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
'''+s[pos:]
s=s.replace('prices=G.prices(s,C,R),relics=', '''prices=G.prices(s,C,R),investments=G.investments(s,C,R),targetMode=s.targetMode or "nearest",
  encounter=s.phase=="running" and C.Encounters.intel(s.campaignNode,s.wave) or nil,
  nextEncounter=s.phase=="running" and s.wave<s.mission.waves and C.Encounters.intel(s.campaignNode,s.wave+1) or nil,
  prepare=s.run and s.stage=="mining" and C.RunSystems.forecast(s.run) or nil,relics=''')
# Prevent upgrading robots mid-recall (otherwise a newly spawned bot can reopen a finished preparation).
s=s.replace(' if s.supply and action=="buy" then return false end',' if (s.supply or s.run.recalling) and action=="buy" then return false end')
p.write_text(s)
