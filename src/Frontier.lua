-- 0.8 presentation only. All progression and purchases remain server-authoritative.
local F={}
function F.menu(ctx,parent,hud,s,view,selected,open,select,send)
 local U,C,Art=ctx.U,ctx.C,ctx.Art;local c=U.colors
 local function t(p,n,v,x,y,w,h,size,col) return U.text(p,n,v,x,y,w,h,size or 20,col or c.ink,true) end
 local function b(p,n,v,x,y,w,h,fn,accent) return U.button(p,n,v,x,y,w,h,fn,accent) end
 local function tag(p,n,v,x,y,w,col)
  local box=U.panel(p,n,x,y,w,30,c.paper);t(box,"Label",v,10,0,w-20,30,13,col or c.mint);return box
 end
 local nav={{"Home","前哨总览",nil},{"Campaign","远征航图","campaign"},{"Research","研究网络","research"},{"Codex","远征图鉴","codex"},{"Options","系统设置","settings"}}
 for i,n in ipairs(nav) do
  local active=view==n[3] or (view==nil and i==1)
  local btn=b(hud,"Nav_"..n[1],string.format("%02d  %s",i,n[2]),(i-1)*228,4,212,58,function() open(n[3]) end,active)
  btn.TextSize=18
 end
 t(hud,"Build","0.9 / FIRST CONTACT",1160,4,200,58,15,c.muted)
 if view=="research" then return end
 if view=="campaign" then
  local board=U.panel(parent,"ExpeditionBoard",0,-8,1380,554,c.cream)
  tag(board,"Section","EXPEDITION / 远征指挥",28,20,240)
  t(board,"Title","选择下一处前哨",28, 64,850,54,38)
  t(board,"Subtitle","逐段推进航线，守住矿脉。通关后解锁相邻区域。",28,120,900,32,18,c.muted)
  local planet=math.floor((selected-1)/8)+1
  for p=1,3 do
   local unlocked=(p-1)*8<=s.profile.campaignCleared
   local btn=b(board,"PlanetTab"..p,string.format("0%d   %s",p,C.Catalog.planets[p].name),28+(p-1)*286,175,270,54,function() select((p-1)*8+1) end,p==planet)
   btn.TextSize=18;U.enabled(btn,unlocked)
  end
  local d=C.Catalog.campaign[selected]
  for n=1,8 do
   local id=(planet-1)*8+n;local mission=C.Catalog.campaign[id];local x=36+(n-1)%4*211;local y=274+math.floor((n-1)/4)*112
   local cleared=id<=s.profile.campaignCleared;local unlocked=id<=s.profile.campaignCleared+1
   local btn=b(board,"Node"..id,string.format("%02d   %s\n%s · %d 波",n,mission.name,cleared and "已完成" or unlocked and "可远征" or "未解锁",mission.waves),x,y,193,88,function() select(id) end,id==selected)
   btn.TextSize=17;U.enabled(btn,unlocked)
   if cleared and id~=selected then btn.TextColor3=c.mint end
  end
  local detail=U.panel(board,"MissionBrief",918,20,434,506,c.paper)
  t(detail,"Sector","SECTOR "..string.format("%02d",selected).." / 任务简报",24,16,386,34,15,c.mint)
  t(detail,"Name",d.name,24,62,386,54,32)
  t(detail,"Terrain",C.Catalog.planets[planet].theme,24,123,386,55,19,c.muted)
  t(detail,"Waves",d.waves.." 波防守   /   "..(d.boss and "中枢任务" or "前哨任务"),24,195,386,36,22)
  t(detail,"Enemy","地面：左右虫群\n空中：第 3 波起掠翼虫",24,250,386,66,19,c.muted)
  local reward=C.Economy.reward(d,true,selected>s.profile.campaignCleared,0,0)
  t(detail,"Rewards","预计基础结算\n合金 +"..reward.alloy.."   数据 +"..reward.research,24,334,386,66,19,c.gold)
  b(detail,"Depart","部署前哨  →",24,428,386,56,function() send("start",{node=selected}) end,true)
  return
 end
 -- Home is not a level grid. The scene remains visible behind the outpost hero.
 local rail=U.panel(parent,"HomeCommand",0,-8,548,554,c.cream)
 tag(rail,"Brand","DUSTBOUND / 荒星前哨",28,25,296,c.mint)
 t(rail,"Title","荒星之上，\n建立你的防线。",28, 83,490,150,48)
 t(rail,"Copy","部署火力，派遣工蜂。\n在下一轮虫潮到来前，让前哨更强。",28,254,480,72,21,c.muted)
 b(rail,"StartGame","开始游戏                 →",28,359,492, 70,function() open("campaign") end,true)
 t(rail,"Resume","航线进度  "..s.profile.campaignCleared.." / 24   ·   下一个目标："..C.Catalog.campaign[selected].name,28,443,490,46,16,c.muted)
 t(rail,"LocalSave",s.saveStatus or "本地试玩 · 不保存",28,497,490,30,13,c.muted)
 tag(parent,"LiveLink","●  OUTPOST UPLINK / 前哨在线",624,12,332)
 Art.sprite(parent,"base",750,207,368,242)
 Art.sprite(parent,"turret",880,182,125, 80)
 Art.sprite(parent,"robot",1135,408,68, 70)
 Art.sprite(parent,"crystal",1230,394,61,82)
 local brief=U.panel(parent,"LatestBrief",632, 63,706,100,c.cream)
 t(brief,"Eyebrow","当前航线 / ACTIVE SECTOR",22,12,650,24,13,c.mint)
 t(brief,"Name","赤砂起航带    /    "..C.Catalog.campaign[selected].name,22,43,650, 40,25)
 local features={{"01 / DEFEND","自动火力 · 守住中心"},{"02 / EXTRACT","实体采矿 · 返航入库"},{"03 / EVOLVE","免费遗物 · 多线研究"}}
 for i,v in ipairs(features) do local card=U.panel(parent,"Feature"..i,632+(i-1)*240,480,226,66,c.cream)
  t(card,"K",v[1],14,7,198,20,12,c.mint);t(card,"V",v[2],14,29,198,27,16)
 end
