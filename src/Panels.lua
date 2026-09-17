-- Adaptive native panels: compact screens use branch/list/detail views, never a shrunken six-column tree.
local P={}
local Gallery=require(script.Parent.Gallery)
local TechMap=require(script.Parent.TechMap)
function P.new(ctx)
 local U,C,R,Guide,Art=ctx.U,ctx.C,ctx.R,ctx.Guide,ctx.Art;local c=U.colors
 local live=nil
 local self={builds=0,revision=0,tech="energy_2",branch=4,category="weapons",entry="cannon",query="",weapon="machine",slot=1,settingsTab="general",scrolls={}}
 local function dirty() self.revision=self.revision+1 end
 local function txt(p,n,v,x,y,w,h,size,bold) return U.text(p,n,v,x,y,w,h,size or 22,c.ink,bold) end
 local function btn(p,n,v,x,y,w,h,fn,accent) return U.button(p,n,v,x,y,w,h,fn,accent) end
 local function scroll(p,n,x,y,w,h,ch)
  local f=U.scroll(p,n,x,y,w,h,ch);f.CanvasPosition=self.scrolls[n] or Vector2.zero;return f
 end
 local function wallet(p) return "合金 "..p.alloy.."   数据 "..p.research.."   晶体 "..p.crystals.."   核心 "..p.cores end
 local function search(p,n,x,y,w,placeholder,value,fn)
  local t=Instance.new("TextBox");t.Name=n;t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,62);t.BackgroundColor3=c.paper;t.BorderSizePixel=0;t.Text=value;t.PlaceholderText=placeholder;t.TextColor3=c.ink;t.TextSize=22;t.Font=Enum.Font.Gotham;t.ClearTextOnFocus=false;t.Parent=p;U.corner(t,8)
  t.FocusLost:Connect(function() local q=t.Text;local cut=utf8.offset(q,61);fn(cut and q:sub(1,cut-1) or q);dirty() end);return t
 end
 function self.build(m,kind,s,compact,W,H)
  for _,connection in ipairs(self.mapConnections or {}) do connection:Disconnect() end;self.mapConnections={}
  self.builds=self.builds+1;self.latest=s;live=nil
  if self.lastKind==kind and self.compact==compact then
   for _,o in ipairs(m:GetChildren()) do if o:IsA("ScrollingFrame") then self.scrolls[o.Name]=o.CanvasPosition end end
  else self.scrolls={} end
  self.lastKind=kind;self.compact=compact;U.clear(m)
  local function head(title,sub,close)
   txt(m,"Title",title,22,10,W-258,46,compact and 30 or 36,true)
   txt(m,"Description",sub,24,57,W-135,47,compact and 21 or 19)
   if close then
    if ctx.canBack and ctx.canBack() then btn(m,"Back","‹ 返回",W-218,12,118,66,ctx.close) end
    btn(m,"Close","×",W-86,12,72,66,ctx.dismiss or ctx.close)
   end
  end
  local bodyY=116;local bodyH=H-206;local footer=H-80
  if kind=="help" then
   head("指挥官手册 / 三分钟上手","不需要瞄准，也不需要手动采矿；你负责每次投入。",true)
   local body=scroll(m,"HelpBody",22,bodyY,W-44,bodyH,760)
   local rows={
    {"01 / 自动守卫","主炮与副武器自动攻击。虫潮生成结束后还要清剿，不能只看倒计时。"},
    {"02 / 投资选择","矿料是本局资金。先读升级前后效果；满耐久不能维修，研究要回主菜单进行。"},
    {"03 / 补给与采矿","清场后选择一份补给。选择期间冻结计时；接收后开始整备，机器人返航才入账。"},
    {"04 / 能源与增益","采矿优先：产量 +40%、射速 −20%；防御优先：射速 +25%、产量 −20%。增益只在对应阶段倒计时。"},
    {"05 / 撤离与进度","标准十波后可撤离或追加两波。剩余矿料用于结算；放弃、关闭游戏不等于撤离，本版不支持断线续局。"},
    {"06 / 操作与舒适度","电脑：1/2/3 切换投资，P 暂停。触屏：点分类与左右箭头。设置可关闭伤害数字、降低动效与音量。"},
   }
   for i,row in ipairs(rows) do txt(body,"HelpTitle"..i,row[1],10,(i-1)*123,W-84,32,25,true);txt(body,"HelpText"..i,row[2],10,(i-1)*123+38,W-84,73,22) end
   btn(m,"HelpDone","明白了，返回",22,footer,W-44,72,ctx.close,true)
  elseif kind=="campaign" then
   head("星球航图 / 24 个远征节点",wallet(s.profile),true)
   local cleared=s.profile.campaignCleared or 0
   self.mission=self.mission or math.min(24,cleared+1)
   local selected=C.Catalog.campaign[self.mission];self.planet=selected.planet
   local pw=(W-60)/3
   for i,planet in ipairs(C.Catalog.planets) do
    local b=btn(m,"Planet_"..i,"",20+(i-1)*(pw+10),bodyY,pw,90,function() self.planet=i;self.mission=(i-1)*8+1;dirty() end,i==self.planet)
    Gallery.sprite(b,planet.art,6,6,76,76)
    txt(b,"PlanetName",planet.name,90,5,pw-98,39,compact and 18 or 23,true)
    txt(b,"PlanetProgress",math.max(0,math.min(8,cleared-(i-1)*8)).." / 8 已完成",90,47,pw-98,28,18)
   end
   local left=math.floor(W*.59);local top=bodyY+108
   local map=U.frame(m,"PlanetRoutes",20,top,left-20,bodyH-108,c.paper);U.corner(map,12)
   local cell=(left-40)/4;local gapY=compact and 98 or 142
   local previous=nil
   for j=1,8 do
    local col=j<=4 and j-1 or 8-j;local row=j<=4 and 0 or 1
    local xx=12+col*cell;local yy=12+row*gapY
    if previous then
     local ax,ay=previous[1]+cell*.4,previous[2]+35;local bx,by=xx+cell*.4,yy+35
     local dx,dy=bx-ax,by-ay;local wire=U.frame(map,"Route_"..j,(ax+bx)/2,(ay+by)/2,math.sqrt(dx*dx+dy*dy),4,c.mint);wire.AnchorPoint=Vector2.new(.5,.5);wire.Rotation=math.deg(math.atan2(dy,dx))
    end
    previous={xx,yy}
   end
   for j=1,8 do
    local id=(self.planet-1)*8+j;local node=C.Catalog.campaign[id]
    local col=j<=4 and j-1 or 8-j;local row=j<=4 and 0 or 1
    local b=btn(map,"Mission_"..id,"",12+col*cell,12+row*gapY,cell-12,compact and 84 or 122,function() self.mission=id;dirty() end,id==self.mission)
    b.BackgroundColor3=id<=cleared and c.mint or id==cleared+1 and c.orange or c.cream
    Gallery.sprite(b,node.boss and "elite" or C.Catalog.planets[self.planet].art,6,5,compact and 32 or 54,compact and 32 or 54)
    txt(b,"NodeNumber",string.format("%02d",j),compact and 44 or 70,6,cell-(compact and 66 or 90),30,22,true)
    txt(b,"NodeSummary",node.waves.." 波 · "..(id<=cleared and "已通关" or id==cleared+1 and "可挑战" or "未解锁"),6,compact and 42 or 66,cell-24,compact and 35 or 44,compact and 15 or 19,true)
   end
   local x=left+18;local w=W-x-22
   local detail=scroll(m,"MissionInspector",x,top,w,bodyH-108,680)
   local reward=R.campaignReward(selected,true,self.mission>cleared,0,1,R.bonuses(s.profile,C))
   local repeatReward=R.campaignReward(selected,true,false,0,1,R.bonuses(s.profile,C))
   txt(detail,"MissionTitle",string.format("%d-%02d / ",selected.planet,selected.node)..selected.name,5,0,w-16,42,compact and 22 or 27,true)
   txt(detail,"MissionDifficulty",selected.waves.." 波 · 耐久 ×"..string.format("%.2f",selected.hp).." · 攻击 ×"..string.format("%.2f",selected.attack).."\n出发额外矿料 +"..selected.startOre..(selected.boss and " · 终波精英" or ""),5,48,w-16,86,21)
   txt(detail,"MissionReward",(self.mission>cleared and "首通" or "重打").."奖励\n"..reward.alloy.." 合金 / "..reward.research.." 数据\n"..reward.crystals.." 晶体 / "..reward.cores.." 核心",5,145,w-16,116,22,true)
   txt(detail,"ReplayReward","重打固定基准："..repeatReward.alloy.." 合金 / "..repeatReward.research.." 数据\n晶体 "..repeatReward.crystals.." / 核心 "..repeatReward.cores,5,272,w-16,88,19)
   txt(detail,"MissionAdvice",C.Catalog.planets[self.planet].hint.."\n失败按推进进度保留部分收益（至少击杀 3 个敌人）；核心需要胜利。无体力消耗，可回刷旧节点。",5,377,w-16,158,21)
   txt(detail,"ResourceGuide","合金 + 数据：基础研究\n晶体：第 5 节点起；核心：星球中枢和紫霜胜利\n研究还受波次与前置约束，可在科技树定位。",5,548,w-16,122,20)
   local launch=btn(m,"LaunchMission",self.mission>cleared+1 and "先完成前一节点" or self.mission<=cleared and "重打节点" or "前往节点",22,footer,(W-64)*.58,72,function() ctx.open(nil);ctx.send("start",{node=self.mission}) end,true)
   U.enabled(launch,self.mission<=cleared+1 and (s.phase=="menu" or s.phase=="ended"))
   btn(m,"CampaignResearch","卡关？调整研究 / 配装",44+(W-64)*.58,footer,(W-64)*.42,72,function() ctx.open("research") end)
  elseif kind=="research" then
   head("研究中心 / 科技目标",wallet(s.profile),true)
   local left=compact and math.floor(W*.57) or 884;local dx=left+40;local dw=W-dx-22
   TechMap.build({U=U,C=C,R=R,Gallery=Gallery,dirty=dirty},m,self,s,20,176,left,bodyH-86)
   local n=C.Tech.nodes[self.tech] or C.Tech.nodes.energy_2;local state,msg=R.techState(s.profile,n.id,C)
   local detail=scroll(m,"TechInspector_"..n.id,dx,bodyY,dw,bodyH,520)
   txt(detail,"NodeTitle",n.name,7,0,dw-20,43,29,true)
   txt(detail,"Effect",n.detail,7,47,dw-25,60,23)
   txt(detail,"Gate","完成波次 "..n.minWave.." / 当前 "..s.profile.bestWave,7,115,dw-22,31,20)
   local cost=n.cost
   txt(detail,"Cost",cost.alloy.." 合金 + "..cost.research.." 数据\n"..cost.crystals.." 晶体 + "..cost.cores.." 核心",7,156,dw-25,72,22,true)
   local y=226
   for i,pre in ipairs(n.prereqs) do
    btn(detail,"Prereq_"..pre,(s.profile.tech[pre] and "✓ " or "前置 → ")..C.Tech.nodes[pre].name,7,y+(i-1)*76,dw-25,66,function()
     self.tech=pre;self.branch=C.Tech.nodes[pre].column;local nx,ny=TechMap.position(C.Tech.nodes[pre]);self.zoom=.85;self.nextCanvas=Vector2.new(math.max(0,nx*.85-left/2),math.max(0,ny*.85-(bodyH-86)/2));dirty()
    end)
   end
   if #n.prereqs==0 then txt(detail,"NoPrereq","无需前置研究",7,y,dw-25,36,21) end
   local missing={}
   for _,v in ipairs({{"alloy","合金"},{"research","数据"},{"crystals","晶体"},{"cores","核心"}}) do local gap=(cost[v[1]] or 0)-(s.profile[v[1]] or 0);if gap>0 then missing[#missing+1]=v[2].."缺 "..gap end end
   if state=="poor" then msg=table.concat(missing," / ") end
   txt(detail,"TechStatus",msg,7,y+math.max(1,#n.prereqs)*76,dw-25,44,21,true)
   btn(m,"TrackedTarget",s.profile.targetResearch==n.id and "取消追踪" or "固定研究目标",22,footer,(W-64)*.42,72,function() ctx.send("target",s.profile.targetResearch==n.id and "" or n.id) end)
   local b=btn(m,"ResearchNode",state=="owned" and "已完成研究" or "确认研究",44+(W-64)*.42,footer,(W-64)*.58,72,function() ctx.send("research",n.id) end,true);U.enabled(b,state=="ready" and (s.phase=="menu" or s.phase=="ended"))
  elseif kind=="workshop" then
   head("武器工坊 / 配装", "5 个挂点：主炮 + 1 件副武器启用；另 3 位预留。",true)
   local left=compact and 290 or 350
   local list=scroll(m,"WeaponList",20,bodyY,left,bodyH,5*84)
   for i,id in ipairs({"machine","arc","rail","flame","mortar"}) do local d=C.Catalog.weapons[id]
    btn(list,"Weapon_"..id,d.name..(s.loadout==id and " · 已装备" or not R.unlocked(s.profile,d) and " · 未解锁" or ""),4,4+(i-1)*84,left-17,72,function() self.weapon=id;dirty() end,self.weapon==id)
   end
   local id=self.weapon;local d=C.Catalog.weapons[id];local x=left+44;local w=W-x-23
   local detail=scroll(m,"WeaponDetail",x,bodyY,w,bodyH,535)
   Gallery.sprite(detail,id,6,0,200,200)
   local content=U.frame(detail,"WeaponInfo",0,216,w,535,nil,1);detail.CanvasSize=UDim2.fromOffset(0,751);detail=content
   txt(detail,"WeaponName",d.name,6,0,w-20,46,30,true)
   txt(detail,"WeaponStats","间隔 "..d.interval.." 秒 · 系数 ×"..d.multiplier.."\n"..d.desc,6,55,w-22,118,23)
   txt(detail,"WeaponGate",d.tech and "需要："..C.Tech.nodes[d.tech].name or "初始解锁",6,181,w-22,40,21)
   if d.tech and not R.unlocked(s.profile,d) then btn(detail,"GoUnlock","定位解锁研究",6,234,w-23,66,function() self.tech=d.tech;self.branch=C.Tech.nodes[d.tech].column;ctx.open("research") end) end
   btn(detail,"PresetSlot","预设槽 "..self.slot.." · "..C.Catalog.weapons[s.profile.presets[self.slot]].name.." · 点击切换",6,316,w-23,68,function() self.slot=self.slot%2+1;dirty() end)
   txt(detail,"ReservedWeaponSlots","01 主炮 · 02 当前副武器\n03 / 04 / 05 预留 · 本版本不可装备",6,400,w-22,88,21)
   local can=R.unlocked(s.profile,d)
   local equip=btn(m,"Equip_"..id,s.loadout==id and "已装备" or can and "装备副武器" or "尚未解锁",22,footer,(W-72)/3,72,function() ctx.send("loadout",id) end,true);U.enabled(equip,can and s.loadout~=id)
   btn(m,"SavePreset","保存预设 "..self.slot,36+(W-72)/3,footer,(W-72)/3,72,function() ctx.send("preset",{slot=self.slot,mode="save"}) end)
   btn(m,"UsePreset","应用预设 "..self.slot,50+(W-72)*2/3,footer,(W-72)/3,72,function() ctx.send("preset",{slot=self.slot,mode="equip"}) end)
  elseif kind=="codex" then
   head("远征档案 / 图鉴","基础参数、使用说明和累计记录；输入名称可筛选。",true)
   local left=compact and 300 or 354
   for i,g in ipairs({{"weapons","武器"},{"supplies","补给"},{"enemies","怪物"}}) do
    btn(m,"Codex_"..g[1],g[2],20+(i-1)*(left/3),112,left/3-7,66,function() self.category=g[1];self.entry=C.Catalog.order[g[1]][1];self.query="";dirty() end,self.category==g[1])
   end
   search(m,"CodexSearch",20,188,left-7,"名称 / 回车筛选",self.query,function(q) self.query=q end)
   local list=scroll(m,"CodexList",20,261,left,H-279,7*98);local i=0
   for _,id in ipairs(C.Catalog.order[self.category]) do local d=C.Catalog[self.category][id]
    if self.query=="" or string.find(d.name,self.query,1,true) then
     local card=btn(list,"Entry_"..id,d.name,4,4+i*98,left-17,88,function() self.entry=id;dirty() end,self.entry==id);card.TextXAlignment=Enum.TextXAlignment.Right;card.TextSize=21
     Gallery.sprite(card,self.category=="supplies" and "crate" or id,7,7,72,72);i=i+1
    end
   end
   if i==0 then txt(list,"Empty","没有匹配的条目",8,9,left-25,55,23) end
   local d=C.Catalog[self.category][self.entry];local x=left+44;local w=W-x-23;local body=scroll(m,"CodexInspector",x,bodyY,w,H-bodyY-18,620)
   Gallery.sprite(body,self.category=="supplies" and "crate" or self.entry,8,0,math.min(compact and 142 or 236,w-25),math.min(compact and 142 or 236,w-25))
   local portraitOffset=math.min(compact and 142 or 236,w-25)+16
   local detailContent=U.frame(body,"EntryText",0,portraitOffset,w,620,nil,1)
   body.CanvasSize=UDim2.fromOffset(0,620+portraitOffset);body=detailContent
   txt(body,"EntryTitle",d.name,8,0,w-25,48,30,true)
   local count=s.profile.codex[self.category][self.entry] or 0
   txt(body,"Record","累计 "..count..(self.category=="weapons" and " 次发射" or self.category=="enemies" and " 次击杀" or " 次接收"),8,54,w-25,36,22)
   txt(body,"Description",d.desc,8,105,w-25,94,24)
   local stats=self.category=="weapons" and "伤害系数 ×"..d.multiplier.." / 间隔 "..d.interval.." 秒 / 射程 "..d.range or self.category=="enemies" and "首次出现第 "..d.firstWave.." 波\n耐久 "..d.hp.." + 波次 ×"..d.hpWave.."\n回收 "..d.reward.." 矿料 / 攻击间隔 "..d.interval.." 秒" or d.detail
   txt(body,"Stats",stats,8,210,w-25,116,23,true)
   txt(body,"Tip",d.tip or "补给三选一；采矿 Buff 仅在整备计时，战斗 Buff 仅在战斗计时。",8,340,w-25,108,22)
   if d.tech then btn(body,"LocateTech","定位解锁研究",8,467,w-25,66,function() self.tech=d.tech;self.branch=C.Tech.nodes[d.tech].column;ctx.open("research") end) end
  elseif kind=="settings_reset" then
   head("恢复默认设置？","只重置偏好，不会删除科技、资源、配装或教学进度。",false)
   txt(m,"ResetExplanation","将恢复声音、显示与操作选项的默认值。\n已暂停的远征仍会保持暂停，请手动继续。",28,142,W-56,H-270,26)
   btn(m,"CancelSettingsReset","保留当前设置",22,footer,(W-62)/2,72,ctx.close)
   btn(m,"ConfirmSettingsReset","确认恢复默认",40+(W-62)/2,footer,(W-62)/2,72,function() if ctx.send("settings_reset","confirm") then ctx.close() end end,true)
  elseif kind=="reroll_confirm" then
   local pending=self.pendingReroll or {token=-1,cost=0}
   local valid=s.supply and s.supply.token==pending.token and s.rerollCost==pending.cost and s.ore>=pending.cost and s.rerolls<s.rerollMax
   head("确认付费重抽？","只消耗本局矿料，不涉及 Robux。",false)
   txt(m,"RerollCost","本次消耗 "..pending.cost.." 矿料\n当前拥有 "..s.ore.." 矿料\n"..(valid and "新补给会替换当前三选一，无法撤销。" or "补给状态或预算已变化，请返回重新查看。"),28,135,W-56,H-250,27,true)
   btn(m,"CancelReroll","保留当前补给",22,footer,(W-62)/2,72,ctx.close)
   local confirm=btn(m,"ConfirmReroll","确认消耗 "..pending.cost.." 矿料",40+(W-62)/2,footer,(W-62)/2,72,function() if ctx.send("reroll",pending.token) then ctx.close() end end,true);U.enabled(confirm,valid==true)
  elseif kind=="settings" then
   head("设置",(s.storage.mode=="local" or s.storage.mode=="guest") and "本地 / 访客：偏好仅在本次会话保留。" or "偏好随档案保存；关闭设置不会自动恢复远征。",true)
   local tabs={{"general","常用"},{"audio","声音"},{"display","显示"},{"advanced","高级"}}
   local tabWidth=(W-62)/4
   for i,d in ipairs(tabs) do
    local id=d[1];local button=btn(m,"SettingsTab_"..id,(self.settingsTab==id and "✓ " or "")..d[2],22+(i-1)*(tabWidth+6),112,tabWidth,58,function() self.settingsTab=id;dirty() end)
    button.BackgroundColor3=self.settingsTab==id and c.mint or c.cream
   end
   local cfg=s.profile.settings;local contentY=188;local contentH=H-282
   local function row(parent,index,name,title,description,key)
    local y=(index-1)*112
    local panel=U.frame(parent,"Setting_"..name,0,y,W-58,102,c.paper,.35);U.corner(panel,10)
    txt(panel,"Label",title,16,8,W-274,34,25,true)
    txt(panel,"Hint",description,16,44,W-274,48,compact and 19 or 20)
    local state=cfg[key] and "✓ 开启" or "— 关闭"
    local toggle=btn(panel,name,state,W-232,22,156,58,function() ctx.send("settings",{key=key,value=not self.latest.profile.settings[key]}) end)
    toggle.BackgroundColor3=cfg[key] and c.mint or c.cream
    return panel
   end
   if self.settingsTab=="general" then
    local body=scroll(m,"SettingsGeneral",22,contentY,W-44,contentH,5*112)
    row(body,1,"ShowTips","战术建议","隐藏普通建议；教学、危险和存档提醒仍保留。","showTips")
    row(body,2,"CompactNumbers","简写资源数字","K=千，M=百万；购买价格与结算始终显示精确数值。","compactNumbers")
    row(body,3,"AutoPause","切出窗口自动暂停","切回后手动继续，不会擅自恢复战斗。","autoPause")
    row(body,4,"ConfirmReroll","付费重抽确认","免费重抽不打断；消耗矿料前再确认一次。","confirmReroll")
    row(body,5,"Hotkeys","游戏快捷键","P 暂停，1 / 2 / 3 分类，退格返回；F6 诊断独立可用。","hotkeys")
   elseif self.settingsTab=="display" then
    local body=scroll(m,"SettingsDisplay",22,contentY,W-44,contentH,5*112)
    row(body,1,"Motion","轻量动效","降低复杂姿态更新，保留移动、弹丸和战斗信息。","reducedMotion")
    row(body,2,"DamageNumbers","伤害数字","控制伤害飘字；矿料入库和升级反馈仍会显示。","damageNumbers")
    row(body,3,"ScreenShake","受击震动","仅关闭基地受击抖动，不改变受伤判定。","screenShake")
    row(body,4,"FlashEffects","闪光特效","关闭枪口、命中闪光与冲击光圈，保留弹道。","flashEffects")
    row(body,5,"EnemyHealth","敌人血条","控制敌人头顶血条；基地耐久始终显示。","enemyHealth")
   elseif self.settingsTab=="audio" then
    local body=scroll(m,"SettingsAudio",22,contentY,W-44,contentH,530)
    row(body,1,"MasterMuted","全部静音","保留音量数值，取消静音后恢复原音量。","masterMuted")
    row(body,2,"MuteUnfocused","后台静音","切到其他窗口时停止提示音并静音音乐。","muteUnfocused")
    for i,d in ipairs({{"sfx","音效音量"},{"music","音乐音量"}}) do
     local y=230+(i-1)*112;local key=d[1]
     txt(body,"AudioLabel_"..key,d[2],16,y,W-370,40,25,true)
     txt(body,"AudioHint_"..key,key=="music" and "未配置音乐资源时，此选项不会凭空生成音乐。" or "战斗、领取和按钮反馈音；每次调整 10%。",16,y+44,W-370,50,19)
     btn(body,"Less_"..key,"−",W-345,y+13,70,66,function() ctx.send("settings",{key=key,value=self.latest.profile.settings[key]-.1}) end)
     txt(body,"Volume_"..key,math.floor(cfg[key]*100+.5).."%",W-264,y+18,110,54,25,true)
     btn(body,"More_"..key,"+",W-146,y+13,70,66,function() ctx.send("settings",{key=key,value=self.latest.profile.settings[key]+.1}) end)
    end
    btn(body,"TestSound","试听反馈音",16,462,W-90,60,function() ctx.audio.play("upgrade") end)
   else
    live={};local info=scroll(m,"SettingsDetails",22,contentY,W-44,contentH,760)
    txt(info,"ArtMode","图像："..Art.detail.."\n声音："..ctx.audio.mode,8,0,W-82,80,21)
    txt(info,"Storage","存档："..(s.saveStatus or "本地会话"),8,88,W-82,65,21)
    txt(info,"Metrics","分析："..s.telemetry.status.." · 本地已记录 "..s.telemetry.total.." 事件",8,164,W-82,60,21)
    live.Performance=txt(info,"Performance",ctx.performance and ctx.performance() or "",8,234,W-82,280,20)
    btn(info,"ToggleDiagnostics","显示 / 隐藏悬浮诊断（F6）",8,530,W-82,68,function() if ctx.toggleDiagnostics then ctx.toggleDiagnostics() end end)
    btn(info,"RetrySave","重试保存 / 读取",8,612,W-82,68,function() ctx.send("save_retry") end)
    txt(info,"DiagnosticHelp","诊断仅用于排查问题；云存档与真机性能需在 Roblox 实测。",8,693,W-82,52,19)
   end
   btn(m,"ResetSettings","恢复默认…",22,footer,(W-62)/2,72,function() ctx.open("settings_reset") end)
   btn(m,"SettingsDone","完成",40+(W-62)/2,footer,(W-62)/2,72,ctx.close,true)
  elseif kind=="pause" then
   head("远征已暂停","战斗、机器人、Buff 与 30 秒整备计时已冻结。",false)
   local half=(W-66)/2
   btn(m,"Resume","继续远征",22,140,half,86,function() ctx.open(nil);ctx.send("pause",false) end,true)
   btn(m,"PauseSettings","设置",44+half,140,half,86,function() ctx.open("settings") end)
   btn(m,"PauseCodex","查看图鉴",22,244,half,86,function() ctx.open("codex") end)
   btn(m,"PauseMenu","返回主菜单",44+half,244,half,86,function() ctx.open("abandon") end)
   txt(m,"PauseSummary","第 "..s.wave.." 波 · 矿料 "..s.ore.." · 已采集 "..s.totalMined.."\n"..(s.supply and "还有补给待选：继续后仍会等待选择。" or s.stage=="mining" and "整备剩余 "..math.ceil(s.breakLeft).." 秒" or "快捷键 P 继续"),24,351,W-48,H-371,24)
  elseif kind=="abandon" then
   head("确认放弃远征？","此操作不结算本局奖励。",false)
   txt(m,"Warning","将放弃本局矿料、研究和稀有资源。\n此前科技、跨局资源和图鉴不受影响。\n本版本尚未提供中途断线续局。",30,140,W-60,H-260,27,true)
   btn(m,"CancelAbandon","取消，回到暂停菜单",22,footer,(W-62)/2,72,function() ctx.open("pause") end,true)
   btn(m,"ConfirmAbandon","确认放弃并返回",40+(W-62)/2,footer,(W-62)/2,72,function() ctx.open(nil);ctx.send("abandon","confirm") end)
  elseif kind=="storage" then
   head("云档未就绪 · 已保护旧进度","未成功读取的云档不会被空白档案覆盖。",false)
   txt(m,"CloudFailure",s.saveStatus..(s.storage.mode=="lock_lost" and "\n\n为避免并发覆盖，当前远征已冻结。请通过 Roblox 菜单退出后重新加入。未保存的修改可能丢失。" or "\n\n可以稍后重试，或明确进入不保存的访客试玩。\n访客进度不会合并进云档。"),30,131,W-60,H-235,25)
   local b=btn(m,"RetryRead",s.storage.busy and "正在重试…" or "重试读取",22,footer,(W-62)/2,72,function() ctx.send("save_retry") end,true);U.enabled(b,not s.storage.busy and s.storage.mode=="read_error")
   local guest=btn(m,"Guest","确认进入不保存的试玩",40+(W-62)/2,footer,(W-62)/2,72,function() ctx.send("guest","confirm") end);U.enabled(guest,not s.storage.busy and s.storage.mode=="read_error")
  elseif kind=="supply" then
   head("整备补给 / 三选一","选择期间计时暂停。可先返回投资，再领取补给。",false)
   local width=(W-68)/3;local selected=ctx.selectedSupply() or Guide.supplyChoice(s,C,R);local recommended=Guide.supplyChoice(s,C,R)
   for i,id in ipairs(s.supply.options) do local d=C.Catalog.supplies[id];local info=Guide.supply(id,s,C,R)
    local b=btn(m,"Choice_"..id,"",22+(i-1)*(width+12),bodyY,width,bodyH,function() ctx.selectSupply(id);dirty() end,id==selected)
    txt(b,"Name",(id==selected and "✓ " or "")..d.name..(id==recommended and " ★" or ""),12,12,width-24,43,27,true)
    txt(b,"Detail",info.detail,12,67,width-24,compact and 73 or 95,compact and 22 or 24)
    local extra=scroll(b,"SupplyDetail_"..id,12,compact and 146 or 172,width-24,math.max(42,bodyH-(compact and 158 or 183)),150)
    txt(extra,"Extra",info.tip,4,0,width-42,150,compact and 20 or 21)
   end
   local rw=(W-80)/3
   btn(m,"InvestFirst","暂看投资",22,footer,rw,72,function() ctx.open("invest") end)
   local b=btn(m,"Reroll",s.rerolls>=s.rerollMax and "重抽已用完" or s.rerollCost==0 and "免费重抽" or "重抽 "..s.rerollCost.." 矿料",40+rw,footer,rw,72,function()
    if s.rerollCost>0 and s.profile.settings.confirmReroll then self.pendingReroll={token=s.supply.token,cost=s.rerollCost};ctx.open("reroll_confirm")
    else ctx.send("reroll",s.supply.token) end
   end);U.enabled(b,s.rerolls<s.rerollMax and s.ore>=s.rerollCost)
   btn(m,"Accept","接收补给",58+rw*2,footer,rw,72,function() ctx.send("supply",{token=s.supply.token,id=selected}) end,true)
  elseif kind=="planner" then
   local limit=s.mode=="tutorial" and C.TutorialWaves or s.overtime and 12 or 10;local intel=Guide.intel(math.min(limit,s.wave+1),C)
   head(s.stage=="mining" and "整备经营台" or "战况情报",s.stage~="mining" and "当前第 "..s.wave.." 波 · "..Guide.intel(s.wave,C).enemies or s.wave>=limit and "本波整备后进入结算 / 撤离决策。" or "第 "..intel.wave.." 波："..intel.enemies,true)
   live={};local body=scroll(m,"PlanningDetails",22,bodyY,W-44,bodyH,530)
   local f=Guide.forecast(s);local rec=Guide.recommend(s,C,R)
   txt(body,"Threat",s.stage=="mining" and intel.tip or Guide.intel(s.wave,C).tip,10,0,W-78,compact and 54 or 67,26,true)
   live.Cargo=txt(body,"Cargo",s.stage~="mining" and "当前为战斗阶段：机器人待命，不产生采矿收入。" or "在途 "..f.cargo.." 矿料 · "..(f.expected>0 and "下一次运回约 "..f.eta.." 秒" or "本阶段已无预计返航").."\n余下整备预计运回约 "..f.expected.." 矿料。",10,compact and 174 or 79,W-78,compact and 68 or 83,24)
   txt(body,"Caution","仅估算返航收入，不含未来投资/增益改变及最后的远程卸载。没有远程卸载科技时，结束前未运回的货物不入账。",10,compact and 252 or 172,W-78,96,22)
   live.Recommendation=txt(body,"Recommendation","建议关注："..C.Upgrades[rec.id].name.."\n"..rec.reason.."\n"..rec.info.detail.." · "..rec.info.reason,10,compact and 60 or 270,W-78,107,24,true)
   if s.waveReport then local r=s.waveReport;txt(body,"WaveReport","上波击杀 "..r.kills.." · 承伤 "..r.taken.."\n主要输出："..C.Catalog.weapons[r.best].name.."（实际有效伤害 "..r.damage.."）",10,391,W-78,98,23) end
   btn(m,"FollowRecommendation","定位建议投资",22,footer,(W-62)/2,72,function() local current=Guide.recommend(self.latest,C,R);ctx.focusUpgrade(current.id);ctx.close() end,true)
   live.Allocation=btn(m,"Allocation","能源："..(s.allocation=="balanced" and "均衡" or s.allocation=="mining" and "采矿优先" or "防御优先").." · 点击切换",40+(W-62)/2,footer,(W-62)/2,72,function() local current=self.latest.allocation;local nextMode=current=="balanced" and "mining" or current=="mining" and "defense" or "balanced";ctx.send("allocate",nextMode) end)
  elseif kind=="decision" then
   head("十波整备完成","现在撤离带回成果，或追加两波争取更多研究与核心。",false)
   Art.sprite(m,"capsule",W/2-52,135,105,172)
   txt(m,"Cargo","结余矿料 "..s.ore.." · 晶体 "..s.runCrystals.." · 核心 "..s.runCores.."\n当前耐久 "..math.ceil(s.hull).." / "..s.maxHull.."；深入后若失败，矿料仅部分保留。",30,compact and 286 or 322,W-60,compact and 110 or 130,24,true)
   btn(m,"Leave","带货撤离",22,footer,(W-62)/2,72,function() ctx.send("decision","leave") end,true)
   btn(m,"Overtime","继续深入 · 追加两波",40+(W-62)/2,footer,(W-62)/2,72,function() ctx.send("decision","continue") end)
  elseif kind=="result" then
   local r=s.result
   head(r.mode=="tutorial" and r.won and "教学远征完成" or r.won and "远征完成，满载归来。" or "前哨失守，下次再来。",s.saveStatus.." · "..(r.mode=="tutorial" and (r.firstClear and "首通材料已领取；教学不兑换矿料。" or "教学练习不发材料。") or "本局奖励已结算。"),false)
   local cardW=(W-74)/4
   for i,d in ipairs({{"合金",r.alloy},{"数据",r.research},{"晶体",r.crystals},{"核心",r.cores}}) do
    local p=U.panel(m,"Reward"..i,22+(i-1)*(cardW+10),120,cardW,100,c.paper)
    txt(p,"Name",d[1],12,5,cardW-24,30,22);txt(p,"Value",tostring(d[2]),12,37,cardW-24,50,35,true)
   end
   local body=scroll(m,"RunSummary",22,235,W-44,H-340,650)
   txt(body,"Stats","击杀 "..r.kills.." · 投资 "..r.purchases.." 次 · 机器人采集 "..r.mined.."\n有效时间 "..math.floor(r.seconds/60).."分"..r.seconds%60 .."秒（不含暂停/选择）",8,0,W-75,71,23)
   local target=Guide.target(s.profile,C,R)
   txt(body,"NextGoal",r.campaignNode and ((r.firstClear and "节点首通，下一关已解锁。" or r.won and "重打奖励已入账。" or "失败收益已按推进进度入账。").."\n回到星球航图选择节点；合金和数据可用于研究，保留现有装备。") or r.firstClear and "首通材料："..r.bonusAlloy.." 合金 + "..r.bonusResearch.." 数据\n"..(s.profile.tech.energy_2 and "已拥有电弧：到工坊换装，再开标准远征。" or "现在可研究电弧蓝图，再到工坊换装试试。") or "下一目标："..target.title.."\n"..target.detail,8,79,W-75,106,24,true)
   txt(body,"SaveStatus",s.saveStatus,8,196,W-75,50,20)
   txt(body,"Debrief",Guide.debrief(s,C,R),8,257,W-75,86,23,true)
   local ledger=r.ledger or {};local t=r.timing or {}
   txt(body,"Ledger","资金记录：击杀回收 "..math.floor(ledger.salvaged or 0).." · 空投 "..(ledger.airdrop or 0).." · 消费 "..math.floor(ledger.spent or 0).."\n未返航货物 "..math.floor(ledger.lostCargo or 0).."（不计收入）",8,353,W-75,75,22)
   txt(body,"SettlementRule",Guide.settlement(s,C,R),8,438,W-75,82,22)
   txt(body,"TimeBreakdown","战斗 "..math.floor((t.combat or 0)+(t.clearing or 0)).."s · 采矿 "..math.floor(t.mining or 0).."s\n另有补给选择 "..math.floor(t.supply or 0).."s · 暂停 "..math.floor(t.pause or 0).."s",8,535,W-75,82,22)
   local bw=(W-86)/4
   btn(m,"ResultResearch","研究",22,footer,bw,72,function() self.tech=s.profile.targetResearch~="" and s.profile.targetResearch or "energy_2";self.branch=C.Tech.nodes[self.tech].column;ctx.open("research") end,true)
   btn(m,"ResultWorkshop","换装",36+bw,footer,bw,72,function() self.weapon=s.profile.tech.energy_2 and "arc" or s.loadout;ctx.open("workshop") end)
   btn(m,"Again",r.campaignNode and "星球航图" or r.mode=="tutorial" and not r.won and "重试三波教学" or "再开标准远征",50+bw*2,footer,bw,72,function() if r.campaignNode then self.mission=math.min(24,s.profile.campaignCleared+1);ctx.open("campaign") else ctx.open(nil);ctx.send("start",r.mode=="tutorial" and not r.won and "tutorial" or "standard") end end,true)
   btn(m,"Menu","主菜单",64+bw*3,footer,bw,72,function() ctx.open(nil);ctx.send("menu") end)
  end
 end
 function self.update(s)
  self.latest=s
  if not live then return end
  local function put(o,text) if o and o.Text~=text then o.Text=text end end
  if live.Performance then put(live.Performance,ctx.performance and ctx.performance() or "") end
  if not live.Cargo then return end
  local f=s.forecast or Guide.forecast(s);local rec=s.recommendation or Guide.recommend(s,C,R)
  put(live.Cargo,s.stage~="mining" and "当前为战斗阶段：机器人待命，不产生采矿收入。" or "在途 "..f.cargo.." 矿料 · "..(f.expected>0 and "下一次运回约 "..f.eta.." 秒" or "本阶段已无预计返航").."\n余下整备预计运回约 "..f.expected.." 矿料。")
  put(live.Recommendation,"建议关注："..C.Upgrades[rec.id].name.."\n"..rec.reason.."\n"..rec.info.detail.." · "..rec.info.reason)
  put(live.Allocation,"能源："..(s.allocation=="balanced" and "均衡" or s.allocation=="mining" and "采矿优先" or "防御优先").." · 点击切换")
 end
 return self
end
return P
