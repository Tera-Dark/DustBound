-- Read-only planning UI. Estimates never grant currency or drive purchases.
local G={}
function G.intel(wave,C)
 local names={"穴居虫"};local tip="均衡投资，观察主炮与回收收入。"
 if wave>=2 then names[#names+1]="疾行虫";tip="疾行虫较快：提高射速，或预留维修矿料。" end
 if wave>=3 then names[#names+1]="甲壳虫";tip="出现重甲：提高主炮伤害；局前可考虑穿透配装。" end
 if wave>=4 then names[#names+1]="酸液虫";tip="远程酸液会先攻击：保持输出，必要时准备护盾。" end
 if wave>=8 then names[#names+1]="矿巢守卫";tip="多种重甲同时进场：输出、维修与护盾要兼顾。" end
 local elite=wave==5 or wave==10 or wave==12
 if elite then tip="精英预警！维修与护盾能争取更多输出时间。";names[#names+1]="掘地巨兽" end
 return {wave=wave,title=elite and "精英波预警" or "下一波情报",enemies=table.concat(names," / "),tip=tip,elite=elite}
end
function G.investment(id,s,C,R)
 local d=C.Upgrades[id];local level=s.upgrades[id] or 0;local price=R.price(id,level,C);local b=R.bonuses(s.profile,C)
 local stats=s.stats;local detail=d.description
 if id=="damage" then detail=string.format("主炮 %.0f → %.0f / 发",stats.damage,stats.damage*(1+(level+1)*.3)/(1+level*.3))
 elseif id=="rate" then detail=string.format("主炮间隔 %.2f → %.2f 秒",1.1/stats.fire,1.1/(stats.fire*(1+(level+1)*.18)/(1+level*.18)))
 elseif id=="drill" then detail=string.format("每趟 %.0f → %.0f 矿料",stats.cargo,stats.cargo*(1+(level+1)*.3)/(1+level*.3))
 elseif id=="armor" then detail=string.format("耐久上限 %d → %d",s.maxHull,s.maxHull+120)
 elseif id=="repair" then detail="实际恢复 "..math.floor(math.min(s.maxHull-s.hull,180*(1+(b.repair or 0)))).." 耐久（不溢出）"
 elseif id=="regen" then detail=string.format("自动修复 %.1f → %.1f / 秒",stats.regen,stats.regen+2)
 elseif id=="barrel" then detail=stats.shots.." → "..(stats.shots+1).." 枚主炮 / 轮"
 elseif id=="salvage" then detail="击杀回收额外 +25% 基础收益"
 elseif id=="refinery" then detail="结算研究倍率 +20% 基础值" end
 local blocked=not price and "本局已满级" or s.mode=="tutorial" and id=="refinery" and "教学不进行精炼结算" or id=="repair" and s.hull>=s.maxHull and "耐久已满" or s.paused and "暂停时不可投资" or s.phase~="running" and "请在远征中投资" or nil
 local gap=price and math.max(0,price-s.ore) or 0
 return {id=id,name=d.name,detail=detail,price=price,level=level,cap=d.cap,can=not blocked and gap==0,reason=blocked or gap>0 and "还差 "..gap.." 矿料" or "可立即投资",gap=gap}
end
function G.recommend(s,C,R)
 local id,why="damage","提高每发伤害，减少虫群堆积。"
 if s.hull<s.maxHull*.55 then id="repair";why="耐久低于 55%，先稳住前哨。"
 elseif s.stage=="mining" and s.wave<=2 and (s.upgrades.drill or 0)<1 then id="drill";why="前期整备：提高后续每趟运回量。"
 elseif s.wave>=2 and (s.upgrades.rate or 0)<2 then id="rate";why="疾行虫开始增多，提高射速更容易补刀。" end
 if not R.price(id,s.upgrades[id] or 0,C) then id="barrel";why="主炮已强化，可考虑增加每轮炮弹。" end
 return {id=id,reason=why,info=G.investment(id,s,C,R)}
end
function G.forecast(s)
 local pending,eta,total=0,nil,0
 if s.stage~="mining" then return {cargo=0,eta=0,expected=0} end
 for _,r in ipairs(s.robots) do
  pending=pending+r.cargo
  local first=math.max(0,(1-r.t)*s.stats.cycle+math.max(0,r.delay or 0))
  if first<=s.breakLeft+1e-7 then
   if eta==nil then eta=first elseif first<eta then eta=first end
   local count=1+math.floor(math.max(0,s.breakLeft-first)/s.stats.cycle+1e-7)
   total=total+(r.cargo>0 and r.cargo or s.stats.cargo)+(count-1)*s.stats.cargo
  end
 end
 return {cargo=math.floor(pending),eta=eta and math.ceil(eta) or 0,expected=math.floor(total)}
end
function G.target(p,C,R)
 local n=C.Tech.nodes[p.targetResearch];if not n then return {title="未固定研究目标",detail="在研究中心选择节点后可追踪。",id=""} end
 if p.tech[n.id] then return {title=n.name,detail="已经完成，选择下一个目标。",id=n.id} end
 local lines={};local _,gate=R.techState(p,n.id,C)
 for _,v in ipairs({{"alloy","合金","远征结算"},{"research","数据","采矿与远征结算"},{"crystals","晶体","第 5 / 10 波精英"},{"cores","核心","第 10 / 12 波精英"}}) do
  local need=math.max(0,n.cost[v[1]]-p[v[1]])
  if need>0 then lines[#lines+1]=v[2].."缺 "..need.." · "..v[3] end
 end
 return {title=n.name,id=n.id,detail=#lines>0 and table.concat(lines,"\n") or gate}
end
function G.lesson(s)
 if s.mode~="tutorial" then return "" end
 if s.profile.tutorialCompleted then return "教学练习：不发材料。可比较不同投资与补给。" end
 if (s.purchases or 0)==0 then return "教学 1/4 · 投资火炮伤害，观察每发伤害的变化。" end
 if not s.firstDeposit then
  if s.supply then return "教学 2/4 · 点选补给，再接收。选择期间不会扣整备时间。" end
  if s.stage=="mining" then return "教学 3/4 · 机器人自动钻探；返航入库后，矿料才增加。" end
  return "教学 2/4 · 自动战斗中不采矿。清空虫群后才有 30 秒整备。"
 end
 return "教学 4/4 · 守住三波后领取首通材料，研究电弧蓝图并换装。"
end
return G
