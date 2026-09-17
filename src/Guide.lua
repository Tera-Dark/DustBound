-- Read-only planning UI. Estimates never grant currency or drive purchases.
local G={}
function G.intel(wave,C)
 local names={C.Catalog.enemies.crawler.name}
 if wave>=3 then names[#names+1]=C.Catalog.enemies.flyer.name end
 if wave>=4 then names[#names+1]=C.Catalog.enemies.tank.name end
 return {wave=wave,title="四向来袭",enemies=table.concat(names," / "),tip="主炮固定，副武器独立攻击；清场后采金。",elite=false}
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
 local ids=s.hull<s.maxHull*.55 and {"repair","armor","damage"} or s.wave<=3 and {"cargo","dig","damage","rate"} or {"damage","rate","barrel","regen","armor"}
 local goal=nil
 for _,id in ipairs(ids) do
  local info=G.investment(id,s,C,R)
  if info.price then local v={id=id,reason="使用机器人运回的金矿投资；不是必买项目。",info=info};goal=goal or v;if info.can then return v end end
 end
 return goal or {id="damage",reason="保留金矿用于后续维修或付费重抽。",info=G.investment("damage",s,C,R)}
end
function G.forecast(s)
 local pending,eta,total=0,nil,0
 if s.stage~="mining" then return {cargo=0,eta=0,expected=0} end
 for _,r in ipairs(s.robots) do
  local distance=320+(r.id-1)*45;local travel=distance/s.stats.move;local dig=2.64/s.stats.dig;local cycle=travel*2+dig
  local first=(r.delay or 0)+(r.state=="outbound" and (1-r.progress)*travel+dig+travel or r.state=="drilling" and (1-r.progress)*dig+travel or (1-r.progress)*travel)
  pending=pending+r.cargo
  if first<=s.breakLeft then eta=math.min(eta or first,first);total=total+(r.cargo>0 and r.cargo or s.stats.cargo)+math.floor((s.breakLeft-first)/cycle)*s.stats.cargo end
 end
 return {cargo=math.floor(pending),eta=eta and math.ceil(eta) or 0,expected=math.floor(total)}
end
function G.target(p,C,R)
 local n=C.Tech.nodes[p.targetResearch];if not n then return {title="未固定研究目标",detail="在研究中心选择节点后可追踪。",id=""} end
 if p.tech[n.id] then return {title=n.name,detail="已经完成，选择下一个目标。",id=n.id} end
 local lines={};local _,gate=R.techState(p,n.id,C)
 for _,v in ipairs({{"alloy","合金","远征结算"},{"research","数据","远征结算"},{"cores","核心","每个星球第 8 关首通；可重置终极天赋退还"}}) do
  local need=math.max(0,n.cost[v[1]]-p[v[1]])
  if need>0 then lines[#lines+1]=v[2].."缺 "..need.." · "..v[3] end
 end
 return {title=n.name,id=n.id,detail=#lines>0 and table.concat(lines,"\n") or gate}
end
function G.lesson(s)
 if s.mode~="tutorial" then return "" end
 if s.profile.tutorialCompleted then return "教学练习：不发材料。可比较不同投资与补给。" end
 if (s.purchases or 0)==0 then return "教学 1/4 · 推荐投资火炮伤害；也可自主选择其他强化。" end
 if not s.firstDeposit then
  if s.supply then return "教学 2/4 · 点选补给，再接收。选择期间不会扣整备时间。" end
  if s.stage=="mining" then return "教学 3/4 · 机器人自动钻探；返航入库后，矿料才增加。" end
  return "教学 2/4 · 自动战斗中不采矿。清空虫群后才有 30 秒整备。"
 end
 return "教学 4/4 · 守住三波后领取首通材料，研究电弧蓝图并换装。"
end
-- Contextual supply descriptions: preview only, no rewards granted here.
function G.supply(id,s,C,R)
 local d=C.Catalog.supplies[id];local b=R.bonuses(s.profile,C)
 local last=s.mission and s.mission.waves or s.mode=="tutorial" and C.TutorialWaves or s.overtime and 12 or 10
 local final=s.wave>=last;local value=0;local tip=d.desc;local detail=d.detail
 if id=="repair" then
  value=math.min(s.maxHull-s.hull,240*(1+(b.repair or 0)))
  detail="实际修复 "..math.floor(value).." 耐久"
  tip=value==0 and "当前耐久已满，这份补给不会带来收益。" or "立即生效；不会超过耐久上限。"
 elseif id=="ore" then value=180;tip="立即到账，可投资或留作标准远征合金结算。"
 elseif id=="drill" then value=final and 100 or 90;detail="产量 +60% · "..math.floor(30*(1+(b.buffTime or 0))).." 秒整备时间"
 elseif id=="drones" then value=95
 elseif id=="shield" then value=s.hull<s.maxHull*.55 and 150 or 55
  detail="减伤 "..math.floor((.5+(b.shieldReduction or 0))*100).."% · "..math.floor(35*(1+(b.shieldTime or 0))).." 秒战斗时间"
 else value=id=="ammo" and 85 or 80 end
 if id=="ammo" or id=="overclock" then detail=(id=="ammo" and "射速 +45%" or "武器伤害 +35%").." · "..math.floor(35*(1+(b.buffTime or 0))).." 秒战斗时间" end
 if (s.effects[id] or 0)>0 then tip=tip.." 再次领取会刷新时长，不叠加倍率。" end
 if final and (id=="ammo" or id=="shield" or id=="overclock") then
  value=0;tip=s.wave==10 and s.mode~="tutorial" and "仅继续追加波次时有用；直接撤离不会用到。" or "已是最后一次整备，没有后续战斗，建议选择即时或采矿补给。"
 end
 return {detail=detail,tip=tip,score=value}
end
function G.supplyChoice(s,C,R)
 local best,score=nil,-1
 if not s.supply then return nil end
 for _,id in ipairs(s.supply.options) do local info=G.supply(id,s,C,R);if info.score>score then best=id;score=info.score end end
 return best
end
function G.buffs(s,C)
 local lines={}
 for _,id in ipairs({"drill","ammo","shield","overclock"}) do
  local left=s.effects[id] or 0
  if left>0 then
   local active=not s.paused and not s.supply and ((s.stage=="mining")== (id=="drill"))
   lines[#lines+1]=C.Catalog.supplies[id].name.." "..math.ceil(left).."s"..(active and "" or "·待机")
  end
 end
 return #lines>0 and table.concat(lines," / ") or "无临时增益 · 补给可强化下一阶段"
end
function G.debrief(s,C,R)
 local r=s.result;if not r then return "" end
 if r.campaignNode and r.won then return "节点奖励已入账；查看星球航图的下一关，或用新材料研究。重打仍有收益。" end
 if r.firstClear then return "已完成首次教学！先研究电弧蓝图，再换装进入标准远征。" end
 if r.mode=="tutorial" and r.won then return "教学练习不重复发材料；准备好后进入标准远征。" end
 if not r.won then
  if (s.upgrades.damage or 0)<2 then return "复盘：主炮伤害投入偏少。下次在前期采矿投资后，尽早补足输出。" end
  if s.allocation=="mining" then return "复盘：失守时仍为采矿优先，射速降低 20%。开战前考虑切回均衡或防御。" end
  return "复盘：提前为精英波准备维修或护盾；不要等耐久见底再处理。"
 end
 return "复盘：保留矿料会兑换合金；先确定研究目标，再决定是否继续追加波次。"
end
function G.settlement(s,C,R)
 local won=true;if s.phase=="ended" then won=s.result.won end
 if s.mission then return "节点结算：首通 180% / 重打 80% 基准奖励，另计永久研究加成。\n精炼提高研究数据；失败按推进进度保留部分材料；核心仅胜利获得。剩余矿料不直接兑换。" end
 if s.mode=="tutorial" then return "教学仅首次胜利领取固定材料；矿料不兑换合金。" end
 local b=R.bonuses(s.profile,C)
 local retention=won and 1 or .35+(b.lossRetention or 0)
 return "结余矿料 × "..math.floor(retention*100).."% 保留 × 合金研究倍率；取整后结算。\n研究数据来自采集、击杀、通关及精炼加成。"
end
return G
