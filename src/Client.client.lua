-- DUSTBOUND 0.7: centered 2D battlefield; free drafts; three-currency research.
local pg=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
pg:SetAttribute("FrontierGameReady",false)
local function fail(e) pg:SetAttribute("FrontierClientError",tostring(e));pg:SetAttribute("FrontierClientPhase","ERROR");warn(e) end
local function launch()
 local RS=game:GetService("ReplicatedStorage");local Run=game:GetService("RunService");local Input=game:GetService("UserInputService")
 local shared=RS:WaitForChild("FrontierShared",12);assert(shared,"共享模块未就绪")
 local function module(n) return require(shared:WaitForChild(n,10)) end
 local C=module("Runtime");local R=module("Rules");local U=module("UI");local Art=module("Art");local B=module("BattleView");local F=module("Frontier")
 pg:SetAttribute("FrontierClientPhase","LOADING_CARTOON_ART")
 Art.init(function(f) pg:SetAttribute("FrontierLoadProgress",.1+.65*f) end,function() Run.Heartbeat:Wait() end)
 Art.yieldFrame=function() Run.Heartbeat:Wait() end
 local audio=module("Audio").new(C);local c=U.colors
 local gui=Instance.new("ScreenGui");gui.Name="DustboundHUD";gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
 local canvas=U.frame(gui,"Canvas",0,0,1440,810,c.shadow,0);canvas.Size=UDim2.fromScale(1,1)
 local root=U.frame(canvas,"Stage",0,0,1440,810,nil,1);root.AnchorPoint=Vector2.new(.5,.5);root.Position=UDim2.fromScale(.5,.5)
 local scale=Instance.new("UIScale");scale.Parent=root
 Art.sprite(root,"background",0,0,1440,810)
 local battle=B.new({C=C,U=U,Art=Art},root)
 local top=U.panel(root,"StatusBar",30,20,1380,80,c.cream)
 local status=U.text(top,"Status","连接前哨…",20,5,1000,60,24,c.ink,true)
 status.Visible=false;local readouts=F.header(U,top)
 local note=U.text(root,"Notice","",40,105,1360,32,16,c.ink,false)
 local hud=U.frame(root,"Actions",30,717,1380,70,nil,1)
 local body=U.frame(root,"Pages",30,150,1380,544,nil,1)
 local overlay=U.frame(root,"ModalLayer",0,0,1440,810,nil,1);overlay.Visible=false
 local net=RS:WaitForChild("FrontierNetwork",12);local action=net:WaitForChild("Action",10)
 local snap=nil;local view=nil;local selected=1;local tech=C.Tech.order[1];local dirty=true;local lastKey="";local serial=0;local pending=0;local wait=0;local age=0
 local codexPage=1;local rerollToken=nil;local shopButtons={};local recallToken=nil;local recallText=nil;local painted=false;local readySent=false;local uiClock=0;local transient="";local transientUntil=0
 local function send(kind,data)
  if kind=="ready" or kind=="ui_ready" then action:FireServer(kind,data);return end
  if pending>0 then return end
  serial=serial+1;pending=serial;wait=0;action:FireServer(kind,data,serial)
 end
 local function open(v) if v=="confirm_recall" then recallToken=snap.prepare and snap.prepare.token end;view=v;dirty=true end
 local function button(p,name,text,x,y,w,h,fn,accent) return U.button(p,name,text,x,y,w,h,fn,accent) end
 local function close() if snap and snap.paused then send("pause",false) end;open(nil) end
 button(top,"Settings","设置",1160,16,100,48,function() if snap and snap.phase=="running" then send("pause",true) end;open("settings") end)
 local pauseButton=button(top,"Pause","暂停",1270,16,95,48,function() if snap and snap.phase=="running" then send("pause",not snap.paused) end end)
 local function text(p,name,value,x,y,w,h,size,bold) return U.text(p,name,value,x,y,w,h,size or 22,c.ink,bold) end
 local function resource(p) return "合金 "..p.alloy.."   /   数据 "..p.research.."   /   核心 "..p.cores end
 local function research(parent)
  text(parent,"Title","研究网络",20,0,340,45,32,true)
  text(parent,"Legend","绿色：已完成 · 橙色：可研究 · 分叉前置任选其一 · 跨区捷径在右侧查看",20,42,1020,34,17)
  local tree=U.scroll(parent,"ResearchNetwork",12,85,1020,442,1150*.57)
  tree.CanvasSize=UDim2.fromOffset(1920*.57,1150*.57);tree.ScrollingDirection=Enum.ScrollingDirection.XY
  local z=.57
  for _,id in ipairs(C.Tech.order) do for _,edge in ipairs(C.ResearchWeb.edges(C.Tech,id)) do if not edge.portal then
   for i=1,#edge.points-1 do local a,b=edge.points[i],edge.points[i+1];local dx,dy=b[1]-a[1],b[2]-a[2]
    local line=U.frame(tree,"Link_"..edge.from.."_"..id,(a[1]+b[1])*z/2,(a[2]+b[2])*z/2,math.sqrt(dx*dx+dy*dy)*z,3,snap.profile.tech[edge.from] and c.mint or c.muted)
    line.AnchorPoint=Vector2.new(.5,.5);line.Rotation=math.deg(math.atan2(dy,dx))
   end
  end end end
  for _,id in ipairs(C.Tech.order) do local n=C.Tech.nodes[id];local state=R.techState(snap.profile,id,C)
   local b=button(tree,"Tech_"..id,n.name,(n.mapX-64)*z,(n.mapY-44)*z,128*z,88*z,function() tech=id;dirty=true end,state=="ready")
   b.TextSize=14;b.BackgroundColor3=state=="owned" and c.mint or id==tech and c.gold or state=="locked" and c.paper or state=="ready" and c.orange or c.cream
  end
  local n=C.Tech.nodes[tech];local state,msg=R.techState(snap.profile,tech,C)
  local panel=U.panel(parent,"ResearchInspector",1050,0,318,535,c.cream)
  text(panel,"Name",n.name,18,12,282,54,26,true)
  text(panel,"Description",n.detail or n.desc or "",18,68,282,92,21)
  text(panel,"Cost",resource(n.cost).."\n"..msg,18,163,282,76,18)
  local buy=button(panel,"Research","研究 · 下次出发生效",18,246,282,52,function() send("research",tech) end,true);U.enabled(buy,state=="ready")
  local pres={};for _,id in ipairs(n.prereqs) do pres[#pres+1]=id end;for _,id in ipairs(n.anyPrereqs) do pres[#pres+1]=id end
  text(panel,"Prerequisites",#n.anyPrereqs>0 and "任选一个入口（点击定位）" or "前置研究（点击定位）",18,310,282,30,17)
  for i,id in ipairs(pres) do button(panel,"Go_"..id,C.Tech.nodes[id].name,18,347+(i-1)*39,282,34,function() tech=id;dirty=true end).TextSize=17 end
  if state=="owned" and n.kind=="ultimate" then button(panel,"RefundTalent","重置终极天赋 · 全额退还",18,479,282,42,function() send("refund_talent",tech) end).TextSize=16 end
 end
 local function draw()
  if not snap then return end
  shopButtons={};U.clear(body);U.clear(hud);U.clear(overlay);overlay.Visible=false
  local running=snap.phase=="running"
  if running then
   F.battleHud({U=U,C=C,Art=Art},hud,snap,view,open,send)
  elseif snap.phase=="menu" then
   F.menu({U=U,C=C,Art=Art},body,hud,snap,view,selected,open,function(id) selected=id;dirty=true end,function(kind,data) view=nil;send(kind,data) end)
   if view=="research" then
    local background=U.panel(body,"ResearchBackdrop",0,-8,1380,554,c.cream)
    research(background)
   end
  end
  local offer=snap.supply
  local modalView=(snap.storage and snap.storage.blocked) and "storage" or (snap.paused and (view=="settings" and "settings" or view=="confirm_abandon" and view or "pause")) or (view=="confirm_reroll" and offer and "confirm_reroll") or offer and "offer" or snap.phase=="ended" and "result" or view
  if modalView=="research" or modalView=="campaign" or not modalView then return end
  overlay.Visible=true
  local shade=U.frame(overlay,"Backdrop",0,0,1440,810,c.shadow,.18);shade.Active=true
  local panel=U.panel(overlay,"Dialog",140,154,1160,508,c.cream)
  if modalView=="storage" then
   text(panel,"Title","云档未就绪 / 已阻止写入",28,20,1080,65,30,true)
   text(panel,"StorageError",snap.saveStatus or "请检查连接后重试",28,110,1080,95,23)
   if snap.storage.mode=="read_error" then
    button(panel,"RetryLoad","重试读取",28,260,510,70,function() send("save_retry") end,true)
    button(panel,"Guest","确认访客试玩（不保存）",570,260,560,70,function() send("guest","confirm") end)
   else text(panel,"Rejoin","存档锁失效，请退出并重新加入，避免覆盖其他会话。",28,260,1080,100,24) end
  elseif modalView=="confirm_reroll" then
   text(panel,"Title","确认付费重抽",28,20,1080,65,30,true)
   text(panel,"Cost","本次消耗 "..snap.rerollCost.." 金矿；武器与遗物选择本身仍免费。",28,120,1080,110,25)
   button(panel,"ConfirmReroll","确认重抽",28,300,510,75,function() local token=rerollToken;view=nil;dirty=true;if snap.supply and snap.supply.token==token then send("reroll",token) end end,true)
   button(panel,"CancelReroll","取消",570,300,560,75,function() open(nil) end)
  elseif modalView=="offer" then
   text(panel,"Title",offer.kind=="weapon" and "免费武器三选一 · 安装到下一副位" or "免费遗物三选一 · 持续本次远征",28,12,1060,60,30,true)
   for i,id in ipairs(offer.options) do local d=offer.kind=="weapon" and C.Catalog.weapons[id] or C.RunSystems.relics[id]
    local card=U.panel(panel,"Choice"..i,28+(i-1)*377,92,350,302,c.paper)
    Art.sprite(card,offer.kind=="relic" and "crystal" or id=="arc" and "crystal" or id=="flame" and "drillBit" or "turret",135,14,80,64)
    text(card,"Name",d.name,18,83,314,45,26,true);text(card,"Detail",d.detail or d.tip or d.desc or "独立攻击的副武器",18,134,314,77,19)
    button(card,"Choose_"..id,"免费选择",18,225,314,58,function() send("supply",{token=offer.token,id=id}) end,true)
   end
   button(panel,"Reroll","重抽 · "..snap.rerollCost.." 金矿",28,422,360,56,function() if snap.rerollCost>0 and snap.profile.settings.confirmReroll then rerollToken=offer.token;open("confirm_reroll") else send("reroll",offer.token) end end).Active=snap.rerolls<snap.rerollMax and snap.ore>=snap.rerollCost
   text(panel,"OfferNote","下波："..(snap.nextEncounter and snap.nextEncounter.name or "—").." · 选择免费，期间暂停采矿。",420,422,710,56,21)
  elseif modalView=="confirm_recall" and snap.prepare then
   text(panel,"Title","提前收队 / 用矿量换取更快推进",28,12,1080,60,30,true)
   text(panel,"NextWave","下一波："..snap.nextEncounter.name.."\n"..snap.nextEncounter.tip,28,80,1080,100,22)
   recallText=text(panel,"RecallQuote","",28,192,1080,120,25,true)
   text(panel,"RecallNote","按当前机器人配置估算；面板不会暂停采矿。确认时以服务器状态为准。",28,334,1080,48,18)
   button(panel,"CancelRecall","继续采矿",28,416,510,64,close)
   button(panel,"ConfirmRecall","确认收队 →",570,416,560,64,function() local token=recallToken;open(nil);send("recall",{token=token}) end,true)
  elseif modalView=="mining" or modalView=="combat" then
   text(panel,"Title",modalView=="mining" and "机器人投资 / 金矿只来自采矿" or "战斗投资 / 本次远征有效",28,12,1040,60,30,true)
   local ids=modalView=="mining" and {"move","dig","cargo","robots"} or {"damage","rate","barrel","armor","repair","regen"}
   for i,id in ipairs(ids) do local d=C.Upgrades[id];local level=snap.upgrades[id] or 0;local price=snap.prices[id]
    local b=button(panel,"Buy_"..id,"",28+(i-1)%3*377,102+math.floor((i-1)/3)*132,350,110,function() send("buy",id) end,true)
    shopButtons[id]=b;b.TextSize=18;U.enabled(b,snap.investments[id].canBuy)
   end
   button(panel,"Close","返回战场",830,430,300,54,close)
  elseif modalView=="settings" then
   text(panel,"Title","设置 / "..tostring(snap.saveStatus or "本地试玩存档"),28,12,1070,58,27,true)
   local settings={{"reducedMotion","轻量动效"},{"enemyHealth","敌人血条"},{"flashEffects","闪光效果"},{"masterMuted","全部静音"},{"autoPause","离开窗口暂停"},{"hotkeys","快捷键"}}
   for i,d in ipairs(settings) do button(panel,"Setting_"..d[1],d[2].."："..(snap.profile.settings[d[1]] and "开" or "关"),28+(i-1)%3*377,90+math.floor((i-1)/3)*88,350,66,function() send("settings",{key=d[1],value=not snap.profile.settings[d[1]]}) end) end
   for i,key in ipairs({"sfx","music"}) do local x=28+(i-1)*550
    text(panel,"Volume_"..key,(key=="sfx" and "音效 " or "音乐 ")..math.floor(snap.profile.settings[key]*100).."%",x,270,230,55,23)
    button(panel,"Less_"..key,"−",x+245,270,95,55,function() send("settings",{key=key,value=math.max(0,snap.profile.settings[key]-.1)}) end)
    button(panel,"More_"..key,"+",x+355,270,95,55,function() send("settings",{key=key,value=math.min(1,snap.profile.settings[key]+.1)}) end)
   end
   text(panel,"Storage",snap.saveStatus or "本地试玩 · 不保存",28,338,1080,65,21)
   if snap.storage and snap.storage.mode=="save_error" then button(panel,"RetrySave","重试保存",28,430,350,54,function() send("save_retry") end) end
   button(panel,"Close","返回",830,430,300,54,close)
  elseif modalView=="result" then
   local r=snap.result;text(panel,"Title",r.won and "前哨守住了！" or "远征结束",28,24,1000,72,38,true)
   text(panel,"Reward",resource(r),28,128,1060,72,32,true)
   text(panel,"Summary","完成波次 "..(r.won and r.wave or math.max(0,r.wave-1)).." / "..snap.mission.waves.." · 机器人采金 "..r.mined.."\n首次通关材料较多，重玩与有效战斗失败也有材料收入。",28,213,1060,66,21)
   if r.recap then
    local totals={};for _,id in ipairs(C.Catalog.order.weapons) do if r.recap.weaponDamage[id] then totals[#totals+1]=C.Catalog.weapons[id].name.." "..math.floor(r.recap.weaponDamage[id]) end end
    text(panel,"WeaponDamage","火力贡献 / "..table.concat(totals," · "),28,284,1080,48,18)
    text(panel,"WorstWave",r.recap.worstWave>0 and "最高承伤：第 "..r.recap.worstWave.." 波 · "..math.floor(r.recap.worstTaken).." 点" or "全局未承伤",28,337,1080,32,20,true)
    text(panel,"RecapTip",r.recap.tip,28,374,690,100,19)
   end
   button(panel,"ReturnMenu","返回前哨",750,405,380,66,function() view=nil;selected=math.min(24,snap.profile.campaignCleared+1);send("menu") end,true)
  elseif modalView=="codex" then
   text(panel,"Title","远征图鉴 / 武器、虫群与整局遗物",28,12,1080,60,30,true)
   local list=U.scroll(panel,"CodexCards",28,90,1100,325,456);local i=0;local entry=0
   for _,group in ipairs({"weapons","enemies","supplies"}) do
    for _,id in ipairs(C.Catalog.order[group]) do local d=C.Catalog[group][id];entry=entry+1
     if entry>(codexPage-1)*6 and entry<=codexPage*6 then
     local card=U.panel(list,"Codex_"..id,(i%3)*364,math.floor(i/3)*228,345,208,c.paper)
     local sprite=group=="weapons" and (id=="arc" and "crystal" or id=="flame" and "drillBit" or "turret") or group=="supplies" and "crystal" or id=="flyer" and "flyerBody" or id=="tank" and "tankBody" or "crawlerBody"
     Art.sprite(card,sprite,12,12,54,54)
     text(card,"Name",d.name,80,12,250,52,23,true)
     text(card,"Description",d.detail or d.desc,16,78,310,113,18)
     i=i+1
     end
    end
   end
   button(panel,"CodexPrev","上一页",28,430,240,54,function() codexPage=math.max(1,codexPage-1);dirty=true end)
   button(panel,"CodexNext","下一页 "..codexPage.." / "..math.ceil(entry/6),288,430,330,54,function() codexPage=math.min(math.ceil(entry/6),codexPage+1);dirty=true end)
   list.CanvasSize=UDim2.fromOffset(0,math.ceil(i/3)*228)
   button(panel,"Close","返回",830,430,300,54,close)
  elseif modalView=="relics" then
   text(panel,"Title","已获得的整局遗物",28,12,1050,60,30,true)
   local list=U.scroll(panel,"OwnedRelics",28,90,1100,310,650);local i=0
   for _,id in ipairs(C.RunSystems.relicOrder) do if snap.relics[id] then local d=C.RunSystems.relics[id];text(list,id,d.name.." / "..d.detail,0,i*60,1080,55,23);i=i+1 end end
   button(panel,"Close","返回",830,430,300,54,close)
  else
   text(panel,"Paused","已暂停",28,30,1000,80,38,true)
   button(panel,"Resume","继续远征",28,170,510,85,close,true)
   button(panel,"Abandon","放弃本局（无结算奖励）",570,170,560,85,function() open("confirm_abandon") end)
   if modalView=="confirm_abandon" then button(panel,"ConfirmAbandon","确认放弃并返回前哨",28,300,1102,80,function() view=nil;send("abandon","confirm") end,true) end
  end
 end
 net.State.OnClientEvent:Connect(function(s)
  local ok,e=xpcall(function()
   if not snap then selected=math.min(24,s.profile.campaignCleared+1) end
   if not snap or s.runId~=snap.runId or s.phase~=snap.phase then dirty=true;view=nil end
   snap=s;age=0
   if view=="confirm_recall" and (s.stage~="mining" or s.prepare and s.prepare.recalling) then view=nil;dirty=true end
   if pending>0 and (s.ack or 0)>=pending then
    pending=0;if s.actionResult and s.actionResult~="" then transient=s.actionResult;transientUntil=os.clock()+4 end
   end
   battle.sync(s);audio.settings(s.profile.settings)
   local owned=0;for _ in pairs(s.profile.tech) do owned=owned+1 end
   local key=s.phase..s.stage..tostring(s.targetMode)..tostring(s.prepare and s.prepare.recalling)..tostring(s.paused)..tostring(s.supply and s.supply.token)..s.purchases..(s.phase~="running" and resource(s.profile) or "")..owned..tostring(s.storage and s.storage.mode)..tostring(s.storage and s.storage.blocked)..R.settingKey(s.profile.settings)
   if key~=lastKey then dirty=true;lastKey=key end
   
  end,debug.traceback);if not ok then fail(e) end
 end)
 net.FX.OnClientEvent:Connect(function(events) local ok,e=xpcall(function() battle.events(events);audio.events(events) end,debug.traceback);if not ok then fail(e) end end)
 Art.yieldFrame=nil
 Run.RenderStepped:Connect(function(dt)
  local ok,e=xpcall(function()
   local size=canvas.AbsoluteSize or workspace.CurrentCamera.ViewportSize;if size.X<=0 or size.Y<=0 then return end;local fit=math.min(size.X/1440,size.Y/810);if scale.Scale~=fit then scale.Scale=fit end
   age=age+dt;wait=wait+dt;if pending>0 and wait>8 then pending=0;transient="请求超时，请检查网络后重试。";transientUntil=os.clock()+4 end
   battle.update(dt);audio.update(dt,snap and snap.paused,snap)
   if not snap then return end
   uiClock=uiClock+dt
   if readySent and not dirty and uiClock<.1 then return end;uiClock=0
   readouts.sync(snap);pauseButton.Visible=snap.phase=="running"
   local statusValue=snap.phase=="running" and ("第 "..snap.wave.." / "..snap.mission.waves.." 波   |   耐久 "..math.ceil(snap.hull).." / "..snap.maxHull.."   |   金矿 "..snap.ore..(snap.stage=="mining" and "   采矿 "..math.ceil(snap.breakLeft).."s" or "")) or resource(snap.profile)
   if status.Text~=statusValue then status.Text=statusValue end
   local noteValue=os.clock()<transientUntil and transient or age>4 and "连接延迟：正在等待服务器…" or pending>0 and "正在处理…" or snap.phase=="running" and (snap.stage=="mining" and "采矿 / 已采在途 "..(snap.prepare and snap.prepare.retainedCargo or 0).." · 继续预计再采 "..(snap.prepare and snap.prepare.futureOre or 0).." 金矿；提前收队保留已采货物" or (snap.encounter and snap.encounter.tip or "主炮自动射击 · P 暂停")) or (snap.notice or "")
   if note.Text~=noteValue then note.Text=noteValue end
   if dirty then dirty=false;draw() end
   for id,b in pairs(shopButtons) do local price=snap.prices[id];local level=snap.upgrades[id] or 0
    local v=snap.investments[id];local value=C.Upgrades[id].name.."  Lv."..level.."\n"..v.detail.."\n"..(v.canBuy and price.." 金矿" or v.reason)
    if b.Text~=value then b.Text=value end;U.enabled(b,v.canBuy)
   end
   if view=="confirm_recall" and recallText and snap.prepare then
    local f=snap.prepare;recallText.Text="已采在途 "..f.retainedCargo.." 金矿：全部保留\n继续预计再采约 "..f.futureOre.." 金矿；收队将放弃未完成钻探\n返航最多约 "..math.ceil(f.returnEta).." 秒"
   end
   if not painted then painted=true;return end
   if not readySent then readySent=true;send("ui_ready",Input.TouchEnabled and "touch" or "keyboard") end
   if not pg:GetAttribute("FrontierGameReady") then pg:SetAttribute("FrontierGameReady",true);pg:SetAttribute("FrontierClientPhase","READY");pg:SetAttribute("FrontierLoadProgress",1) end
  end,debug.traceback);if not ok then fail(e) end
 end)
 Input.WindowFocusReleased:Connect(function() audio.focus(false);if snap and snap.phase=="running" and snap.profile.settings.autoPause then send("pause",true) end end)
 Input.WindowFocused:Connect(function() audio.focus(true) end)
 Input.InputBegan:Connect(function(input,processed) if processed or not snap or not snap.profile.settings.hotkeys then return end;if input.KeyCode==Enum.KeyCode.P and snap.phase=="running" then send("pause",not snap.paused) elseif input.KeyCode==Enum.KeyCode.Backspace then close() end end)
 pcall(function() pg.ScreenOrientation=Enum.ScreenOrientation.LandscapeSensor end)
 pg:SetAttribute("FrontierClientPhase","WAITING_FOR_2D_STATE");send("ready")
end
local ok,e=xpcall(launch,debug.traceback);if not ok then fail(e) end
