-- Articulated GUI rigs, server projectile interpolation and pooled feedback.
-- Images are static shared atlas regions; only transforms change per render frame.
local A=require(script.Parent.Animation)
local WeaponRig=require(script.Parent.WeaponRig)
local Motion={}
function Motion.new(ctx)
 local self={actors={},pool={},shots={},robots={},fx={},fxPool={},time=0,since=0,recoil=0,recoilV=0,shake=0,angle=0,poseClock=0,visualDirty=true,queue={},seenShots={},renderTime=0,highestShot=0,dropped=0}
 local function option(key) return not ctx.options or ctx.options()[key]~=false end
 local frame,corner,Art,C=ctx.frame,ctx.corner,ctx.Art,ctx.C;local c=ctx.colors
 local limits=C.Animation or {delay=.10,eventLimit=192,projectileLimit=80,effectLimit=56}
 self.weapons=WeaponRig.new(ctx)
 ctx.turret.Visible=false;ctx.muzzle.Visible=false;ctx.auxiliary.Visible=false
 local function segment(parent,name,color,width)
  local f=frame(parent,name,0,0,1,width,color);f.AnchorPoint=Vector2.new(.5,.5);corner(f,width/2);return f
 end
 local function line(f,x,y,tx,ty,width)
  local dx,dy=tx-x,ty-y;f.Position=UDim2.fromOffset((x+tx)/2,(y+ty)/2);f.Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy),width);f.Rotation=math.deg(math.atan2(dy,dx))
 end
 local function actor(kind)
  local d=C.Catalog.enemies[kind];local key=d.body
  local a=table.remove(self.pool[key] or {})
  if not a then
   local root=frame(ctx.enemiesLayer,"Rig_"..key,0,0,96,91,nil,1);root.AnchorPoint=Vector2.new(.5,1)
   local shadow=frame(root,"Shadow",4,73,90,12,c.ink,.77);corner(shadow,12)
   local legs={}
   for i=1,6 do
    legs[i]={upper=segment(root,"UpperLeg"..i,c.ink,8),lower=segment(root,"LowerLeg"..i,c.ink,7),accent=segment(root,"LegAccent"..i,c.purple,3)}
   end
   local body=Art.sprite(root,key,7,11,82,55)
   local eyes=frame(root,"HitFlash",30,31,26,4,c.gold,.9);corner(eyes,2)
   local hp=frame(root,"HealthBack",10,-3,76,5,c.ink);corner(hp,3)
   local bar=frame(hp,"Health",0,0,76,5,c.orange);corner(bar,3)
   local scale=Instance.new("UIScale");scale.Parent=root
   a={ui=root,body=body,legs=legs,bar=bar,flash=eyes,scale=scale,key=key,hp=hp}
  end
  a.ui.Parent=ctx.enemiesLayer;a.ui.Visible=true;a.kind=kind;a.scale.Scale=(d.body=="tankBody" and 1.15 or .92)*(d.scale or 1)
  a.death=nil;a.deathAt=nil;a.target=nil;a.previous=nil;a.posed=false;a.phase=0;a.health=nil;a.emerged=false;return a
 end
 local function release(a) a.ui.Visible=false;a.ui.Parent=nil;self.pool[a.key]=self.pool[a.key] or {};table.insert(self.pool[a.key],a) end
 local function effect(class)
  self.fxPool[class]=self.fxPool[class] or {};local f=table.remove(self.fxPool[class])
  if not f then
   f=Instance.new(class);f.BorderSizePixel=0
   if class=="TextLabel" then f.BackgroundTransparency=1;f.TextSize=18;f.Font=Enum.Font.GothamBold;f.TextStrokeTransparency=.25;f.TextStrokeColor3=c.cream
   else corner(f,12) end
  end
  f.Parent=ctx.fxLayer;f.Visible=true;f.AnchorPoint=Vector2.new(.5,.5);f.Rotation=0;return f
 end
 local function burst(x,y,kind,value)
  if #self.fx>=limits.effectLimit then self.dropped=self.dropped+1;return end
  if kind=="text" then
   local f=effect("TextLabel");f.Text=value;f.TextColor3=c.ink;f.TextTransparency=0;f.Size=UDim2.fromOffset(135,28)
   self.fx[#self.fx+1]={f=f,class="TextLabel",kind="text",x=x,y=y,age=0,life=.85}
  else
   local f=effect("Frame");f.BackgroundColor3=kind=="smoke" and c.paper or kind=="acid" and c.mint or c.gold;f.BackgroundTransparency=.1
   self.fx[#self.fx+1]={f=f,class="Frame",kind=kind,x=x,y=y,age=0,life=kind=="smoke" and .42 or .26}
  end
 end
 local dying={}
 local function newRobot(id)
  local ui=frame(ctx.robotLayer,"Robot"..id,0,0,78,70,nil,1);ui.AnchorPoint=Vector2.new(.5,1)
  local shadow=frame(ui,"Shadow",8,58,63,10,c.ink,.8);corner(shadow,8)
  local arm=segment(ui,"DrillArm",c.ink,8)
  local body=Art.sprite(ui,"robot",17,6,55,51)
  local bit=Art.sprite(ui,"drillBit",0,33,25,17)
  local tread=frame(ui,"TreadMovement",23,48,37,5,c.ink);corner(tread,3)
  local wheels={};for i=1,3 do wheels[i]=frame(tread,"Wheel"..i,(i-1)*12,0,6,3,c.paper);corner(wheels[i],2) end
  local cargo=Art.sprite(ui,"crystal",43,-8,23,29);cargo.Visible=false
  local back=frame(ui,"ProgressBack",16,64,57,4,c.ink);corner(back,2)
  local progress=frame(back,"Progress",0,0,57,4,c.mint);corner(progress,2)
  local spark=frame(ui,"DrillSpark",1,47,5,5,c.gold);corner(spark,3)
  return {ui=ui,body=body,arm=arm,bit=bit,wheels=wheels,cargo=cargo,progress=progress,spark=spark,shadow=shadow,x=385,track=0,deploy=0,dust=0}
 end
 local deposits={}
 for i=1,5 do deposits[i]=Art.sprite(ctx.robotLayer,"crystal",725+(i-1)*112,444+(i%2)*17,39,46);deposits[i].Visible=false end
 local function removeShot(id)
  local sh=self.shots[id];if not sh then return end
  sh.f.Parent=nil;self.fxPool.Frame[#self.fxPool.Frame+1]=sh.f;self.shots[id]=nil
 end
 local function clearTransient()
  for id in pairs(self.shots) do removeShot(id) end
  for _,a in ipairs(dying) do release(a) end;dying={}
  for _,e in ipairs(self.fx) do e.f.Parent=nil;self.fxPool[e.class][#self.fxPool[e.class]+1]=e.f end
  self.fx={};self.queue={};self.seenShots={};self.highestShot=0
 end
 local function visual(weapon)
  local d=C.Catalog.weapons[weapon]
  return d and d.visual or {projectile="shell",color={135,226,185},arc=0,length=17,width=7}
 end
 local function addShot(p,stamp)
  if self.shots[p.id] then
   local sh=self.shots[p.id];sh.goalX=p.tx;sh.goalY=p.ty;return
  end
  if self.seenShots[p.id] then return end
  local count=0;for _ in pairs(self.shots) do count=count+1 end
  if count>=limits.projectileLimit then self.dropped=self.dropped+1;return end
  self.seenShots[p.id]=true;self.highestShot=math.max(self.highestShot,p.id)
  local v=visual(p.weapon);local born=p.born or stamp-(p.age or 0);local duration=p.duration
  local late=born+duration<self.renderTime
  if late then born=self.renderTime;duration=math.min(.09,duration) end
  local slot=p.slot or (p.weapon=="cannon" and 1 or p.weapon~="acid" and 2 or nil)
  local x,y=p.x,p.y
  if slot then local mx,my=self.weapons.muzzle(slot);x=mx or x;y=my or y end
  local f=effect("Frame");f.Visible=false;f.BackgroundColor3=Color3.fromRGB(v.color[1],v.color[2],v.color[3]);f.BackgroundTransparency=0
  f.Size=UDim2.fromOffset(v.length or 17,v.width or 5)
  self.shots[p.id]={f=f,p={id=p.id,x=x,y=y,tx=p.tx,ty=p.ty,born=born,duration=duration,arc=v.arc or 0},goalX=p.tx,goalY=p.ty,late=late}
 end
 function self.sync(s)
  local old=self.snap;local reset=not old or old.runId~=s.runId or s.elapsed<old.elapsed
  local changed=reset or not old or old.phase~=s.phase or old.stage~=s.stage or old.paused~=s.paused or old.wave~=s.wave
  self.visualDirty=self.visualDirty or changed
  if reset then
   clearTransient();self.weapons.reset();for id,a in pairs(self.actors) do release(a);self.actors[id]=nil end
   self.time=s.elapsed;self.renderTime=math.max(0,s.elapsed-limits.delay);self.since=0
  else self.time=math.max(self.time,s.elapsed) end
  if old then for _,key in ipairs({"reducedMotion","screenShake","flashEffects","enemyHealth"}) do
   if old.profile.settings[key]~=s.profile.settings[key] then self.visualDirty=true end
  end end
  self.snap=s;self.weapons.configure(s)
  local seen={}
  for i,e in ipairs(s.enemies) do if Art.mode~="fallback" or i<=12 then
   seen[e.id]=true;local a=self.actors[e.id]
   if not a then a=actor(e.kind);a.x=e.x;self.actors[e.id]=a end
   if a.target and a.at~=s.elapsed then a.previous={x=a.target.x,at=a.at} end
   a.target=e;a.at=s.elapsed
   local fraction=math.max(0,e.hp/e.maxHp)
   a.healthGoal=fraction;if a.health==nil then a.health=fraction end
  end end
  for id,a in pairs(self.actors) do if not seen[id] then
   if s.phase=="running" and not reset then a.deathAt=s.elapsed;a.death=nil;dying[#dying+1]=a else release(a) end
   self.actors[id]=nil
  end end
  for _,p in ipairs(s.projectiles) do addShot(p,s.elapsed) end
  for id in pairs(self.seenShots) do if id<self.highestShot-256 then self.seenShots[id]=nil end end
  local visible=s.phase=="running" and s.stage=="mining"
  for i,d in ipairs(deposits) do d.Visible=visible and i<=s.stats.robots end
  for _,r in ipairs(s.robots) do
   if not self.robots[r.id] then self.robots[r.id]=newRobot(r.id) end
   local a=self.robots[r.id]
   if changed then a.previous=nil;a.x=385;a.track=0;a.deploy=0
   elseif a.target and a.at~=s.elapsed then a.previous={r=a.target,at=a.at} end
   a.target=r;a.at=s.elapsed;a.ui.Visible=visible
  end
  for id,a in pairs(self.robots) do if not visible or id>#s.robots then a.ui.Visible=false;a.target=nil end end
  if s.phase=="menu" or s.phase=="ended" then clearTransient() end
 end
 local function dispatch(e)
  if e.kind=="shot" then
   local slot=e.slot or (e.weapon=="cannon" and 1 or 2)
   self.weapons.fire(slot,e.weapon,e.x,e.y,self.renderTime)
   if e.projectile then addShot(e.projectile,e.at or self.renderTime) end
   local v=visual(e.weapon)
   if v.projectile=="beam" or v.projectile=="flame" then
    if #self.fx<limits.effectLimit then
     local x,y=self.weapons.muzzle(slot);local m=C.WeaponMounts[slot]
     local f=effect("Frame");f.BackgroundColor3=Color3.fromRGB(v.color[1],v.color[2],v.color[3]);f.BackgroundTransparency=option("flashEffects") and .05 or .55
     self.fx[#self.fx+1]={f=f,class="Frame",kind="beam",x=x or m.fireX,y=y or m.fireY,tx=e.x,ty=e.y-22,age=0,life=.18,width=v.width or 3,subtle=not option("flashEffects")}
    end
   end
  elseif e.kind=="impact" then
   local sh=e.projectileId and self.shots[e.projectileId]
   if sh and sh.late and self.renderTime<sh.p.born+sh.p.duration then
    e.at=sh.p.born+sh.p.duration;if #self.queue<limits.eventLimit then self.queue[#self.queue+1]=e end;return
   end
   if option("flashEffects") then burst(e.x,e.y,e.weapon=="acid" and "acid" or "impact") end
  elseif e.kind=="kill" then
   for _,a in ipairs(dying) do if a.target and a.target.id==e.id then a.deathAt=math.min(a.deathAt,e.at or self.renderTime) end end
   burst(e.x,e.y-65,"text","+"..e.ore.." 矿料")
  elseif e.kind=="hit" then if ctx.numbers() and e.amount>=1 and #self.fx<25 then burst(e.x,e.y-80,"text","−"..e.amount) end
  elseif e.kind=="deposit" then burst(e.x,e.y-45,"text","运回 +"..e.ore)
  elseif e.kind=="basehit" then if option("screenShake") then self.shake=.18 end
  elseif e.kind=="upgrade" then burst(455,255,"text","升级完成") end
 end
 function self.events(events)
  if #events>0 then self.visualDirty=true end
  for _,e in ipairs(events) do
   if not e.runId or not self.snap or e.runId==self.snap.runId then
    if e.kind=="upgrade" or not e.at or e.at<=self.renderTime then dispatch(e)
    elseif #self.queue<limits.eventLimit then self.queue[#self.queue+1]=e else self.dropped=self.dropped+1 end
   end
  end
 end
 local function pose(a,t,reduced,death)
  local e=a.target;if not e then return end
  local m=C.Catalog.enemyMotion[e.kind] or C.Catalog.enemyMotion.crawler
  local walking=e.x>C.Catalog.enemies[e.kind].range+.1;local phase=a.phase+e.id*1.7
  local age=t-(e.attackAt or -100);local hit=t-(e.hitAt or -100)
  local wind=age<0 and age>=-.1 and A.smooth((age+.1)/.1) or 0
  local strike=age>=0 and age<.3 and (1-A.smooth(age/.3))*9/m.weight or 0
  local bob=not reduced and math.sin(phase*2)*m.bob or 0
  a.body.Position=UDim2.fromOffset(7+(reduced and 0 or wind*3-strike),11+bob+(death or 0)*15)
  a.body.Rotation=death and death*65 or not reduced and math.sin(phase)*1.5 or 0
  a.body.Size=UDim2.fromOffset(82+(hit>=0 and hit<.1 and not reduced and 3 or 0),55-(hit>=0 and hit<.1 and not reduced and 3 or 0))
  a.flash.BackgroundTransparency=hit>=0 and hit<.1 and .15 or .9
  a.flash.Visible=option("flashEffects");a.hp.Visible=not death and option("enemyHealth")
  for i,leg in ipairs(a.legs) do
   local side=i<=3 and -1 or 1;local row=(i-1)%3
   local gait=(phase/(math.pi*2)+row/3+(side==1 and .5 or 0))%1
   local swing,lift=0,0
   if walking and not reduced then
    if gait<.62 then swing=(-.5+gait/.62)*m.stride
    else local q=(gait-.62)/.38;swing=(.5-A.smooth(q))*m.stride;lift=math.sin(q*math.pi)*m.lift end
   end
   local hx,hy=48+side*(9+row*3),43+row*4
   local kx,ky=48+side*(31+row*2)+swing*.35,47+row*6-lift*.45
   local fx,fy=48+side*(43-row*6)+swing,77-row*2-lift
   if death then fy=fy-death*22;kx=kx+side*death*9 end
   line(leg.upper,hx,hy,kx,ky,8);line(leg.lower,kx,ky,fx,fy,7);line(leg.accent,kx,ky,fx,fy,3)
  end
 end
 function self.update(dt)
  local s=self.snap;if not s then return end
  local running=s.phase=="running" and not s.paused and not s.supply
  if not running and not self.visualDirty then return end
  local step=running and math.min(dt,.1) or 0
  self.time=running and math.min(s.elapsed+(limits.maxExtrapolation or .2),self.time+step) or self.time
  if running then self.renderTime=math.max(self.renderTime,math.max(0,self.time-limits.delay)) end
  self.since=math.max(0,self.renderTime-s.elapsed)
  local t=self.renderTime;local reduced=ctx.reduced()
  self.poseClock=self.poseClock+dt;local poseDue=self.visualDirty or self.poseClock>=(reduced and 1/15 or 1/30)
  if poseDue then self.poseClock=0 end;self.visualDirty=false
  local queue=self.queue;self.queue={}
  for _,e in ipairs(queue) do if e.at<=t then dispatch(e) else self.queue[#self.queue+1]=e end end
  for _,a in pairs(self.actors) do
   local e=a.target;local oldX=a.x
   local goal=A.enemyX(a.previous,e,a.at,t,C.Catalog.enemies[e.kind].range)
   a.x=a.x+(goal-a.x)*A.alpha(28,step)
   local m=C.Catalog.enemyMotion[e.kind] or C.Catalog.enemyMotion.crawler
   a.phase=a.phase+math.abs(a.x-oldX)/m.stride*math.pi*2
   local emerge=A.smooth((t-(e.spawnAt or 0))/.32)
   a.ui.Visible=t>=(e.spawnAt or 0)
   a.ui.Position=UDim2.fromOffset(a.x,e.y+35+(1-emerge)*22)
   a.scale.Scale=(C.Catalog.enemies[e.kind].body=="tankBody" and 1.15 or .92)*(C.Catalog.enemies[e.kind].scale or 1)*(reduced and 1 or .22+.78*emerge)
   a.health=a.health+(a.healthGoal-a.health)*A.alpha(22,step)
   a.bar.Size=UDim2.new(a.health,0,1,0)
   if poseDue or not a.posed then pose(a,t,reduced,nil);a.posed=true end
  end
  for i=#dying,1,-1 do
   local a=dying[i];local age=t-a.deathAt
   if age>=.34 then release(a);table.remove(dying,i)
   elseif age>=0 then
    local q=A.smooth(age/.34)
    if poseDue then pose(a,t,reduced,q) end
    a.ui.Position=UDim2.fromOffset(a.x,a.target.y+35+q*14)
    a.scale.Scale=math.max(.12,(C.Catalog.enemies[a.kind].scale or 1)*(1-q*.85));a.hp.Visible=false
   end
  end
  for _,a in pairs(self.robots) do local r=a.target;if r then
   local source=r;local stamp=a.at
   if a.previous and t<a.at then source=a.previous.r;stamp=a.previous.at end
   local phase=A.robotPhase(source,math.max(0,t-stamp),s.stats.cycle)
   local goal,deploy,state=A.robotPath(phase,r.id);local before=a.x
   a.x=a.x+(goal-a.x)*A.alpha(30,step)
   a.track=a.track+(a.x-before)*.65
   a.deploy=a.deploy+(deploy-a.deploy)*A.alpha(24,step)
   a.ui.Position=UDim2.fromOffset(a.x,r.y+11)
   local drilling=state=="drilling";local bob=not reduced and math.sin(a.track*.6)*.65 or 0
   a.body.Position=UDim2.fromOffset(17,6+bob)
   a.body.Rotation=reduced and 0 or A.clamp((goal-a.x)*.025,-2,2)
   local vibration=drilling and not reduced and math.sin(t*65)*1.1 or 0
   a.bit.Position=UDim2.fromOffset(8*(1-a.deploy)+vibration,24+9*a.deploy)
   a.bit.Size=UDim2.fromOffset(25,drilling and not reduced and 13+math.sin(t*80)*3 or 17)
   a.bit.Rotation=drilling and not reduced and math.sin(t*48)*4 or -18*(1-a.deploy)
   line(a.arm,32,28,14+8*(1-a.deploy)+vibration,32+9*a.deploy,7)
   a.cargo.Visible=source.cargo>0;a.progress.Size=UDim2.new(phase,0,1,0)
   a.spark.Visible=drilling and not reduced and option("flashEffects") and math.sin(t*34+r.id)>0
   for i,w in ipairs(a.wheels) do w.Position=UDim2.fromOffset((i*12+a.track)%35,0) end
  end end
  for id,sh in pairs(self.shots) do
   local p=sh.p
   p.tx=p.tx+(sh.goalX-p.tx)*A.alpha(25,step);p.ty=p.ty+(sh.goalY-p.ty)*A.alpha(25,step)
   local x,y,angle,q=A.projectile(p,t)
   sh.f.Visible=t>=p.born
   if q>=1 then removeShot(id) else sh.f.Position=UDim2.fromOffset(x,y);sh.f.Rotation=angle end
  end
  self.weapons.update(s,step,t,reduced,option("flashEffects"))
  ctx.turret.Visible=false;ctx.muzzle.Visible=false;ctx.auxiliary.Visible=false
  self.shake=math.max(0,self.shake-step)
  ctx.base.Position=UDim2.fromOffset(242+(not reduced and option("screenShake") and self.shake>0 and math.sin(t*70)*self.shake*15 or 0),188)
  for i=#self.fx,1,-1 do
   local e=self.fx[i];e.age=e.age+step;local q=e.age/e.life
   if q>=1 then e.f.Parent=nil;self.fxPool[e.class][#self.fxPool[e.class]+1]=e.f;table.remove(self.fx,i)
   elseif e.kind=="text" then e.f.Position=UDim2.fromOffset(e.x,e.y-A.smooth(q)*35);e.f.TextTransparency=q*q
   elseif e.kind=="beam" then line(e.f,e.x,e.y,e.tx,e.ty,e.width*(1-q*.6));e.f.BackgroundTransparency=(e.subtle and .55 or .05)+q*(e.subtle and .45 or .95)
   else local size=e.kind=="smoke" and 9+q*25 or 8+q*42;e.f.Size=UDim2.fromOffset(size,size);e.f.Position=UDim2.fromOffset(e.x,e.y-(e.kind=="smoke" and q*28 or 0));e.f.BackgroundTransparency=q end
  end
 end
 function self.prewarm(checkpoint)
  self.weapons.configure({loadout="machine"})
  local reserve={}
  for _,kind in ipairs({"crawler","crawler","tank"}) do local a=actor(kind);a.ui.Visible=false;reserve[#reserve+1]=a;if checkpoint then checkpoint() end end
  for _,a in ipairs(reserve) do release(a) end
  for id=1,2 do if not self.robots[id] then self.robots[id]=newRobot(id);self.robots[id].ui.Visible=false end;if checkpoint then checkpoint() end end
  for _,class in ipairs({"Frame","TextLabel"}) do
   local batch={};for i=1,8 do batch[i]=effect(class) end
   for _,f in ipairs(batch) do f.Parent=nil;self.fxPool[class][#self.fxPool[class]+1]=f end
   if checkpoint then checkpoint() end
  end
 end
 function self.destroy()
  clearTransient();self.weapons.destroy()
  for _,a in pairs(self.actors) do a.ui:Destroy() end;self.actors={}
  for _,a in pairs(self.robots) do a.ui:Destroy() end;self.robots={}
  for _,d in ipairs(deposits) do d:Destroy() end
  for _,pool in pairs(self.pool) do for _,a in ipairs(pool) do a.ui:Destroy() end end
  for _,pool in pairs(self.fxPool) do for _,f in ipairs(pool) do f:Destroy() end end
  self.pool={};self.fxPool={}
 end
 return self
end
return Motion
