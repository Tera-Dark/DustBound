-- Data-driven 2D mounts and gun silhouettes. No combat or inventory authority.
local A=require(script.Parent.Animation)
local W={builders={}}
function W.registerModel(name,builder) assert(type(name)=="string" and type(builder)=="function");W.builders[name]=builder end
local function buildModel(ctx,parent,visual)
 local c=ctx.colors
 local function block(name,x,y,w,h,color,round)
  local f=ctx.frame(parent,name,90+x,54+y,w,h,color or c.ink)
  if round then ctx.corner(f,round) end
  return f
 end
 if visual.imageId and visual.imageId>0 then
  local image=Instance.new("ImageLabel");image.Name="CustomWeaponArt";image.BackgroundTransparency=1
  image.Position=UDim2.fromOffset(90+(visual.imageX or -28),54+(visual.imageY or -24));image.Size=UDim2.fromOffset(visual.imageW or 90,visual.imageH or 48)
  image.Image="rbxassetid://"..visual.imageId;image.Rotation=visual.restRotation or 0;image.Parent=parent
  return
 end
 if visual.sprite then
  local sprite=ctx.Art.sprite(parent,visual.sprite,16,-2,162,103);sprite.Rotation=visual.restRotation or 0;return
 end
 local color=Color3.fromRGB(visual.color[1],visual.color[2],visual.color[3])
 local builder=W.builders[visual.model] or W.builders.ballistic
 builder(block,c,color)
