-- Layered side-lane battlefield presentation. Server snapshots own movement/damage/gold.
local A=require(script.Parent.Animation)
local W=require(script.Parent.WeaponRig)
local B={}
function B.new(ctx,parent)
 local U,C,Art=ctx.U,ctx.C,ctx.Art;local c=U.colors
 local self={actors={},pools={},robots={},shots={},seen={},fx={},fxPool={},time=0,snap=nil,pose=0}
 local world=U.frame(parent,"WideBattlefield",720,390,1440,650,nil,1);world.AnchorPoint=Vector2.new(.5,.5)
 local camera=Instance.new("UIScale");camera.Scale=.94;camera.Parent=world
 self.world=world
 -- No opaque rounded playfield: characters stand directly in the landscape.
 local floor=U.frame(world,"OutpostFootprint",596,396,248,30,c.shadow,.76);U.corner(floor,15)
 for _,side in ipairs({-1,1}) do
  for i=1,3 do
   local x=720+side*(320+(i-1)*45)
   Art.sprite(world,"crystal",x-15,411+(i-1)*24,38,52)
  end
  local marker=U.panel(world,"Approach"..side,side<0 and 32 or 1223,306,185,30,c.cream)
  U.text(marker,"Label",side<0 and "地面信号  >>>" or "<<<  地面信号",8,0,169,30,13,c.gold,true)
  local mine=U.panel(world,"MineLabel"..side,side<0 and 275 or 990,539,177,29,c.cream)
  U.text(mine,"Text","矿脉 / AU-"..(side<0 and "01" or "02"),10,0,157,29,12,c.mint,true)
 end
 local air=U.panel(world,"AirWarning",566,84,308,30,c.cream)
 U.text(air,"Label","空域监测 / 第 3 波起空袭",12,0,284,30,13,c.mint,true)
 self.air=air
 local base=Art.sprite(world,"base",598,254,244,160)
 local robots=U.frame(world,"MiningRobots",0,0,1440,650,nil,1)
 local enemies=U.frame(world,"Invaders",0,0,1440,650,nil,1)
 local mounts=U.frame(world,"WeaponMounts",0,0,1440,650,nil,1)
 local fxLayer=U.frame(world,"CombatEffects",0,0,1440,650,nil,1)
 local wc={};for k,v in pairs(c) do wc[k]=v end
 wc.ink=c.shadow;wc.cream=Color3.fromRGB(237,226,192);wc.paper=Color3.fromRGB(157,183,165)
 self.rig=W.new({C=C,Art=Art,colors=wc,frame=U.frame,corner=U.corner,weaponLayer=mounts,fxLayer=fxLayer})
 local function actor(kind)
  self.pools[kind]=self.pools[kind] or {};local a=table.remove(self.pools[kind])
  if a then a.root.Parent=enemies;a.root.Visible=true;return a end
  local root=U.frame(enemies,"Enemy_"..kind,0,0,84,76,nil,1);root.AnchorPoint=Vector2.new(.5,.5)
  local model=U.frame(root,"BodyRig",0,0,84,76,nil,1);local legs={}
  local shadow=U.frame(root,"ContactShadow",9,58,66,12,c.shadow,.7);U.corner(shadow,6)
  local wings={}
  if kind=="flyer" then
   shadow.Position=UDim2.fromOffset(15,112);shadow.BackgroundTransparency=.87
   local left=Art.sprite(model,"flyerWing",-24,-6,60, 40)
   local right=Art.sprite(model,"flyerWing",48,-6,60,40);right.Rotation=180
   wings={left,right}
  else
   for i=1,6 do
    local leg=U.frame(model,"Leg"..i,14+(i-1)%3*19,i<=3 and 39 or 48,8,20,c.shadow);U.corner(leg,3);legs[i]=leg
   end
  end
  local body=Art.sprite(model,kind=="flyer" and "flyerBody" or kind=="tank" and "tankBody" or kind=="runner" and "runnerBody" or "crawlerBody",9,6,66,50)
  local hp=U.frame(root,"HealthTrack",14,-9,56,4,c.shadow,.25);local bar=U.frame(hp,"Health",0,0,56,5,c.orange)
  a={root=root,model=model,body=body,legs=legs,wings=wings,shadow=shadow,hp=hp,bar=bar,x=0,y=0,kind=kind};return a
 end
 local function recycle(a)
  a.root.Parent=nil;self.pools[a.kind]=self.pools[a.kind] or {};self.pools[a.kind][#self.pools[a.kind]+1]=a
 end
 local function effect()
  local f=table.remove(self.fxPool)
  if not f then f=U.frame(fxLayer,"PooledEffect",0,0,12,12,c.gold);U.corner(f,6) end
  f.Parent=fxLayer;f.Visible=true;f.AnchorPoint=Vector2.new(.5,.5);f.Rotation=0;f.BackgroundTransparency=0;f.BackgroundColor3=c.gold;return f
 end
 local function release(f) f.Parent=nil;self.fxPool[#self.fxPool+1]=f end
 local function shot(p)
  if self.shots[p.id] then self.shots[p.id].p.tx=p.tx;self.shots[p.id].p.ty=p.ty;return end
  if self.seen[p.id] then return end
  local count=0;for _ in pairs(self.shots) do count=count+1 end;if count>=80 then return end
  self.seen[p.id]=true
  local born=p.born or self.time;local duration=p.duration or .2
  if born+duration<self.time then born=self.time;duration=.09 end
  local v=C.Catalog.weapons[p.weapon].visual
  self.shots[p.id]={f=effect(),p={x=p.x,y=p.y,tx=p.tx,ty=p.ty,born=born,duration=duration,arc=v.arc or 0}}
  self.shots[p.id].f.Size=UDim2.fromOffset(v.length or 17,v.width or 5)
 end
 function self.sync(s)
  local reset=not self.snap or self.snap.runId~=s.runId
  if reset then
   for _,r in pairs(self.robots) do r.root.Visible=false;r.r=nil end
   for id,a in pairs(self.actors) do recycle(a);self.actors[id]=nil end
   for id,p in pairs(self.shots) do release(p.f);self.shots[id]=nil end
   for _,e in ipairs(self.fx) do release(e.f) end;self.fx={};self.seen={};self.rig.reset();self.time=s.elapsed
  end
  self.snap=s;self.time=math.max(self.time,s.elapsed);world.Visible=s.phase~="menu";self.rig.configure(s)
  local seen={}
  for _,e in ipairs(s.enemies) do
   local a=self.actors[e.id];if not a then a=actor(e.kind);a.x=e.x;a.y=e.y;self.actors[e.id]=a end
   a.e=e;seen[e.id]=true
  end
  for id,a in pairs(self.actors) do if not seen[id] then recycle(a);self.actors[id]=nil end end
  for _,p in ipairs(s.projectiles) do shot(p) end
  local high=0;for id in pairs(self.seen) do high=math.max(high,id) end
  for id in pairs(self.seen) do if id<high-256 then self.seen[id]=nil end end
  for _,r in ipairs(s.robots) do
   if not self.robots[r.id] then
    local root=U.frame(robots,"Robot"..r.id,r.x,r.y,66,66,nil,1);root.AnchorPoint=Vector2.new(.5,.5)
    local model=U.frame(root,"MiningRig",0,0,66,66,nil,1)
    local shadow=U.frame(root,"GroundShadow",8,56, 50,9,c.shadow,.76);U.corner(shadow,5)
    local tread=U.frame(model,"Tread",13,43,40,13,c.shadow);U.corner(tread,6)
    local wheels={};for i=1,3 do local wheel=U.frame(tread,"Wheel"..i,3+(i-1)*12,3,8,7,c.muted);U.corner(wheel,4);wheels[i]=wheel end
    Art.sprite(model,"robot",9,0,46,50);local bit=Art.sprite(model,"drillBit",39,39,24,14)
    local load=Art.sprite(model,"crystal",3,-6,24,30);load.Visible=false
    local label=U.text(root,"RobotState","出库",-24,-25,114,24,12,c.shadow,true,Enum.TextXAlignment.Center)
    local track=U.frame(root,"DigTrack",8,67,50,4,c.shadow,.35)
    local bar=U.frame(track,"DigProgress",0,0,1,4,c.mint)
    local dust={};for i=1,5 do local f=U.frame(root,"DrillDust"..i,50,48,4,4,c.gold);U.corner(f,2);f.Visible=false;dust[i]=f end
    self.robots[r.id]={root=root,model=model,bit=bit,wheels=wheels,load=load,label=label,track=track,bar=bar,dust=dust,x=r.x,y=r.y}
   end
   local a=self.robots[r.id];a.r=r;a.root.Visible=true
   if reset then a.x=r.x;a.y=r.y end
  end
  local robotIds={};for _,r in ipairs(s.robots) do robotIds[r.id]=true end
  for id,a in pairs(self.robots) do if not robotIds[id] then a.root.Visible=false;a.r=nil end end
  air.Visible=s.wave>=3
 end
 function self.events(events)
  if not self.snap then return end
  local opts=self.snap.profile.settings
  for _,e in ipairs(events) do if e.runId==self.snap.runId then
   if e.kind=="shot" then
    self.rig.fire(e.slot or 1,e.weapon,e.x,e.y,self.time)
    if e.projectile then shot(e.projectile)
    elseif #self.fx<40 then
     local x,y=self.rig.muzzle(e.slot or 1);self.fx[#self.fx+1]={f=effect(),x=x or 720,y=y or 340,tx=e.x,ty=e.y,age=0,life=.16,beam=true}
    end
   elseif e.kind=="deposit" and #self.fx<40 then
    self.fx[#self.fx+1]={f=effect(),x=720,y=423,age=0,life=.7,deposit=true}
    self.fx[#self.fx].f.BackgroundColor3=c.mint
   elseif e.kind=="enemyattack" and #self.fx<40 then
    self.fx[#self.fx+1]={f=effect(),x=e.x,y=e.y,tx=e.tx,ty=e.ty,age=0,life=.23,beam=e.enemyKind=="flyer"}
    self.fx[#self.fx].f.BackgroundColor3=c.red
   elseif e.kind=="impact" and opts.flashEffects and #self.fx<40 then
    self.fx[#self.fx+1]={f=effect(),x=e.x,y=e.y,age=0,life=.22}
   end
  end end
 end
 function self.update(dt)
  local s=self.snap;if not s then return end
  local live=s.phase=="running" and not s.paused and not s.supply
  if not live then return end
  dt=math.min(dt,.1)
  self.time=math.min(s.elapsed+.2,self.time+dt);self.pose=self.pose+dt
  local opts=s.profile.settings;local pose=self.pose>(opts.reducedMotion and 1/15 or 1/30);if pose then self.pose=0 end
  for _,a in pairs(self.actors) do
   local e=a.e;local extra=math.min(.15,math.max(0,self.time-s.elapsed))
   a.x=a.x+((e.x+(e.vx or 0)*extra)-a.x)*A.alpha(22,dt)
   a.y=a.y+((e.y+(e.vy or 0)*extra)-a.y)*A.alpha(22,dt)
   local bob=a.kind=="flyer" and not opts.reducedMotion and math.sin(self.time*5+e.id)*5 or 0
   a.root.Position=UDim2.fromOffset(a.x,a.y+bob);a.hp.Visible=opts.enemyHealth
   a.bar.Size=UDim2.new(math.max(0,e.hp/e.maxHp),0,1,0)
   if pose then
    a.model.Rotation=a.kind=="flyer" and math.deg(math.atan2(210-a.y,720-a.x))-90 or 0
    a.body.Rotation=0 -- Keep ground silhouettes upright on both approaches.
    for i,wing in ipairs(a.wings) do wing.Rotation=(i==2 and 180 or 0)+(opts.reducedMotion and 0 or math.sin(self.time*24+e.id)*(i==1 and 28 or -28)) end
    if a.kind~="flyer" and not opts.reducedMotion then a.model.Position=UDim2.fromOffset(0,math.sin(self.time*10+e.id)*1.7) end
    for i,leg in ipairs(a.legs) do leg.Rotation=opts.reducedMotion and 0 or math.sin(self.time*(a.kind=="runner" and 16 or 8)+i*2+e.id)*18 end
   end
  end
  for _,a in pairs(self.robots) do if a.r then
   a.x=a.x+(a.r.x-a.x)*A.alpha(22,dt);a.y=a.y+(a.r.y-a.y)*A.alpha(22,dt)
   local r=a.r;local drilling=r.state=="drilling";local moving=not drilling and (r.delay or 0)<=0
   a.root.Position=UDim2.fromOffset(a.x,a.y)
   a.model.Position=UDim2.fromOffset(drilling and not opts.reducedMotion and math.sin(self.time*55)*1.5 or 0,moving and not opts.reducedMotion and math.sin(self.time*18+r.id)*1.5 or 0)
   local side=(r.mineX or 1040)<720 and -1 or 1
   a.bit.Position=UDim2.fromOffset(side<0 and -2 or 39,39)
   a.bit.Rotation=(side<0 and 180 or 0)+(drilling and not opts.reducedMotion and math.sin(self.time*45)*18 or 0)
   a.load.Visible=(r.cargo or 0)>0;a.track.Visible=drilling
   a.bar.Size=UDim2.new(r.progress or 0,0,1,0)
   local label=drilling and "钻探 "..math.floor((r.progress or 0)*100).."%" or r.state=="returning" and "返航 +"..(r.cargo or 0) or "前往矿脉"
   if a.label.Text~=label then a.label.Text=label end
   if pose then for i,w in ipairs(a.wheels) do w.Rotation=moving and not opts.reducedMotion and self.time*300 or 0 end end
   for i,f in ipairs(a.dust) do
    f.Visible=drilling and not opts.reducedMotion
    if f.Visible then local q=(self.time*2+i*.21)%1;f.Position=UDim2.fromOffset((side<0 and 1 or  60)+side*q*(10+i*2),49-q*26+q*q*22);f.BackgroundTransparency=q end
   end
  end end
  for id,p in pairs(self.shots) do
   local x,y,angle,q=A.projectile(p.p,self.time)
   if q>=1 then release(p.f);self.shots[id]=nil else p.f.Position=UDim2.fromOffset(x,y);p.f.Rotation=angle end
  end
  for i=#self.fx,1,-1 do local e=self.fx[i];e.age=e.age+dt;local q=e.age/e.life
   if q>=1 then release(e.f);table.remove(self.fx,i)
   elseif e.deposit then e.f.Size=UDim2.fromOffset(10,10);e.f.Position=UDim2.fromOffset(e.x,e.y-q*50);e.f.BackgroundTransparency=q
   elseif e.beam then
    local dx,dy=e.tx-e.x,e.ty-e.y;e.f.Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy),3);e.f.Position=UDim2.fromOffset((e.x+e.tx)/2,(e.y+e.ty)/2);e.f.Rotation=math.deg(math.atan2(dy,dx));e.f.BackgroundTransparency=.4+q*.6
   else e.f.Size=UDim2.fromOffset(8+q*26,8+q*26);e.f.Position=UDim2.fromOffset(e.x,e.y);e.f.BackgroundTransparency=q end
  end
  self.rig.update(s,dt,self.time,opts.reducedMotion,opts.flashEffects)
  base.Position=UDim2.fromOffset(598,254)
 end
 function self.destroy()
  self.rig.destroy();world:Destroy()
  for _,pool in pairs(self.pools) do for _,a in ipairs(pool) do a.root:Destroy() end end
  for _,f in ipairs(self.fxPool) do f:Destroy() end
 end
 return self
end
return B