end
function F.header(U,top)
 local c=U.colors;local self={};local cells={}
 for i,d in ipairs({{"OUTPOST / 07",24,230},{"HULL / 前哨耐久",275,315},{"WAVE / 虫潮",612,210},{"ORE / 金矿",858,260}}) do
  local box=U.frame(top,"Readout"..i,d[2],8,d[3],64,nil,1)
  U.text(box,"Key",d[1],0,0,d[3],20,11,c.muted,true)
  cells[i]=U.text(box,"Value","—",0,22,d[3],32,23,c.ink,true)
 end
 local line=U.frame(top,"HullTrack",275,65,294,3,c.paper)
 local hp=U.frame(line,"HullFill",0,0,294,3,c.mint)
 local labels={"赤砂 · 起航带","合金","数据","核心"}
 function self.sync(s)
  local live=s.phase=="running"
  local values=live and {s.stage=="mining" and "●  采矿整备" or s.stage=="clearing" and "●  残敌清剿" or "●  防线交战",math.ceil(s.hull).." / "..s.maxHull,string.format("%02d / %02d",s.wave,s.mission.waves),s.ore..(s.stage=="mining" and "   · "..math.ceil(s.breakLeft).."s" or "   +"..s.totalMined.." 采集")} or {"前哨指挥中心",s.profile.alloy.."  合金",s.profile.research.."  数据",s.profile.cores.."  核心"}
  for i,v in ipairs(values) do if cells[i].Text~=v then cells[i].Text=v end end
  if line.Visible~=live then line.Visible=live end
  if live then local ratio=math.max(0,s.hull/s.maxHull);if self.ratio~=ratio then hp.Size=UDim2.new(ratio,0,1,0);hp.BackgroundColor3=ratio<.3 and c.red or c.mint;self.ratio=ratio end end
  local keys=live and {"OUTPOST / 07","HULL / 前哨耐久","WAVE / 虫潮","ORE / 金矿"} or {"DUSTBOUND / 荒星前哨","ALLOY / 永久材料","DATA / 研究资料","CORE / 行星核心"}
  for i,k in ipairs(keys) do local label=cells[i].Parent:FindFirstChild("Key");if label.Text~=k then label.Text=k end end
 end
 return self
end
function F.battleHud(ctx,parent,s,view,open,send)
 local U,C,Art=ctx.U,ctx.C,ctx.Art;local c=U.colors
 local tactics=U.panel(parent,"TacticalBar",0,-68,1380,56,c.cream)
 for i,v in ipairs({{"nearest","近身"},{"air","空中"},{"armor","重甲"}}) do
  local btn=U.button(tactics,"Aim_"..v[1],"主炮 / "..v[2],12+(i-1)*147,8,137,40,function() send("target_mode",v[1]) end,s.targetMode==v[1]);btn.TextSize=16;U.enabled(btn,not s.paused and not s.supply)
 end
 U.text(tactics,"WaveIntel",s.stage=="mining" and "下波 / "..(s.nextEncounter and s.nextEncounter.name or "—") or "当前 / "..(s.encounter and s.encounter.name or "—"),478,7,560,42,18,c.ink,true)
 local recall=U.button(tactics,"Recall","提前收队 →",1118,8,246,40,function() open("confirm_recall") end,true)
 recall.TextSize=17;recall.Visible=s.stage=="mining";U.enabled(recall,s.prepare and not s.prepare.recalling and not s.supply and not s.paused or false)
 local dock=U.panel(parent,"BattleDock",0,-4,1380,78,c.cream)
 U.button(dock,"Mining","采矿投资",12,10,208,58,function() open(view=="mining" and nil or "mining") end,true)
 U.button(dock,"Combat","战斗投资",232,10,208,58,function() open(view=="combat" and nil or "combat") end)
 for i,slot in ipairs(s.weaponSlots) do
  local card=U.panel(dock,"LoadoutSlot"..i,472+(i-1)*117,9,103,60,c.paper)
  U.text(card,"Label",i==1 and "MAIN" or "AUX "..(i-1),7,3,89,15,9,c.muted,true)
  if slot.enabled then
   Art.sprite(card,slot.weapon=="arc" and "crystal" or slot.weapon=="flame" and "drillBit" or "turret",35,16, 40, 30)
  else U.text(card,"Empty","+",0,16,103,34,25,c.muted,true,Enum.TextXAlignment.Center) end
 end
 local count=0;for _ in pairs(s.relics) do count=count+1 end
 U.button(dock,"Relics","遗物 ×"..count,1120,10,244,58,function() open("relics") end)
end
return F
