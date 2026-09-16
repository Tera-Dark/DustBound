-- Articulated GUI rigs, server projectile interpolation and pooled feedback.
-- Images are static shared atlas regions; only transforms change per render frame.
local Motion={}
function Motion.new(ctx)
 local self={actors={},pool={},shots={},robots={},fx={},fxPool={},time=0,since=0,recoil=0,recoilV=0,shake=0,angle=0}
 local frame,corner,Art,C=ctx.frame,ctx.corner,ctx.Art,ctx.C;local c=ctx.colors
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
  a.death=nil;a.target=nil;return a
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
  if #self.fx>=56 then return end
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
  return {ui=ui,body=body,arm=arm,bit=bit,wheels=wheels,cargo=cargo,progress=progress,spark=spark,x=385}
 end
 local deposits={}
 for i=1,5 do deposits[i]=Art.sprite(ctx.robotLayer,"crystal",725+(i-1)*112,444+(i%2)*17,39,46);deposits[i].Visible=false end
 function self.sync(s)
  self.snap=s;self.since=0;self.time=s.elapsed
  local seen={}
  for i,e in ipairs(s.enemies) do if Art.mode~="fallback" or i<=12 then
   seen[e.id]=true;local a=self.actors[e.id]
   if not a then a=actor(e.kind);a.x=e.x;self.actors[e.id]=a end
   a.target=e;a.bar.Size=UDim2.new(math.max(0,e.hp/e.maxHp),0,1,0)
  end end
  for id,a in pairs(self.actors) do if not seen[id] then
   if s.phase=="running" and s.stage~="mining" then a.death=0;dying[#dying+1]=a else release(a) end
   self.actors[id]=nil
  end end
  local shotSeen={}
  for _,p in ipairs(s.projectiles) do
   shotSeen[p.id]=true;local sh=self.shots[p.id]
   if not sh then
    local f=effect("Frame");f.BackgroundColor3=p.weapon=="acid" and c.mint or p.weapon=="rail" and c.cream or c.gold;f.BackgroundTransparency=0
    sh={f=f};self.shots[p.id]=sh
   end
   sh.target=p
  end
  for id,sh in pairs(self.shots) do if not shotSeen[id] then sh.f.Parent=nil;self.fxPool.Frame[#self.fxPool.Frame+1]=sh.f;self.shots[id]=nil end end
  local visible=s.phase=="running" and s.stage=="mining"
  for i,d in ipairs(deposits) do d.Visible=visible and i<=s.stats.robots end
  for _,r in ipairs(s.robots) do
   if not self.robots[r.id] then self.robots[r.id]=newRobot(r.id) end
   local a=self.robots[r.id];a.target=r;a.ui.Visible=visible
  end
  for id,a in pairs(self.robots) do if not visible or id>#s.robots then a.ui.Visible=false;a.target=nil end end
  if s.phase=="menu" or s.phase=="ended" then
   for _,a in ipairs(dying) do release(a) end;dying={}
   for _,e in ipairs(self.fx) do e.f.Parent=nil;self.fxPool[e.class][#self.fxPool[e.class]+1]=e.f end;self.fx={}
  end
 end
 function self.events(events)
  for _,e in ipairs(events) do
   if e.kind=="shot" then
    if e.weapon=="cannon" then self.recoilV=self.recoilV+75;if not ctx.reduced() then burst(565,146,"smoke") end end
    if e.weapon=="arc" or e.weapon=="flame" then
     if #self.fx<48 then
      local f=effect("Frame");f.BackgroundColor3=e.weapon=="arc" and c.mint or c.orange;f.BackgroundTransparency=.05
      self.fx[#self.fx+1]={f=f,class="Frame",kind="beam",x=602,y=275,tx=e.x,ty=e.y-23,age=0,life=.16,width=e.weapon=="arc" and 3 or 12}
     end
    end
   elseif e.kind=="impact" then burst(e.x,e.y,e.weapon=="acid" and "acid" or "impact")
   elseif e.kind=="kill" then burst(e.x,e.y-65,"text","+"..e.ore.." 矿料")
   elseif e.kind=="hit" then if ctx.numbers() and not ctx.reduced() and e.amount>=1 and #self.fx<25 then burst(e.x,e.y-80,"text","−"..e.amount) end
   elseif e.kind=="deposit" then burst(e.x,e.y-45,"text","运回 +"..e.ore)
   elseif e.kind=="basehit" then self.shake=.18
   elseif e.kind=="upgrade" then burst(455,255,"text","升级完成") end
  end
 end
 local function pose(a,t,reduced,death)
  local e=a.target;if not e then return end
  local walking=e.x>C.Catalog.enemies[e.kind].range+.1
  local phase=t*(walking and e.speed*.25 or 2)+e.id*2
  local attackAge=t-(e.attackAt or -100);local hitAge=t-(e.hitAt or -100)
  local lunge=attackAge>=0 and attackAge<.38 and math.sin(attackAge/.38*math.pi)*9 or 0
  local bob=not reduced and math.sin(phase*2)*1.4 or 0
  a.body.Position=UDim2.fromOffset(7-(reduced and 0 or lunge),11+bob+(death or 0)*25)
  a.body.Rotation=death and death*75 or not reduced and math.sin(phase)*2 or 0
  a.body.Size=UDim2.fromOffset(82+(hitAge<.12 and not reduced and 4 or 0),55-(hitAge<.12 and not reduced and 4 or 0))
  a.flash.BackgroundTransparency=hitAge<.12 and .15 or .9
  a.hp.Visible=not death
  for i,leg in ipairs(a.legs) do
   local side=i<=3 and -1 or 1;local row=(i-1)%3;local gait=phase+row*2.1+(side==1 and math.pi or 0)
   local swing=walking and not reduced and math.sin(gait)*10 or 0
   local lift=walking and not reduced and math.max(0,math.cos(gait))*10 or 0
   local hx,hy=48+side*(9+row*3),43+row*4
   local kx,ky=48+side*(31+row*2)+swing*.4,47+row*6-lift*.5
   local fx,fy=48+side*(43-row*6)+swing,77-row*2-lift
   if death then fy=fy-death*25;kx=kx+side*death*10 end
   line(leg.upper,hx,hy,kx,ky,8);line(leg.lower,kx,ky,fx,fy,7);line(leg.accent,kx,ky,fx,fy,3)
  end
 end
 function self.update(dt)
  local s=self.snap;if not s then return end
  local running=s.phase=="running" and not s.paused and not s.supply
  local step=running and math.min(dt,.05) or 0
  self.since=math.min(.25,self.since+step);local t=s.elapsed+self.since;local reduced=ctx.reduced()
  for _,a in pairs(self.actors) do
   local e=a.target;local target=e.x
   if running then target=math.max(C.Catalog.enemies[e.kind].range,e.x-e.speed*self.since);a.x=a.x+(target-a.x)*math.min(1,dt*18) end
   local emerge=math.min(1,math.max(.1,(t-(e.spawnAt or 0))/.35))
   a.ui.Position=UDim2.fromOffset(a.x,e.y+35+(1-emerge)*28)
   a.scale.Scale=(C.Catalog.enemies[e.kind].body=="tankBody" and 1.15 or .92)*(C.Catalog.enemies[e.kind].scale or 1)*(reduced and 1 or emerge)
   pose(a,t,reduced,nil)
  end
  for i=#dying,1,-1 do local a=dying[i];a.death=a.death+step
   if a.death>.35 then release(a);table.remove(dying,i) else pose(a,t,reduced,a.death/.35);a.scale.Scale=math.max(.1,a.scale.Scale-step*2) end
  end
  for _,a in pairs(self.robots) do local r=a.target;if r then
   if running then a.x=a.x+(r.x-a.x)*math.min(1,dt*18) else a.x=r.x end
   a.ui.Position=UDim2.fromOffset(a.x,r.y+11)
   local drilling=r.state=="drilling";local vibration=drilling and not reduced and math.sin(t*67)*1.6 or 0
   a.body.Rotation=not reduced and math.sin(t*(drilling and 38 or 16)+r.id)*1.5 or 0
   a.bit.Position=UDim2.fromOffset(vibration,33);a.bit.Rotation=drilling and math.sin(t*40)*9 or 0
   line(a.arm,32,28,14+vibration,41,7)
   a.cargo.Visible=r.cargo>0;a.progress.Size=UDim2.new(r.t,0,1,0)
   a.spark.Visible=drilling and not reduced and math.sin(t*60)>0
   for i,w in ipairs(a.wheels) do w.Position=UDim2.fromOffset((i*12+(drilling and 0 or t*22))%35,0) end
  end end
  for _,sh in pairs(self.shots) do local p=sh.target
   local q=math.min(1,(p.age+self.since)/p.duration);local dx,dy=p.tx-p.x,p.ty-p.y
   local arc=(p.weapon=="mortar" and 160 or p.weapon=="cannon" and 48 or 0)
   local x,y=p.x+dx*q,p.y+dy*q-4*arc*q*(1-q)
   sh.f.Position=UDim2.fromOffset(x,y);sh.f.Rotation=math.deg(math.atan2(dy-4*arc*(1-2*q),dx))
   sh.f.Size=UDim2.fromOffset(p.weapon=="rail" and 40 or p.weapon=="machine" and 21 or 17,p.weapon=="machine" and 3 or 7)
  end
  -- Damped spring recoil and tracking pivot, rather than swapping two still positions.
  if step>0 then
   self.recoilV=self.recoilV+(-130*self.recoil-20*self.recoilV)*step;self.recoil=self.recoil+self.recoilV*step;self.shake=math.max(0,self.shake-step)
   local enemy=s.enemies[1];local desired=enemy and math.deg(math.atan2(enemy.y-170,enemy.x-500))*.4 or 0
   self.angle=self.angle+(desired-self.angle)*math.min(1,dt*9)
  end
  ctx.turret.Position=UDim2.fromOffset(412-(reduced and 0 or self.recoil),110);ctx.turret.Rotation=self.angle
  ctx.muzzle.Visible=not reduced and self.recoil>1;ctx.muzzle.Rotation=t*360
  ctx.base.Position=UDim2.fromOffset(242+(not reduced and self.shake>0 and math.sin(t*80)*3 or 0),188)
  ctx.auxiliary.BackgroundTransparency=.2+math.sin(t*4)*.12
  for i=#self.fx,1,-1 do local a=self.fx[i];a.age=a.age+step;local q=a.age/a.life
   if q>=1 then a.f.Parent=nil;self.fxPool[a.class][#self.fxPool[a.class]+1]=a.f;table.remove(self.fx,i)
   else
    if a.kind=="text" then a.f.Position=UDim2.fromOffset(a.x,a.y-q*35);a.f.TextTransparency=q
    elseif a.kind=="beam" then line(a.f,a.x,a.y,a.tx,a.ty,a.width);a.f.BackgroundTransparency=q
    else local size=a.kind=="smoke" and 9+q*25 or 8+q*45;a.f.Size=UDim2.fromOffset(size,size);a.f.Position=UDim2.fromOffset(a.x,a.y-(a.kind=="smoke" and q*28 or 0));a.f.BackgroundTransparency=q end
   end
  end
 end
 return self
end
return Motion
