-- Data-driven 48-node technology graph. Every effect has a Core/Rules consumer.
local T={branches={},nodes={},order={}}
local branches={
 {id="fort",name="堡垒防御",icon="shield",items={
  {"复合底座","初始耐久 +90",{hull=90}}, {"加厚装甲","初始耐久再 +90",{hull=90}},
  {"斜面装甲","受到伤害 -5%",{mitigation=.05}}, {"自修复网格","每秒修复 0.7 耐久",{regen=.7}},
  {"强化支架","初始耐久 +120",{hull=120}}, {"医疗编组","维修效果 +25%",{repair=.25}},
  {"护盾稳压","护盾持续时间 +20%",{shieldTime=.2}}, {"紧急重启","每局一次：致命伤后恢复 15% 耐久",{revive=1}},
 }},
 {id="industry",name="机器人采矿",icon="drill",items={
  {"标准钻头","机器人货物产量 +10%",{mining=.1}}, {"矿料分拣","货物产量再 +10%",{mining=.1}},
  {"第三工蜂","永久增加 1 台采矿机器人",{robots=1}}, {"高速履带","机器人采矿循环加快 15%",{robotSpeed=.15}},
  {"货舱扩容","机器人货物产量 +20%",{mining=.2}}, {"第四工蜂","再增加 1 台采矿机器人",{robots=1}},
  {"高纯矿脉","货物产量 +10%",{mining=.1}}, {"远程卸载","整备结束时自动收回在途货物",{autoUnload=1}},
 }},
 {id="ballistics",name="弹道军械",icon="turret",items={
  {"精密炮膛","武器伤害 +8%",{damage=.08}}, {"高压弹药","武器伤害再 +8%",{damage=.08}},
  {"快速闭锁","射速 +6%",{fire=.06}}, {"磁轨蓝图","解锁副武器：磁轨枪",{unlockRail=1}},
  {"高速推进","炮弹飞行速度 +25%",{projectileSpeed=.25}}, {"破片扩散","主炮爆炸半径 +30%",{splash=.3}},
  {"密集弹芯","武器伤害 +10%",{damage=.1}}, {"第五发协议","每第 5 发主炮造成 1.75 倍伤害",{fifthShot=1}},
 }},
 {id="energy",name="能量武器",icon="crystal",items={
  {"辅助电容","副武器伤害 +8%",{auxDamage=.08}}, {"电弧蓝图","解锁副武器：电弧线圈",{unlockArc=1}},
  {"循环供能","射速 +6%",{fire=.06}}, {"燃烧蓝图","解锁副武器：喷焰器",{unlockFlame=1}},
  {"长效电池","弹药、加速等增益延长 20%",{buffTime=.2}}, {"额外节点","电弧多连锁 1 个目标",{arcTargets=1}},
  {"护盾调谐","护盾期间再减伤 10%",{shieldReduction=.1}}, {"聚变反应堆","武器伤害 +15%",{damage=.15}},
 }},
 {id="logistics",name="补给后勤",icon="ammo",items={
  {"出发储备","初始矿料 +40",{startOre=40}}, {"急救培训","维修效果 +15%",{repair=.15}},
  {"备用频道","每局增加 1 次免费重抽",{freeRerolls=1}}, {"工蜂空投","解锁补给：机器人支援",{unlockDrone=1}},
  {"扩充仓库","初始矿料 +80",{startOre=80}}, {"残骸协议","击杀矿料收入 +20%",{salvage=.2}},
  {"议价协议","付费重抽价格 -30%",{rerollDiscount=.3}}, {"超频货柜","解锁补给：超载核心",{unlockOverclock=1}},
 }},
 {id="expedition",name="远征档案",icon="ore",items={
  {"数据归档","结算研究数据 +8%",{research=.08}}, {"货物保险","结算合金 +10%",{alloy=.1}},
  {"迫击蓝图","解锁副武器：迫击炮",{unlockMortar=1}}, {"晶体勘探","晶体奖励 +25%",{crystals=.25}},
  {"残骸打捞","失败保留比例 35% → 45%",{lossRetention=.1}}, {"深层记录","结算研究数据 +15%",{research=.15}},
  {"核心回收","完成追加两波时额外获得 1 核心",{coreBonus=1}}, {"出发屏障","开战时自带 12 秒护盾",{startShield=12}},
 }},
}
local gates={0,2,5,5,8,10,10,12}
for col,b in ipairs(branches) do
 T.branches[#T.branches+1]={id=b.id,name=b.name,icon=b.icon,column=col}
 for tier,item in ipairs(b.items) do
  local id=b.id.."_"..tier
  local prerequisites={};if tier>1 then prerequisites[1]=b.id.."_"..(tier-1) end
  -- Cross-discipline gates give the large graph actual topology, not six disconnected shopping lists.
  if tier==4 then prerequisites[#prerequisites+1]=branches[(col%6)+1].id.."_2" end
  if tier==7 then prerequisites[#prerequisites+1]=branches[((col+1)%6)+1].id.."_4" end
  T.nodes[id]={id=id,name=item[1],detail=item[2],effects=item[3],branch=b.id,column=col,tier=tier,icon=b.icon,
    prereqs=prerequisites,minWave=gates[tier],cost={alloy=60+tier*tier*18,research=6+tier*5,crystals=tier>=3 and (tier-2)*2 or 0,cores=tier>=6 and tier-5 or 0}}
  T.order[#T.order+1]=id
 end
end
-- Early functional unlock without renaming persistent node IDs: old ownership is preserved.
T.nodes.energy_2.prereqs={};T.nodes.energy_2.minWave=0
T.nodes.energy_2.cost={alloy=120,research=20,crystals=0,cores=0}
return T