end
W.registerModel("ballistic",function(b,c,color)
 b("HousingOutline",-26,-15,51,29,c.ink,7);b("Housing",-22,-11,41,21,c.cream,5)
 b("Barrel",15,-8,26,13,c.ink,3);b("BarrelInset",18,-4,21,5,c.paper,2)
 b("Magazine",-8,9,16,14,c.ink,3);b("MagazineInset",-5,11,10,9,c.orange,2);b("Status",-17,-6,13,4,color,2)
end)
W.registerModel("coil",function(b,c,color)
 b("Capacitor",-27,-16,42,32,c.ink,12);b("Core",-23,-12,34,24,c.paper,10)
 b("Emitter",8,-8,24,16,c.ink,4)
 for i=0,2 do b("Coil"..i,1+i*9,-17,5,34,color,3) end
end)
W.registerModel("rail",function(b,c,color)
 b("Breech",-29,-13,41,26,c.ink,5);b("BreechInset",-25,-9,31,18,c.cream,4)
 for _,y in ipairs({-12,7}) do b("Rail",5,y,46,6,c.ink,2);b("Conductor",7,y+1,41,3,color,1) end
 b("Chamber",-20,-4,17,8,c.orange,2)
end)
W.registerModel("flame",function(b,c,color)
 b("Tank",-27,-20,22,39,c.ink,10);b("TankInset",-23,-16,14,31,c.orange,7)
 b("Body",-10,-12,39,24,c.ink,6);b("BodyInset",-6,-8,28,16,c.cream,4)
 b("Nozzle",24,-15,19,30,c.ink,4);b("HotTip",36,-11,6,22,color,2)
end)
W.registerModel("mortar",function(b,c,color)
 b("Chamber",-23,-21,39,42,c.ink,10);b("ChamberInset",-19,-17,31,34,c.paper,8)
 b("Tube",3,-17,30,34,c.ink,5);b("TubeInset",5,-12,22,24,c.cream,3);b("Mouth",26,-21,10,42,c.ink,4)
 b("Band",4,-18,7,36,color,2)
end)
function W.new(ctx)
 local self={slots={},time=0,activeCount=0}
 local parent=ctx.weaponLayer or ctx.fxLayer
 for i,m in ipairs(ctx.C.WeaponMounts) do
  local mount=ctx.frame(parent,"WeaponMount"..i,m.x,m.y,180,108,nil,1);mount.AnchorPoint=Vector2.new(.5,.5)
  local scale=Instance.new("UIScale");scale.Scale=m.scale or (i==1 and 1 or .85);scale.Parent=mount
  local gun=ctx.frame(mount,"RecoilAssembly",0,0,180,108,nil,1)
  local empty=ctx.frame(parent,"ReservedMount"..i,m.x-17,m.y-11,34,22,ctx.colors.ink,.12);ctx.corner(empty,7)
  local text=Instance.new("TextLabel");text.Name="SlotNumber";text.BackgroundTransparency=1;text.Size=UDim2.fromScale(1,1)
  text.Text=string.format("%02d",i);text.TextSize=12;text.Font=Enum.Font.GothamBold;text.TextColor3=ctx.colors.cream;text.Parent=empty
  local flash=ctx.frame(gun,"MuzzleFlash",90,49,15,10,ctx.colors.gold);ctx.corner(flash,5);flash.Visible=false
  self.slots[i]={mount=mount,gun=gun,empty=empty,flash=flash,angle=0,recoil=0,velocity=0,shotAt=-100,id=nil,config=m,scale=scale.Scale}
 end
 function self.configure(s)
  self.activeCount=0
  for i,r in ipairs(self.slots) do
   local id=A.mountWeapon(s,i);r.mount.Visible=id~=nil;r.empty.Visible=id==nil
   if id then self.activeCount=self.activeCount+1 end
   if id~=r.id then
    if r.art then r.art:Destroy();r.art=nil end
    r.id=id;r.recoil=0;r.velocity=0;r.shotAt=-100;r.target=nil
    local def=id and ctx.C.Catalog.weapons[id]
    if def then
     r.visual=def.visual or {model="ballistic",muzzle=40,kick=2,color={251,206,85},projectile="bullet",length=20,width=4,arc=0}
     r.art=ctx.frame(r.gun,"WeaponArt_"..id,0,0,180,108,nil,1);buildModel(ctx,r.art,r.visual)
     r.flash.Position=UDim2.fromOffset(90+r.visual.muzzle,49)
     r.flash.BackgroundColor3=Color3.fromRGB(r.visual.color[1],r.visual.color[2],r.visual.color[3])
     r.flash.ZIndex=2
    end
   end
  end
 end
 function self.fire(slot,weapon,x,y,at)
  local r=self.slots[slot];if not r or r.id~=weapon then return end
  r.target={x=x,y=y};r.shotAt=math.max(at or self.time,self.time)
  r.recoil=math.min(12,r.recoil+(r.visual.kick or 3));r.velocity=0
 end
 function self.muzzle(slot)
  local r=self.slots[slot];if not r or not r.id then return nil end
  local angle=math.rad(r.angle);local length=((r.visual.muzzle or 40)-r.recoil)*r.scale
  return r.config.x+math.cos(angle)*length,r.config.y+math.sin(angle)*length
 end
 function self.update(s,dt,time,reduced,flashes)
  self.time=time
  for _,r in ipairs(self.slots) do if r.id then
   local target=(time-r.shotAt<.45 and r.target) or s.enemies[1]
   local desired=target and math.deg(math.atan2(target.y-r.config.y,target.x-r.config.x)) or 0
   desired=A.clamp(desired,r.visual.aimMin or -20,r.visual.aimMax or 35)
   r.angle=r.angle+((desired-r.angle+180)%360-180)*A.alpha(14,dt)
   r.recoil,r.velocity=A.spring(r.recoil,r.velocity,23,dt)
   r.mount.Rotation=r.angle;r.gun.Position=UDim2.fromOffset(reduced and 0 or -r.recoil,0)
   local age=time-r.shotAt
   r.flash.Visible=flashes and not reduced and age>=0 and age<.065
   if r.flash.Visible then r.flash.Size=UDim2.fromOffset(11+(1-age/.065)*12,7+(1-age/.065)*5) end
  end end
 end
 function self.reset()
  self.time=0
  for _,r in ipairs(self.slots) do r.angle=0;r.recoil=0;r.velocity=0;r.shotAt=-100;r.target=nil;r.flash.Visible=false end
 end
 function self.destroy()
  for _,r in ipairs(self.slots) do r.mount:Destroy();r.empty:Destroy() end
 end
 return self
end
return W
