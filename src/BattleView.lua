-- Bounded 2D radial battlefield presentation. Server snapshots own movement/damage/gold.
local A=require(script.Parent.Animation)
local W=require(script.Parent.WeaponRig)
local B={}
function B.new(ctx,parent)
 local U,C,Art=ctx.U,ctx.C,ctx.Art;local c=U.colors
 local self={actors={},pools={},robots={},shots={},seen={},fx={},fxPool={},time=0,snap=nil,pose=0}
 local world=U.frame(parent,"WideBattlefield",720,359,1440,650,nil,1);world.AnchorPoint=Vector2.new(.5,.5)
 local camera=Instance.new("UIScale");camera.Scale=.79;camera.Parent=world
 self.world=world
 local ground=U.frame(world,"RadialGround",0,0,1440,650,c.paper,.08);U.corner(ground,55);U.outline(ground,2,c.ink)
 local base=Art.sprite(world,"base",598,254,244,160)
 local robots=U.frame(world,"MiningRobots",0,0,1440,650,nil,1)
 local enemies=U.frame(world,"Invaders",0,0,1440,650,nil,1)
 local mounts=U.frame(world,"WeaponMounts",0,0,1440,650,nil,1)
 local fxLayer=U.frame(world,"CombatEffects",0,0,1440,650,nil,1)
 self.rig=W.new({C=C,Art=Art,colors=c,frame=U.frame,corner=U.corner,weaponLayer=mounts,fxLayer=fxLayer})
 local function actor(kind)
  self.pools[kind]=self.pools[kind] or {};local a=table.remove(self.pools[kind])
  if a then a.root.Parent=enemies;a.root.Visible=true;return a end
  local root=U.frame(enemies,"Enemy_"..kind,0,0,84,76,nil,1);root.AnchorPoint=Vector2.new(.5,.5)
  local model=U.frame(root,"BodyRig",0,0,84,76,nil,1);local legs={}
  for i=1,6 do
   local leg=U.frame(model,"Leg"..i,i<=3 and 5 or 65,17+(i-1)%3*13,16,6,c.ink);U.corner(leg,3);legs[i]=leg
  end
  local body=Art.sprite(model,kind=="tank" and "tankBody" or "crawlerBody",12,12,60,43)
  if kind=="flyer" then
   for i=1,2 do local wing=U.frame(model,"Wing"..i,i==1 and 1 or 65,7,19,41,c.mint,.18);U.corner(wing,12);legs[#legs+1]=wing end
   U.text(root,"FlyingLabel","空中",14,-18,60,20,13,c.ink,true,Enum.TextXAlignment.Center)
  end
  local hp=U.frame(root,"HealthTrack",14,69,56,5,c.ink,.25);local bar=U.frame(hp,"Health",0,0,56,5,c.orange)
  a={root=root,model=model,body=body,legs=legs,hp=hp,bar=bar,x=0,y=0,kind=kind};return a
 end
 local function recycle(a)
  a.root.Parent=nil;self.pools[a.kind]=self.pools[a.kind] or {};self.pools[a.kind][#self.pools[a.kind]+1]=a
 end
 local function effect()
  local f=table.remove(self.fxPool)
  if not f then f=U.frame(fxLayer,"PooledEffect",0,0,12,12,c.gold);U.corner(f,6) end
  f.Parent=fxLayer;f.Visible=true;f.AnchorPoint=Vector2.new(.5,.5);f.Rotation=0;f.BackgroundTransparency=0;return f
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
    Art.sprite(root,"robot",9,2,46,50);local bit=Art.sprite(root,"drillBit",39,39,24,14)
    self.robots[r.id]={root=root,bit=bit,x=r.x,y=r.y}
   end
   local a=self.robots[r.id];a.r=r;a.root.Visible=true
  end
  for id,a in pairs(self.robots) do if not s.robots[id] then a.root.Visible=false;a.r=nil end end
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
    a.model.Rotation=math.deg(math.atan2(340-a.y,720-a.x))+180
    for i,leg in ipairs(a.legs) do leg.Rotation=opts.reducedMotion and 0 or math.sin(self.time*(a.kind=="flyer" and 18 or 8)+i*2+e.id)*18 end
   end
  end
  for _,a in pairs(self.robots) do if a.r then
   a.x=a.x+(a.r.x-a.x)*A.alpha(22,dt);a.y=a.y+(a.r.y-a.y)*A.alpha(22,dt)
   a.root.Position=UDim2.fromOffset(a.x,a.y);a.bit.Rotation=a.r.state=="drilling" and not opts.reducedMotion and math.sin(self.time*45)*12 or 0
  end end
  for id,p in pairs(self.shots) do
   local x,y,angle,q=A.projectile(p.p,self.time)
   if q>=1 then release(p.f);self.shots[id]=nil else p.f.Position=UDim2.fromOffset(x,y);p.f.Rotation=angle end
  end
  for i=#self.fx,1,-1 do local e=self.fx[i];e.age=e.age+dt;local q=e.age/e.life
   if q>=1 then release(e.f);table.remove(self.fx,i)
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
