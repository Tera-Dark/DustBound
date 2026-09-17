-- Separate, lazy 1 MiB illustration atlas. Battle art and boot decoding stay unchanged.
local G={mode="cold",waiting={}}
local shared=script.Parent
local Art=require(shared.Art)
local slots={cannon=0,machine=1,arc=2,rail=3,flame=4,mortar=5,crawler=6,runner=7,tank=8,spitter=9,elite=10,warden=11,planet1=12,planet2=13,planet3=14,crate=15}
local function apply(v)
 if G.content then v.ImageContent=G.content end
end
function G.init()
 if G.mode~="cold" then return end;G.mode="loading"
 task.spawn(function()
  local image
  local ok,err=pcall(function()
   local data=require(shared.GalleryData)
   image=game:GetService("AssetService"):CreateEditableImage({Size=Vector2.new(512,512)});assert(image)
   Art.decode(data,function(y,rows,bytes) image:WritePixelsBuffer(Vector2.new(0,y),Vector2.new(512,rows),buffer.fromstring(bytes)) end,function() game:GetService("RunService").Heartbeat:Wait() end)
   G.content=Content.fromObject(image);G.image=image
  end)
  G.mode=ok and "embedded" or "fallback";G.error=not ok and tostring(err) or nil
  if not ok and image then image:Destroy() end
  for _,entry in ipairs(G.waiting) do if entry.view.Parent then apply(entry.view);entry.fallback.Visible=not ok end end
  G.waiting={}
 end)
end
function G.sprite(parent,key,x,y,w,h)
 local U=require(shared.UI);local i=slots[key] or 15
 local f=U.frame(parent,"Illustration_"..key,x,y,w,h,U.colors.paper);U.corner(f,math.min(10,w*.1));f.ClipsDescendants=true
 local fallback=U.frame(f,"ArtFallback",0,0,w,h,nil,1)
 if G.mode~="embedded" then
  local function block(name,bx,by,bw,bh,color,round)
   local v=U.frame(fallback,name,(50+bx)*w/100,(50+by)*h/100,bw*w/100,bh*h/100,color or U.colors.ink)
   if round then U.corner(v,round*math.min(w,h)/100) end
   return v
  end
  if i<=5 then
   local W=require(shared.WeaponRig);local def=require(shared.Catalog).weapons[key]
   local model=def.visual.model=="turret" and "ballistic" or def.visual.model
   local builder=W.builders[model] or W.builders.ballistic;builder(block,U.colors,U.colors.mint)
  elseif i<=11 then
   local tint=Color3.fromRGB(104,74,112);local d=require(shared.Catalog).enemies[key]
   if d then tint=Color3.fromRGB(d.color[1],d.color[2],d.color[3]) end
   for leg=0,5 do local side=leg<3 and -1 or 1;local row=leg%3;local v=block("Leg",side*31-4,-18+row*19,8,31,U.colors.ink,4);v.Rotation=side*28 end
   block("Carapace",-28,-30,56,57,U.colors.ink,26);block("Shell",-24,-26,48,47,tint,23)
   block("Eye",-15,10,9,9,U.colors.gold,4);block("Eye",6,10,9,9,U.colors.gold,4)
  elseif i<=14 then
   local colors={U.colors.orange,U.colors.mint,Color3.fromRGB(141,114,172)}
   block("PlanetOutline",-39,-39,78,78,U.colors.ink,40);block("Planet",-35,-35,70,70,colors[i-11],38)
   for _,crater in ipairs({{-20,-20,19},{8,-5,25},{-15,17,12}}) do block("Crater",crater[1],crater[2],crater[3],crater[3],U.colors.paper,15) end
  else
   block("Crate",-35,-25,70,57,U.colors.ink,7);block("Inset",-30,-20,60,47,U.colors.orange,5)
   block("Band",-5,-25,10,57,U.colors.cream,2)
   local crystal=block("Crystal",-14,-35,15,29,U.colors.mint,4);crystal.Rotation=-20
  end
 else fallback.Visible=false end
 local view=Instance.new("ImageLabel");view.Name="GalleryArtwork";view.BackgroundTransparency=1;view.Size=UDim2.fromScale(1,1)
 view.ImageRectOffset=Vector2.new(i%4*128+3,math.floor(i/4)*128+3);view.ImageRectSize=Vector2.new(122,122);view.Parent=f
 if G.mode=="embedded" then apply(view);fallback.Visible=false
 elseif G.mode~="fallback" then G.waiting[#G.waiting+1]={view=view,fallback=fallback};G.init() end
 return f
end
return G
