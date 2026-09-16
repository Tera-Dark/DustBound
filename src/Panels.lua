-- Adaptive native panels: compact screens use branch/list/detail views, never a shrunken six-column tree.
local P={}
function P.new(ctx)
 local U,C,R,Guide,Art=ctx.U,ctx.C,ctx.R,ctx.Guide,ctx.Art;local c=U.colors
 local self={revision=0,tech="energy_2",branch=4,category="weapons",entry="cannon",query="",weapon="machine",scrolls={}}
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
  if self.lastKind==kind and self.compact==compact then
   for _,o in ipairs(m:GetChildren()) do if o:IsA("ScrollingFrame") then self.scrolls[o.Name]=o.CanvasPosition end end
  else self.scrolls={} end
  self.lastKind=kind;self.compact=compact;U.clear(m)
  local function head(title,sub,close)
   txt(m,"Title",title,22,10,W-120,46,compact and 30 or 36,true)
   txt(m,"Description",sub,24,57,W-135,47,compact and 21 or 19)
   if close then btn(m,"Close","×",W-86,12,72,66,ctx.close) end
  end
  local bodyY=116;local bodyH=H-206;local footer=H-80
  if kind=="research" then
   head("研究中心 / 科技目标",wallet(s.profile),true)
   local left=compact and 302 or 884;local dx=left+40;local dw=W-dx-22
   if compact then
    btn(m,"PreviousBranch","‹",20,114,72,66,function() self.branch=(self.branch+4)%6+1;dirty() end)
    txt(m,"BranchName",C.Tech.branches[self.branch].name,93,118,149,58,24,true)
    btn(m,"NextBranch","›",252,114,72,66,function() self.branch=self.branch%6+1;dirty() end)
    local list=scroll(m,"TechTree",20,194,left,bodyH-78,8*80)
    local branch=C.Tech.branches[self.branch].id
    for tier=1,8 do
     local id=branch.."_"..tier;local n=C.Tech.nodes[id];local state=R.techState(s.profile,id,C)
     local b=btn(list,"Tech_"..id,n.name.."\n"..(state=="owned" and "已完成" or state=="ready" and "可研究" or state=="poor" and "资源不足" or "前置未满足"),4,4+(tier-1)*80,left-17,70,function() self.tech=id;dirty() end,self.tech==id)
     b.TextSize=22;if state=="owned" then b.BackgroundColor3=c.mint end
    end
   else
    local tree=scroll(m,"TechTree",20,156,left,bodyH-40,930)
    for _,b in ipairs(C.Tech.branches) do txt(m,"Branch_"..b.id,b.name,25+(b.column-1)*146,114,138,34,19,true) end
    for _,id in ipairs(C.Tech.order) do
     local n=C.Tech.nodes[id];local state=R.techState(s.profile,id,C);local x=5+(n.column-1)*146;local y=5+(n.tier-1)*114
     if n.tier>1 and #n.prereqs>0 then U.frame(tree,"Link",x+66,y-28,4,30,c.muted) end
     local b=btn(tree,"Tech_"..id,n.name.."\n"..(state=="owned" and "已完成" or state=="ready" and "可研究" or state=="poor" and "资源不足" or "前置未满足"),x,y,135,85,function() self.tech=id;self.branch=n.column;dirty() end,state=="ready")
     b.TextSize=19;if state=="owned" then b.BackgroundColor3=c.mint end;if id==self.tech then U.frame(b,"Selected",0,0,5,85,c.ink) end
    end
   end
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
     self.tech=pre;self.branch=C.Tech.nodes[pre].column;self.scrolls.TechTree=Vector2.new(0,math.max(0,(C.Tech.nodes[pre].tier-2)*(compact and 80 or 114)));dirty()
    end)
   end
   if #n.prereqs==0 then txt(detail,"NoPrereq","无需前置研究",7,y,dw-25,36,21) end
   txt(detail,"TechStatus",msg,7,y+math.max(1,#n.prereqs)*76,dw-25,44,21,true)
   btn(m,"TrackedTarget",s.profile.targetResearch==n.id and "取消追踪" or "固定研究目标",22,footer,(W-64)*.42,72,function() ctx.send("target",s.profile.targetResearch==n.id and "" or n.id) end)
   local b=btn(m,"ResearchNode",state=="owned" and "已完成研究" or "确认研究",44+(W-64)*.42,footer,(W-64)*.58,72,function() ctx.send("research",n.id) end,true);U.enabled(b,state=="ready" and (s.phase=="menu" or s.phase=="ended"))
  elseif kind=="workshop" then
   head("武器工坊 / 配装", "固定主炮 + 一件副武器；研究解锁后免费换装。",true)
   local left=compact and 290 or 350
   local list=scroll(m,"WeaponList",20,bodyY,left,bodyH,5*84)
   for i,id in ipairs({"machine","arc","rail","flame","mortar"}) do local d=C.Catalog.weapons[id]
    btn(list,"Weapon_"..id,d.name..(s.loadout==id and " · 已装备" or not R.unlocked(s.profile,d) and " · 未解锁" or ""),4,4+(i-1)*84,left-17,72,function() self.weapon=id;dirty() end,self.weapon==id)
   end
   local id=self.weapon;local d=C.Catalog.weapons[id];local x=left+44;local w=W-x-23
   local detail=scroll(m,"WeaponDetail",x,bodyY,w,bodyH,440)
   txt(detail,"WeaponName",d.name,6,0,w-20,46,30,true)
   txt(detail,"WeaponStats","间隔 "..d.interval.." 秒 · 系数 ×"..d.multiplier.."\n"..d.desc,6,55,w-22,118,23)
   txt(detail,"WeaponGate",d.tech and "需要："..C.Tech.nodes[d.tech].name or "初始解锁",6,181,w-22,40,21)
   if d.tech and not R.unlocked(s.profile,d) then btn(detail,"GoUnlock","定位解锁研究",6,234,w-23,66,function() self.tech=d.tech;self.branch=C.Tech.nodes[d.tech].column;ctx.open("research") end) end
   local can=R.unlocked(s.profile,d)
   local equip=btn(m,"Equip_"..id,s.loadout==id and "已装备" or can and "装备副武器" or "尚未解锁",22,footer,(W-72)/3,72,function() ctx.send("loadout",id) end,true);U.enabled(equip,can and s.loadout~=id)
   btn(m,"SavePreset","保存预设 1",36+(W-72)/3,footer,(W-72)/3,72,function() ctx.send("preset",{slot=1,mode="save"}) end)
   btn(m,"UsePreset","应用预设 1",50+(W-72)*2/3,footer,(W-72)/3,72,function() ctx.send("preset",{slot=1,mode="equip"}) end)
  elseif kind=="codex" then
   head("远征档案 / 图鉴","基础参数、使用说明和累计记录；输入名称可筛选。",true)
   local left=compact and 300 or 354
   for i,g in ipairs({{"weapons","武器"},{"supplies","补给"},{"enemies","怪物"}}) do
    btn(m,"Codex_"..g[1],g[2],20+(i-1)*(left/3),112,left/3-7,66,function() self.category=g[1];self.entry=C.Catalog.order[g[1]][1];self.query="";dirty() end,self.category==g[1])
   end
   search(m,"CodexSearch",20,188,left-7,"名称 / 回车筛选",self.query,function(q) self.query=q end)
   local list=scroll(m,"CodexList",20,261,left,H-279,7*78);local i=0
   for _,id in ipairs(C.Catalog.order[self.category]) do local d=C.Catalog[self.category][id]
    if self.query=="" or string.find(d.name,self.query,1,true) then
     btn(list,"Entry_"..id,d.name,4,4+i*78,left-17,66,function() self.entry=id;dirty() end,self.entry==id);i=i+1
    end
   end
   if i==0 then txt(list,"Empty","没有匹配的条目",8,9,left-25,55,23) end
   local d=C.Catalog[self.category][self.entry];local x=left+44;local w=W-x-23;local body=scroll(m,"CodexInspector",x,bodyY,w,H-bodyY-18,620)
   txt(body,"EntryTitle",d.name,8,0,w-25,48,30,true)
   local count=s.profile.codex[self.category][self.entry] or 0
   txt(body,"Record","累计 "..count..(self.category=="weapons" and " 次发射" or self.category=="enemies" and " 次击杀" or " 次接收"),8,54,w-25,36,22)
   txt(body,"Description",d.desc,8,105,w-25,94,24)
   local stats=self.category=="weapons" and "伤害系数 ×"..d.multiplier.." / 间隔 "..d.interval.." 秒 / 射程 "..d.range or self.category=="enemies" and "首次出现第 "..d.firstWave.." 波\n耐久 "..d.hp.." + 波次 ×"..d.hpWave.."\n回收 "..d.reward.." 矿料 / 攻击间隔 "..d.interval.." 秒" or d.detail
   txt(body,"Stats",stats,8,210,w-25,116,23,true)
   txt(body,"Tip",d.tip or "补给三选一；采矿 Buff 仅在整备计时，战斗 Buff 仅在战斗计时。",8,340,w-25,108,22)
   if d.tech then btn(body,"LocateTech","定位解锁研究",8,467,w-25,66,function() self.tech=d.tech;self.branch=C.Tech.nodes[d.tech].column;ctx.open("research") end) end
  elseif kind=="settings" then
   head("设置 / 运行状态","偏好随档案保存；关闭设置不会自动恢复远征。",true)
   local col=(W-62)/2;local cfg=s.profile.settings
   btn(m,"Motion",cfg.reducedMotion and "轻量动效：开启" or "轻量动效：关闭",22,118,col,68,function() ctx.send("settings",{key="reducedMotion",value=not cfg.reducedMotion}) end,true)
   btn(m,"DamageNumbers",cfg.damageNumbers and "伤害数字：显示" or "伤害数字：隐藏",40+col,118,col,68,function() ctx.send("settings",{key="damageNumbers",value=not cfg.damageNumbers}) end)
   for i,d in ipairs({{"sfx","音效"},{"music","音乐"}}) do
    local x=22+(i-1)*(col+18);local key=d[1]
    btn(m,"Less_"..key,"−",x,205,70,68,function() ctx.send("settings",{key=key,value=cfg[key]-.2}) end)
    txt(m,"Volume_"..key,d[2].." "..math.floor(cfg[key]*100).."%",x+80,211,col-160,53,25,true)
    btn(m,"More_"..key,"+",x+col-70,205,70,68,function() ctx.send("settings",{key=key,value=cfg[key]+.2}) end)
   end
   local info=scroll(m,"SettingsDetails",22,293,W-44,H-385,380)
   txt(info,"ArtMode","图像："..Art.detail.."\n声音："..ctx.audio.mode..(C.SoundIds.music and "" or " / 音乐未配置"),7,0,W-78,73,21)
   txt(info,"Storage","存档："..(s.saveStatus or "本地会话"),7,80,W-78,70,21)
   txt(info,"Metrics","分析："..s.telemetry.status.." · 本地已记录 "..s.telemetry.total.." 事件",7,157,W-78,65,21)
   txt(info,"ModeHelp","内置提示音无需上传；完整原创音效需按随包说明上传。\n正式云存档/API 与手机体验仍需发布与真机核验。",7,231,W-78,100,21)
   btn(m,"RetrySave","重试保存 / 读取",22,footer,(W-62)/2,72,function() ctx.send("save_retry") end)
   btn(m,"TestSound","试听反馈音",40+(W-62)/2,footer,(W-62)/2,72,function() ctx.audio.play("upgrade") end,true)
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
   local width=(W-68)/3;local selected=ctx.selectedSupply() or s.supply.options[1]
   for i,id in ipairs(s.supply.options) do local d=C.Catalog.supplies[id]
    local b=btn(m,"Choice_"..id,"",22+(i-1)*(width+12),bodyY,width,bodyH,function() ctx.selectSupply(id);dirty() end,id==selected)
    txt(b,"Name",d.name,12,12,width-24,43,27,true)
    txt(b,"Detail",d.detail,12,67,width-24,95,24)
    txt(b,"Extra",d.desc,12,172,width-24,math.max(42,bodyH-183),21)
   end
   local rw=(W-80)/3
   btn(m,"InvestFirst","暂看投资",22,footer,rw,72,function() ctx.open("invest") end)
   local b=btn(m,"Reroll",s.rerolls>=s.rerollMax and "重抽已用完" or s.rerollCost==0 and "免费重抽" or "重抽 "..s.rerollCost.." 矿料",40+rw,footer,rw,72,function() ctx.send("reroll",s.supply.token) end);U.enabled(b,s.rerolls<s.rerollMax and s.ore>=s.rerollCost)
   btn(m,"Accept","接收补给",58+rw*2,footer,rw,72,function() ctx.send("supply",{token=s.supply.token,id=selected}) end,true)
  elseif kind=="planner" then
   local limit=s.mode=="tutorial" and C.TutorialWaves or s.overtime and 12 or 10;local intel=Guide.intel(math.min(limit,s.wave+1),C)
   head("整备经营台",s.wave>=limit and "本波整备后进入结算 / 撤离决策。" or "第 "..intel.wave.." 波："..intel.enemies,true)
   local body=scroll(m,"PlanningDetails",22,bodyY,W-44,bodyH,530)
   local f=Guide.forecast(s);local rec=Guide.recommend(s,C,R)
   txt(body,"Threat",intel.tip,10,0,W-78,compact and 54 or 67,26,true)
   txt(body,"Cargo","在途 "..f.cargo.." 矿料 · 下一次运回约 "..f.eta.." 秒\n按当前配置估算，余下整备可运回约 "..f.expected.." 矿料。",10,compact and 174 or 79,W-78,compact and 68 or 83,24)
   txt(body,"Caution","仅估算返航收入，不含未来投资/增益改变及最后的远程卸载。没有远程卸载科技时，结束前未运回的货物不入账。",10,compact and 252 or 172,W-78,96,22)
   txt(body,"Recommendation","建议关注："..C.Upgrades[rec.id].name.."\n"..rec.reason.."\n"..rec.info.detail.." · "..rec.info.reason,10,compact and 60 or 270,W-78,107,24,true)
   if s.waveReport then local r=s.waveReport;txt(body,"WaveReport","上波击杀 "..r.kills.." · 承伤 "..r.taken.."\n主要输出："..C.Catalog.weapons[r.best].name.."（实际有效伤害 "..r.damage.."）",10,391,W-78,98,23) end
   btn(m,"FollowRecommendation","定位建议投资",22,footer,(W-62)/2,72,function() ctx.focusUpgrade(rec.id);ctx.close() end,true)
   btn(m,"Allocation","能源："..(s.allocation=="balanced" and "均衡" or s.allocation=="mining" and "采矿优先" or "防御优先").." · 点击切换",40+(W-62)/2,footer,(W-62)/2,72,function() local nextMode=s.allocation=="balanced" and "mining" or s.allocation=="mining" and "defense" or "balanced";ctx.send("allocate",nextMode) end)
  elseif kind=="decision" then
   head("十波整备完成","现在撤离带回成果，或追加两波争取更多研究与核心。",false)
   Art.sprite(m,"capsule",W/2-52,135,105,172)
   txt(m,"Cargo","可带回矿料 "..s.ore.." · 晶体 "..s.runCrystals.." · 核心 "..s.runCores,30,322,W-60,54,25,true)
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
   local body=scroll(m,"RunSummary",22,235,W-44,H-340,280)
   txt(body,"Stats","击杀 "..r.kills.." · 投资 "..r.purchases.." 次 · 机器人采集 "..r.mined.."\n有效时间 "..math.floor(r.seconds/60).."分"..r.seconds%60 .."秒（不含暂停/选择）",8,0,W-75,71,23)
   local target=Guide.target(s.profile,C,R)
   txt(body,"NextGoal",r.firstClear and "首通材料："..r.bonusAlloy.." 合金 + "..r.bonusResearch.." 数据\n"..(s.profile.tech.energy_2 and "已拥有电弧：到工坊换装，再开标准远征。" or "现在可研究电弧蓝图，再到工坊换装试试。") or "下一目标："..target.title.."\n"..target.detail,8,79,W-75,106,24,true)
   txt(body,"SaveStatus",s.saveStatus,8,196,W-75,50,20)
   local bw=(W-86)/4
   btn(m,"ResultResearch","研究",22,footer,bw,72,function() self.tech=s.profile.targetResearch~="" and s.profile.targetResearch or "energy_2";self.branch=C.Tech.nodes[self.tech].column;ctx.open("research") end,true)
   btn(m,"ResultWorkshop","换装",36+bw,footer,bw,72,function() self.weapon=s.profile.tech.energy_2 and "arc" or s.loadout;ctx.open("workshop") end)
   btn(m,"Again","再开标准远征",50+bw*2,footer,bw,72,function() ctx.open(nil);ctx.send("start","standard") end,true)
   btn(m,"Menu","主菜单",64+bw*3,footer,bw,72,function() ctx.open(nil);ctx.send("menu") end)
  end
 end
 return self
end
return P
