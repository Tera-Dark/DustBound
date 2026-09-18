-- Three persistent currencies; in-run gold is a separate robot-funded ledger.
local E={}
function E.curve(node)
 local t=math.max(0,node-4)
 return 1+.025*t+.0015*t*t,1+.018*t,1+.012*t
end
function E.reward(node,won,first,completed,kills)
 local baseA=85+node.id*12;local baseD=18+node.id*3
 local progress=math.max(0,math.min(1,(completed+.35)/node.waves))
 local factor=won and (first and 1.5 or .6) or kills>=3 and .35*progress or 0
 return {alloy=math.floor(baseA*factor),research=math.floor(baseD*factor),cores=won and first and node.node==8 and 1 or 0}
end
local function replace(n,effects,detail) n.effects=effects;n.detail=detail end
function E.configure(C)
 if C.economyReady then return end
 C.Tech=C.ResearchWeb.build(C.Tech)

 local n=C.Tech.nodes
 replace(n.industry_1,{robotCargo=.1},"机器人单次挖矿数量 +10%")
 replace(n.industry_2,{robotDig=.12},"机器人挖矿速度 +12%")
 replace(n.industry_4,{robotMove=.15},"机器人移动速度 +15%")
 replace(n.industry_5,{robotCargo=.2},"机器人单次挖矿数量 +20%")
 replace(n.industry_7,{robotDig=.15},"机器人挖矿速度 +15%")
 replace(n.logistics_1,{robotMove=.1},"机器人移动速度 +10%")
 replace(n.logistics_4,{robotDig=.1},"机器人挖矿速度 +10%")
 replace(n.logistics_5,{robotCargo=.15},"机器人单次挖矿数量 +15%")
 replace(n.logistics_6,{robotCargo=.2},"机器人单次挖矿数量 +20%；不再从击杀获得金矿")
 replace(n.logistics_7,{rerollDiscount=.3},"付费重抽价格降低 30%")
 replace(n.logistics_8,{digPerRobot=.035},"终极工蜂网络：每台机器人使挖矿速度 +3.5%")
 replace(n.energy_2,{arcDamage=.18},"电弧伤害 +18%；电弧已进入基础抽取池")
 replace(n.energy_4,{flameDamage=.18},"喷焰器伤害 +18%；喷焰器已进入基础抽取池")
 replace(n.ballistics_4,{railDamage=.18},"磁轨枪伤害 +18%；磁轨枪已进入基础抽取池")
 replace(n.expedition_3,{mortarDamage=.18},"迫击炮伤害 +18%；迫击炮已进入基础抽取池")
 replace(n.energy_5,{fire=.08},"整局武器射速 +8%")
 replace(n.energy_7,{mitigation=.04},"受到伤害降低 4%")
 replace(n.fort_7,{mitigation=.04},"受到伤害降低 4%")
 replace(n.expedition_4,{research=.1},"关卡研究数据奖励 +10%")
 replace(n.expedition_5,{lossRetention=.1},"失败材料保留倍率额外 +10% 基础值")
 replace(n.expedition_7,{alloy=.12},"关卡合金奖励 +12%")
 replace(n.expedition_8,{mitigation=.08},"终极出发屏障：整局受到伤害降低 8%")
 for _,id in ipairs(C.Tech.order) do
  local node=C.Tech.nodes[id];local b=node.effects
  node.kind=node.tier==8 and "ultimate" or (b.robots or b.arcTargets or b.freeRerolls or b.autoUnload) and "function" or "basic"
  if node.kind=="basic" then node.cost={alloy=50+node.tier*node.tier*12,research=node.tier>=5 and 12 or 0,crystals=0,cores=0}
  elseif node.kind=="function" then node.cost={alloy=50+node.tier*20,research=24+node.tier*12,crystals=0,cores=0}
  else node.cost={alloy=650,research=160,crystals=0,cores=1};node.minWave=8 end
 end
 for _,node in ipairs(C.Catalog.campaign) do
  node.waves=C.RunSystems.waves[node.id];node.hp,node.attack,node.density=E.curve(node.id)
  node.startOre=0;node.reward=E.reward(node,true,false,0,0)
 end
 for key,def in pairs(C.RunSystems.upgrades) do
  C.Upgrades[key]={name=def.name,description=def.name.." · 金矿投资",cost=def.cost,growth=def.growth,cap=def.cap,icon="drill",color="orange"}
 end
 C.Categories.mining={"move","dig","cargo","robots"}
 C.ActiveUpgradeIds={"move","dig","cargo","robots","damage","rate","barrel","armor","repair","regen"}
 for id,name in pairs({energy_2="电弧增幅",energy_4="热能增幅",ballistics_4="磁轨增幅",expedition_3="迫击增幅",logistics_1="启程轴承",logistics_4="钻探协同",logistics_6="矿运协议",expedition_4="数据勘探",expedition_7="合金回收",fort_7="防御稳压",energy_7="防御调谐"}) do C.Tech.nodes[id].name=name end
 C.Catalog.enemies.flyer={name="掠翼虫",body="flyerBody",hp=20,hpWave=4,speed=44,attack=8,attackWave=1,interval=1.8,range=190,color={92,143,157},firstWave=3,desc="从战场上方接近的飞行兵。",tip="低耐久、移动较快；从空域向下俯冲，悬停后攻击；优先用速射清理。"}
 C.Catalog.order.enemies={"crawler","tank","flyer"}
 C.Catalog.supplies=C.RunSystems.relics;C.Catalog.order.supplies=C.RunSystems.relicOrder
 for _,d in pairs(C.Catalog.supplies) do d.desc=d.detail;d.icon="crystal";d.tip="免费选择，持续整局；本局已拥有的遗物不再进入抽取池。" end
 for _,d in pairs(C.Catalog.weapons) do d.tech=nil;d.visual.aimMin=-180;d.visual.aimMax=180 end
 C.WeaponMounts={
  {id=1,name="主炮",x=720,y=272,fireX=720,fireY=272,scale=.65},
  {id=2,name="副位 1",x=630,y=338,fireX=630,fireY=338,scale=.52},
  {id=3,name="副位 2",x=810,y=338,fireX=810,fireY=338,scale=.52},
  {id=4,name="副位 3",x=665,y=397,fireX=665,fireY=397,scale=.52},
  {id=5,name="副位 4",x=775,y=397,fireX=775,fireY=397,scale=.52},
 }
 C.Supplies=C.Catalog.supplies
 C.economyReady=true
end
return E
