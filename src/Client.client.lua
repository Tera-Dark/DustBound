-- DUSTBOUND 0.5.0 | native adaptive 2D client. No HTML and no avatar dependency.
local Players=game:GetService("Players");local pg=Players.LocalPlayer:WaitForChild("PlayerGui")
pg:SetAttribute("FrontierGameReady",false);pg:SetAttribute("FrontierClientPhase","BUILDING_2D_UI");pg:SetAttribute("FrontierClientError","")
local function fail(err) pg:SetAttribute("FrontierClientPhase","ERROR");pg:SetAttribute("FrontierClientError",tostring(err):sub(1,3000));warn("[DUSTBOUND UI] "..tostring(err)) end
local function launch()
 local RS=game:GetService("ReplicatedStorage");local RunService=game:GetService("RunService");local UIS=game:GetService("UserInputService")
 local shared=RS:WaitForChild("FrontierShared",10);assert(shared,"FrontierShared missing")
 local C=require(shared:WaitForChild("Config",10));local R=require(shared:WaitForChild("Rules",10));C.Tech=require(shared:WaitForChild("Tech",10));C.Catalog=require(shared:WaitForChild("Catalog",10))
 pcall(function() pg.ScreenOrientation=Enum.ScreenOrientation.LandscapeSensor end)
 local U=require(shared:WaitForChild("UI",10));local Guide=require(shared:WaitForChild("Guide",10));local Art=require(shared:WaitForChild("Art",10));local Motion=require(shared:WaitForChild("Motion",10));local Panels=require(shared:WaitForChild("Panels",10));local Audio=require(shared:WaitForChild("Audio",10))
 pg:SetAttribute("FrontierClientPhase","LOADING_CARTOON_ART");Art.init();local audio=Audio.new(C)
 local c=U.colors
 local function screen(name,order,safe)
  local g=Instance.new("ScreenGui");g.Name=name;g.ResetOnSpawn=false;g.DisplayOrder=order;g.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
  g.ScreenInsets=safe and Enum.ScreenInsets.CoreUISafeInsets or Enum.ScreenInsets.None;g.SafeAreaCompatibility=Enum.SafeAreaCompatibility.None;g.ClipToDeviceSafeArea=safe;g.Parent=pg;return g
 end
 local bgGui=screen("DustboundBackground",1,false);local bg=Art.sprite(bgGui,"background",0,0,1440,810);bg.Size=UDim2.fromScale(1,1)
 local gui=screen("DustboundHUD",10,true);local canvas=U.frame(gui,"Canvas",0,0,1440,810,nil,1);canvas.Size=UDim2.fromScale(1,1)
 local root=U.frame(canvas,"Stage",0,0,1440,810,nil,1);root.AnchorPoint=Vector2.new(.5,.5);root.Position=UDim2.fromScale(.5,.5)
 local scaler=Instance.new("UIScale");scaler.Parent=root
 local shadeGui=screen("DustboundShade",20,false);local shade=U.frame(shadeGui,"ModalBackdrop",0,0,1440,810,c.ink,.42);shade.Size=UDim2.fromScale(1,1);shade.Active=true;shade.Visible=false
 local modalGui=screen("DustboundPanels",21,true);local modalCanvas=U.frame(modalGui,"SafeCanvas",0,0,1440,810,nil,1);modalCanvas.Size=UDim2.fromScale(1,1)
 local modalRoot=U.frame(modalCanvas,"ModalStage",0,0,1440,810,nil,1);modalRoot.AnchorPoint=Vector2.new(.5,.5);modalRoot.Position=UDim2.fromScale(.5,.5);modalRoot.Visible=false
 local modalScale=Instance.new("UIScale");modalScale.Parent=modalRoot
 local modal=U.panel(modalRoot,"Modal",72,65,1296,680,c.cream)
 local net=RS:WaitForChild("FrontierNetwork",12);assert(net,"FrontierNetwork missing")
 local Action=net:WaitForChild("Action",10);local State=net:WaitForChild("State",10);local FX=net:WaitForChild("FX",10);assert(Action and State and FX,"Network endpoints missing")
 local pendingOverlay=U.frame(modalRoot,"PendingRequest",72,65,1296,680,c.ink,.35);pendingOverlay.ZIndex=5;pendingOverlay.Active=true;pendingOverlay.Visible=false
 local pendingLabel=U.text(pendingOverlay,"Text","正在处理，请稍候…",0,0,1296,680,27,c.cream,true,Enum.TextXAlignment.Center)
 local snap=nil;local view=nil;local tab="weapons";local page=1;local selectedSupply=nil;local offerToken=nil
 local requestSerial=0;local waiting=0;local waitingTime=0;local pendingKind=nil;local sentUI=false;local deferredView=nil
 local function send(kind,data)
  if kind=="ready" or kind=="view" or kind=="ui_ready" then Action:FireServer(kind,data);return true end
  if waiting>0 then return false end
  requestSerial=requestSerial+1;waiting=requestSerial;waitingTime=0;pendingKind=kind
  Action:FireServer(kind,data,requestSerial);return true
 end
 local function open(v)
  view=v
  if v=="research" or v=="codex" or v=="settings" then deferredView=v end
 end
 local function close() view=snap and snap.paused and "pause" or nil end
 local function focusUpgrade(id) for group,ids in pairs(C.Categories) do for i,key in ipairs(ids) do if key==id then tab=group;page=i;return end end end end
 local panels=Panels.new({U=U,C=C,R=R,Guide=Guide,Art=Art,audio=audio,send=send,open=open,close=close,focusUpgrade=focusUpgrade,
  selectedSupply=function() return selectedSupply end,selectSupply=function(id) selectedSupply=id end})
 local W,H,compact=1440,810,false;local refs={};local motion=nil;local layoutKey="";local modalKey=""
 local function txt(p,n,v,x,y,w,h,size,bold) return U.text(p,n,v,x,y,w,h,size or 22,c.ink,bold) end
 local function btn(p,n,v,x,y,w,h,fn,a)
  return U.button(p,n,v,x,y,w,h,function() audio.play("click");fn() end,a)
 end
 local function begin(mode) if send("start",mode) then view=nil;tab="weapons";page=1 end end
 local function buildLayout()
  U.clear(root);refs={};layoutKey=tostring(compact);modalKey=""
  root.Size=UDim2.fromOffset(W,H);modalRoot.Size=UDim2.fromOffset(W,H)
  modal.Position=UDim2.fromOffset(compact and 10 or 72,compact and 10 or 65);modal.Size=UDim2.fromOffset(compact and W-20 or 1296,compact and H-20 or 680)
  pendingOverlay.Position=modal.Position;pendingOverlay.Size=modal.Size;pendingLabel.Size=UDim2.fromScale(1,1)
  local menu=U.frame(root,"MainMenu",0,0,W,H,nil,1);refs.menu=menu
  if compact then
   txt(menu,"Title","DUSTBOUND",24,10,536,63,48,true)
   txt(menu,"Tagline","荒星前哨 / 自动防御 · 机器人采矿",27,71,556,38,23)
   Art.sprite(menu,"base",W-437,185,408,267);Art.sprite(menu,"turret",W-224,120,135,86)
   refs.wallet=txt(menu,"Wallet","",W-344,14,318,103,23,true)
   refs.tutorial=btn(menu,"Tutorial","3 波教学 · 推荐",24,125,456,72,function() begin("tutorial") end,true)
   refs.start=btn(menu,"Start","▶  开始标准远征",24,211,456,72,function() begin("standard") end)
   btn(menu,"Research","研究中心",24,297,222,72,function() open("research") end)
   btn(menu,"Workshop","武器工坊",258,297,222,72,function() open("workshop") end)
   btn(menu,"Codex","远征图鉴",24,383,222,72,function() open("codex") end)
   btn(menu,"Settings","设置",258,383,222,72,function() open("settings") end)
   refs.menuGoal=txt(menu,"Goal","",W-429,450,402,66,21,true)
   refs.menuStatus=txt(menu,"StorageStatus","",24,H-70,480,62,19)
  else
   txt(menu,"Kicker","AUTOMATE · INVEST · SURVIVE",64,28,700,33,18,true)
   txt(menu,"Title","DUSTBOUND",58,77,780,107,83,true)
   txt(menu,"Tagline","荒星前哨 / 让每一笔投入有价值。",64,189,680,54,30,true)
   Art.sprite(menu,"base",664,226,686,449);Art.sprite(menu,"turret",956,133,210,133)
   local wallet=U.panel(menu,"WalletPanel",1123,22,286,130,c.cream);refs.wallet=txt(wallet,"Wallet","",18,12,250,104,22,true)
   local p=U.panel(menu,"MenuPanel",64,279,522,377,c.cream)
   refs.tutorial=btn(p,"Tutorial","3 波教学 · 推荐",21,20,480,73,function() begin("tutorial") end,true)
   refs.start=btn(p,"Start","▶  开始标准远征",21,108,480,68,function() begin("standard") end)
   btn(p,"Research","研究中心",21,193,230,67,function() open("research") end)
   btn(p,"Workshop","武器工坊",271,193,230,67,function() open("workshop") end)
   btn(p,"Codex","远征图鉴",21,280,230,67,function() open("codex") end)
   btn(p,"Settings","设置",271,280,230,67,function() open("settings") end)
   local gp=U.panel(menu,"PinnedGoal",626,684,782,98,c.cream);refs.menuGoal=txt(gp,"Goal","",18,10,746,79,23)
   refs.menuStatus=txt(menu,"StorageStatus","",64,674,526,93,18)
  end
  local scene=U.frame(root,"Battlefield",0,0,1440,550,nil,1);refs.scene=scene
  local ss=Instance.new("UIScale");ss.Scale=compact and .58 or 1;ss.Parent=scene
  if compact then scene.Position=UDim2.fromOffset(18,7) end
  Art.sprite(scene,"crystal",172,379,104,106)
  local base=Art.sprite(scene,"base",242,188,435,284);local turret=Art.sprite(scene,"turret",412,110,162,103)
  local muzzle=U.frame(scene,"MuzzleFlash",550,122,29,22,c.gold);U.corner(muzzle,10);muzzle.Visible=false
  local auxiliary=U.frame(scene,"Coil",578,260,25,40,c.mint);U.corner(auxiliary,12)
  local enemies=U.frame(scene,"Enemies",0,0,1440,550,nil,1);local robots=U.frame(scene,"Robots",0,0,1440,550,nil,1);local fx=U.frame(scene,"Effects",0,0,1440,550,nil,1)
  motion=Motion.new({C=C,Art=Art,colors=c,frame=U.frame,corner=U.corner,enemiesLayer=enemies,robotLayer=robots,fxLayer=fx,turret=turret,base=base,muzzle=muzzle,auxiliary=auxiliary,
   reduced=function() return snap and snap.profile.settings.reducedMotion or false end,numbers=function() return not snap or snap.profile.settings.damageNumbers end})
  if snap then motion.sync(snap) end
  local hud=U.frame(root,"GameHUD",0,0,W,H,nil,1);refs.hud=hud
  refs.wave=txt(hud,"Wave","",compact and 17 or 496,7,compact and 320 or 440,38,compact and 27 or 32,true)
  local hb=U.panel(hud,"Hull",compact and 20 or 497,compact and 46 or 55,compact and 314 or 435,compact and 22 or 38,c.paper)
  refs.hullFill=U.frame(hb,"Fill",0,0,compact and 314 or 435,compact and 22 or 38,c.mint);U.corner(refs.hullFill,8)
  refs.hull=txt(hb,"Value","",0,0,compact and 314 or 435,compact and 22 or 38,compact and 17 or 24,true)
  if not compact then txt(hud,"Brand","DUSTBOUND",38,13,418,45,38,true) end
  refs.ore=txt(hud,"Ore","",compact and 376 or 1090,8,compact and 302 or 316,49,compact and 30 or 34,true)
  btn(hud,"Pause","Ⅱ",W-(compact and 89 or 490),compact and 5 or 20,compact and 73 or 64,compact and 70 or 64,function() if snap then local wanted=not snap.paused;if send("pause",wanted) then view=wanted and "pause" or nil end end end)
  refs.plannerButton=btn(hud,"Planner","情报",compact and 696 or 1110,compact and 5 or 145,compact and 151 or 292,compact and 70 or 67,function() open(snap and snap.supply and "supply" or "planner") end)
  refs.stage=txt(hud,"Stage","",compact and W*.54 or 705,compact and 79 or 103,compact and W*.43 or 696,39,compact and 24 or 23,true)
  refs.guide=txt(hud,"Guide","",compact and W*.54 or 705,compact and 124 or 216,compact and W*.43 or 696,compact and 76 or 66,compact and 22 or 22)
  refs.cargo=txt(hud,"Forecast","",compact and W*.54 or 705,compact and 204 or 300,compact and W*.43 or 696,compact and 70 or 89,compact and 22 or 24,true)
  refs.notice=txt(hud,"Notice","",compact and 25 or 270,compact and H-264 or 504,compact and 910 or 950,compact and 36 or 49,compact and 20 or 22,true)
  refs.tabs={};refs.cards={}
  if compact then
   for i,d in ipairs({{"base","基地"},{"mining","采矿"},{"weapons","武器"}}) do
    local key=d[1];refs.tabs[key]=btn(hud,"Tab_"..key,d[2],12+(i-1)*(W-24)/3,H-222,(W-42)/3,70,function() tab=key;page=1 end,key==tab)
   end
   local card=U.panel(hud,"UpgradeCard",12,H-140,W-24,128,c.cream)
   btn(card,"PreviousUpgrade","‹",10,42,70,73,function() page=(page+1)%3+1 end)
   btn(card,"NextUpgrade","›",W-114,42,70,73,function() page=page%3+1 end)
   local title=txt(card,"Name","",100,8,503,39,27,true)
   local detail=txt(card,"Detail","",100,47,479,67,23)
   local buy=btn(card,"Buy","",W-356,45,230,70,function() if snap then send("buy",C.Categories[tab][page]) end end,true)
   local level=txt(card,"Level","",W-356,10,230,30,19)
   refs.cards[1]={title=title,detail=detail,buy=buy,level=level}
  else
   local y=H-238
   for i,d in ipairs({{"base","基地"},{"mining","采矿"},{"weapons","武器"}}) do
    local key=d[1];refs.tabs[key]=btn(hud,"Tab_"..key,d[2],205+(i-1)*343,y,332,55,function() tab=key;page=1 end,key==tab)
   end
   for i=1,3 do
    local p=U.panel(hud,"Upgrade"..i,205+(i-1)*343,y+69,332,164,c.cream)
    local title=txt(p,"Name","",17,8,299,34,25,true);local detail=txt(p,"Detail","",17,49,299,49,20)
    local buy=btn(p,"Buy","",17,106,298,48,function() if snap then send("buy",C.Categories[tab][i]) end end,true)
    refs.cards[i]={title=title,detail=detail,buy=buy}
   end
   local power=U.panel(hud,"Power",25,y+69,162,164,c.cream)
   txt(power,"Title","能源分配",8,5,146,28,18,true)
   for i,d in ipairs({{"balanced","均衡"},{"mining","采矿优先"},{"defense","防御优先"}}) do
    local key=d[1];local b=btn(power,"Power_"..key,d[2],9,38+(i-1)*41,144,33,function() send("allocate",key) end);b.TextSize=17
   end
   local target=U.panel(hud,"Target",1258,y+69,156,164,c.cream);refs.target=txt(target,"Text","",10,7,136,150,17)
  end
  refs.request=txt(root,"RequestStatus","",compact and 23 or 35,compact and H-282 or H-267,compact and 918 or 1300,29,compact and 19 or 18,true)
 end
 local function render()
  if not snap or not refs.menu then return end
  local s=snap;local inMenu=s.phase=="menu";refs.menu.Visible=inMenu;refs.scene.Visible=not inMenu;refs.hud.Visible=not inMenu
  refs.wallet.Text="合金 "..s.profile.alloy.."   数据 "..s.profile.research.."\n晶体 "..s.profile.crystals.."   核心 "..s.profile.cores
  refs.tutorial.Text=s.profile.tutorialCompleted and "重温教学 · 无材料奖励" or "3 波教学 · 推荐"
  refs.tutorial.BackgroundColor3=s.profile.tutorialCompleted and c.cream or c.orange;refs.start.BackgroundColor3=s.profile.tutorialCompleted and c.orange or c.cream
  refs.menuStatus.Text="v0.5.0 · "..s.saveStatus
  local target=Guide.target(s.profile,C,R);refs.menuGoal.Text="研究目标："..target.title.."\n"..target.detail
  local limit=s.mode=="tutorial" and C.TutorialWaves or s.overtime and 12 or 10
  refs.wave.Text=(s.mode=="tutorial" and "教学 " or "远征 ")..string.format("%02d",s.wave).." / "..limit.." 波"
  refs.hull.Text=math.ceil(s.hull).." / "..s.maxHull;refs.hullFill.Size=UDim2.new(R.clamp(s.hull/s.maxHull,0,1),0,1,0);refs.hullFill.BackgroundColor3=s.hull<s.maxHull*.3 and c.orange or c.mint
  refs.ore.Text="矿料 "..s.ore
  refs.stage.Text=s.paused and "已暂停" or s.supply and "补给待选 · 倒计时暂停" or s.stage=="mining" and "机器人整备 "..math.ceil(s.breakLeft).." / 30 秒" or s.stage=="clearing" and "清剿剩余 "..#s.enemies.." 只" or "虫潮生成 "..math.max(0,math.ceil(C.WaveDuration-s.waveElapsed)).." 秒"
  refs.plannerButton.Text=s.supply and "选择补给" or "情报 / 经营台"
  local rec=s.recommendation or Guide.recommend(s,C,R);local intel=Guide.intel(s.stage=="mining" and math.min(limit,s.wave+1) or s.wave,C)
  refs.guide.Text=s.mode=="tutorial" and Guide.lesson(s) or intel.tip
  if s.stage=="mining" then
   local f=s.forecast or Guide.forecast(s);refs.cargo.Text="在途 "..f.cargo.." · 下趟约 "..f.eta.." 秒\n余下预计运回 "..f.expected.." 矿料"
  else refs.cargo.Text="建议："..C.Upgrades[rec.id].name.."\n"..rec.info.detail end
  refs.cargo.Visible=not compact and s.stage=="mining"
  if compact and s.stage=="mining" and s.firstDeposit then
   local f=s.forecast or Guide.forecast(s)
   refs.guide.Text="在途 "..f.cargo.." · 下次约 "..f.eta.." 秒运回\n余下约 "..f.expected.." 矿料（估算）"
  end
  refs.notice.Text=(Art.mode=="fallback" and #s.enemies>12) and "兼容显示：另有 "..(#s.enemies-12).." 只敌人参与战斗" or s.notice or ""
  if refs.target then refs.target.Text="研究目标\n"..target.title.."\n"..(target.id~="" and "菜单查看来源" or "可固定一个目标") end
  for id,b in pairs(refs.tabs) do b.BackgroundColor3=id==tab and c.orange or c.cream end
  for i,card in ipairs(refs.cards) do
   local slot=compact and page or i;local id=C.Categories[tab][slot];local info=Guide.investment(id,s,C,R)
   card.title.Text=info.name..(not compact and id==rec.id and " ★ 建议" or "")..(compact and "  "..slot.." / 3" or "")
   card.detail.Text=info.detail
   if card.level then card.level.Text="等级 "..info.level.." / "..info.cap end
   card.buy.Text=not info.price and "已满级" or "投入 "..info.price.." 矿料"..(info.gap>0 and " / 缺 "..info.gap or "")
   if id=="repair" and s.hull>=s.maxHull then card.buy.Text="耐久已满" end
   U.enabled(card.buy,info.can and waiting==0)
  end
  refs.request.Text=waiting>0 and "正在处理…" or s.storage.mode=="save_error" and "保存失败：到设置重试；离开可能丢失未保存进度" or s.actionResult or ""
  if s.supply then
   if offerToken~=s.supply.token then offerToken=s.supply.token;selectedSupply=s.supply.options[1] end
  else selectedSupply=nil;offerToken=nil;if view=="supply" or view=="invest" then view=nil end end
  if view=="planner" and s.stage~="mining" then
   -- Keep battle intel accessible; no fabricated mining forecast during combat.
  end
  local kind=s.storage.blocked and "storage" or s.paused and (view or "pause") or s.phase=="decision" and "decision" or s.phase=="ended" and (view or "result") or view=="invest" and nil or view or s.supply and "supply" or nil
  -- 'invest' is an intentional non-modal view while supply still holds the countdown.
  if view=="invest" and not s.paused and not s.storage.blocked then kind=nil end
  shade.Visible=kind~=nil;modalRoot.Visible=kind~=nil;pendingOverlay.Visible=kind~=nil and waiting>0
  if kind then
   local owned=0;for _ in pairs(s.profile.tech) do owned=owned+1 end
   local cfg=s.profile.settings
   local key=kind..":"..tostring(compact)..":"..panels.revision..":"..s.profile.alloy..":"..s.profile.research..":"..s.profile.crystals..":"..s.profile.cores..":"..owned..":"..s.profile.targetResearch..":"..s.loadout..":"..tostring(cfg.reducedMotion)..":"..tostring(cfg.damageNumbers)..":"..cfg.sfx..":"..cfg.music..":"..s.saveStatus..":"..tostring(s.storage.busy)..":"..tostring(offerToken)..":"..tostring(selectedSupply)..":"..tostring(s.profile.presets[1])
   if kind=="planner" then key=key..":"..math.floor(s.elapsed*2)..":"..s.allocation end
   if key~=modalKey then modalKey=key;panels.build(modal,kind,s,compact,compact and W-20 or 1296,compact and H-20 or 680) end
  else modalKey="" end
 end
 local function resize()
  local camera=workspace.CurrentCamera;if not camera then return end;camera.CameraType=Enum.CameraType.Scriptable
  local size=canvas.AbsoluteSize
  if not size or size.X<1 or size.Y<1 then
   size=camera.ViewportSize
   local ok,a,b=pcall(function() return game:GetService("GuiService"):GetGuiInset() end)
   if ok and a and b then size=Vector2.new(size.X-a.X-b.X,size.Y-a.Y-b.Y) end
  end
  if size.X<1 or size.Y<1 then return end
  local small=size.X<1050 or size.Y<580;local nw=small and math.max(960,math.floor(size.X/size.Y*540/8)*8) or 1440
  local changed=small~=compact or layoutKey=="" or nw~=W
  compact=small;W=nw;H=compact and 540 or 810
  if changed then buildLayout() end
  local scale=math.min(size.X/W,size.Y/H);scaler.Scale=scale;modalScale.Scale=scale
 end
 State.OnClientEvent:Connect(function(packet)
  local ok,err=xpcall(function()
   snap=packet;requestSerial=math.max(requestSerial,packet.ack or 0);audio.settings(snap.profile.settings)
   if (packet.ack or 0)>=waiting then waiting=0;pendingKind=nil end
   resize();render();if not motion then pg:SetAttribute("FrontierClientPhase","WAITING_FOR_VIEWPORT");return end;motion.sync(snap)
   pg:SetAttribute("FrontierGameReady",true);pg:SetAttribute("FrontierClientPhase","READY_2D")
  end,debug.traceback);if not ok then fail(err) end
 end)
 FX.OnClientEvent:Connect(function(events) local ok,err=xpcall(function() if motion then motion.events(events) end;audio.events(events) end,debug.traceback);if not ok then fail(err) end end)
 local uiClock,requestClock=0,0
 RunService.RenderStepped:Connect(function(dt)
  local ok,err=xpcall(function()
   resize();requestClock=requestClock+dt
   if not snap and requestClock>1 then requestClock=0;send("ready") end
   if waiting>0 then waitingTime=waitingTime+dt;if waitingTime>3 then waiting=0;pendingKind=nil;send("ready") end end
   uiClock=uiClock+dt;if uiClock>.12 then uiClock=0;render() end
   if snap and not sentUI and waiting==0 and motion then sentUI=true;send("ui_ready",UIS.TouchEnabled and "touch" or "keyboard")
   elseif deferredView and waiting==0 then local v=deferredView;deferredView=nil;send("view",v) end
   if motion then motion.update(dt) end;audio.update(dt,snap and snap.paused,snap)
  end,debug.traceback);if not ok then fail(err) end
 end)
 UIS.InputBegan:Connect(function(input,processed)
  if processed or UIS:GetFocusedTextBox() then return end
  if input.KeyCode==Enum.KeyCode.P and snap and (snap.phase=="running" or snap.phase=="decision") then local wanted=not snap.paused;if send("pause",wanted) then view=wanted and "pause" or nil end end
  if input.KeyCode==Enum.KeyCode.One then tab="base";page=1 elseif input.KeyCode==Enum.KeyCode.Two then tab="mining";page=1 elseif input.KeyCode==Enum.KeyCode.Three then tab="weapons";page=1 end
 end)
 pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All,false) end)
 pg:SetAttribute("FrontierClientPhase","WAITING_FOR_2D_STATE");resize();send("ready")
end
local ok,err=xpcall(launch,debug.traceback);if not ok then fail(err) end
