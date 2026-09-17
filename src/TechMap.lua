-- Aligned technology lanes with short local edges. Cross-lane prerequisites use inspector links. Native XY touch scrolling + desktop background dragging.
local M={}
function M.position(n)
 return 230+(n.tier-1)*176,150+(n.column-1)*132
end
function M.build(ctx,parent,self,s,x,y,w,h)
 local CW,CH=1600,920
 local U,C,R,G=ctx.U,ctx.C,ctx.R,ctx.Gallery;local c=U.colors
 self.zoom=self.zoom or math.min(w/CW,h/CH)
 local z=self.zoom
 local offsetX=math.max(0,(w-CW*z)/2)
 local tree=U.scroll(parent,"TechTree",x,y,w,h,CH*z)
 tree.CanvasSize=UDim2.fromOffset(CW*z,CH*z);tree.ScrollingDirection=Enum.ScrollingDirection.XY
 tree.BackgroundTransparency=0;tree.BackgroundColor3=c.paper;U.corner(tree,12)
 local saved=self.nextCanvas or self.scrolls.TechTree or Vector2.new(math.max(0,800*z-w/2),math.max(0,460*z-h/2));self.nextCanvas=nil
 tree.CanvasPosition=saved
 local function line(name,ax,ay,bx,by,color)
  local dx,dy=(bx-ax)*z,(by-ay)*z
  local f=U.frame(tree,name,(ax+bx)*z/2+offsetX,(ay+by)*z/2,math.sqrt(dx*dx+dy*dy),math.max(2,4*z),color)
  f.AnchorPoint=Vector2.new(.5,.5);f.Rotation=math.deg(math.atan2(dy,dx))
 end
 -- Only adjacent prerequisites are wired. No long cross-lane spaghetti.
 local required={};local selected=C.Tech.nodes[self.tech]
 for _,pre in ipairs(selected.prereqs) do required[pre]=true end
 for _,id in ipairs(C.Tech.order) do
  local n=C.Tech.nodes[id];local nx,ny=M.position(n)
  for _,pre in ipairs(n.prereqs) do
   local pn=C.Tech.nodes[pre]
   if pn.column==n.column then
    local px,py=M.position(pn)
    line("Dependency_"..pre.."_"..id,px+64,py,nx-64,ny,id==self.tech and c.orange or s.profile.tech[pre] and c.mint or c.muted)
   end
  end
 end
 local arts={fort="tank",industry="crate",ballistics="cannon",energy="arc",logistics="machine",expedition="planet3"}
 for _,id in ipairs(C.Tech.order) do
  local n=C.Tech.nodes[id];local state=R.techState(s.profile,id,C);local nx,ny=M.position(n)
  local b=U.button(tree,"Tech_"..id,"",(nx-64)*z+offsetX,(ny-44)*z,128*z,88*z,function() self.tech=id;self.branch=n.column;ctx.dirty() end,state=="ready")
  for _,child in ipairs(b:GetChildren()) do if child:IsA("UICorner") then child.CornerRadius=UDim.new(0,math.max(2,7*z)) elseif child:IsA("UIStroke") then child.Thickness=math.max(1,2*z) end end
  b.BackgroundColor3=state=="owned" and c.mint or state=="locked" and c.paper or c.cream
  local key=arts[n.branch];if n.effects.unlockArc then key="arc" elseif n.effects.unlockRail then key="rail" elseif n.effects.unlockFlame then key="flame" elseif n.effects.unlockMortar then key="mortar" end
  if z<.5 then G.sprite(b,key,25*z,4*z,78*z,78*z) else G.sprite(b,key,39*z,4*z,50*z,50*z) end
  if z>=.5 then U.text(b,"NodeLabel",n.name,3*z,55*z,122*z,28*z,math.max(11,17*z),c.ink,true,Enum.TextXAlignment.Center) end
  if z>=.5 then U.text(b,"Tier",tostring(n.tier),4*z,2*z,22*z,23*z,math.max(10,15*z),c.ink,true) end
  if required[id] then U.outline(b,math.max(2,3*z),c.mint) end
  local cross=false;for _,pre in ipairs(n.prereqs) do if C.Tech.nodes[pre].column~=n.column then cross=true end end
  if cross then U.text(b,"CrossPrerequisite","↗",102*z,3*z,23*z,23*z,math.max(12,18*z),c.ink,true) end
  if self.tech==id then U.outline(b,math.max(2,4*z),c.orange) end
 end
 for _,branch in ipairs(C.Tech.branches) do
  local _,ny=M.position(C.Tech.nodes[branch.id.."_1"])
  U.text(tree,"BranchLabel_"..branch.id,branch.name,12*z+offsetX,(ny-25)*z,144*z,50*z,math.max(11,20*z),c.ink,true,Enum.TextXAlignment.Center)
 end
 for tier=1,8 do
  local nx=M.position(C.Tech.nodes["fort_"..tier])
  U.text(tree,"StageLabel"..tier,string.format("%02d",tier),(nx-50)*z+offsetX,35*z,100*z,40*z,math.max(12,22*z),c.ink,true,Enum.TextXAlignment.Center)
 end
 local UIS=game:GetService("UserInputService");local drag=nil
 tree.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 then drag={x=input.Position.X,y=input.Position.Y,canvas=tree.CanvasPosition} end
 end)
 self.mapConnections=self.mapConnections or {}
 self.mapConnections[#self.mapConnections+1]=UIS.InputChanged:Connect(function(input)
  if drag and input.UserInputType==Enum.UserInputType.MouseMovement and tree.Parent then
   local abs=tree.AbsoluteSize;local scale=abs and abs.X>0 and abs.X/w or 1
   tree.CanvasPosition=Vector2.new(math.max(0,math.min(CW*z-w,drag.canvas.X-(input.Position.X-drag.x)/scale)),math.max(0,math.min(CH*z-h,drag.canvas.Y-(input.Position.Y-drag.y)/scale)))
  end
 end)
 self.mapConnections[#self.mapConnections+1]=UIS.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then drag=nil end end)
 local function zoom(nextZoom)
  nextZoom=math.max(.12,math.min(1.2,nextZoom))
  local nx=(tree.CanvasPosition.X+w/2-offsetX)/z*nextZoom-w/2+math.max(0,(w-CW*nextZoom)/2)
  local ny=(tree.CanvasPosition.Y+h/2)/z*nextZoom-h/2
  self.nextCanvas=Vector2.new(math.max(0,math.min(math.max(0,CW*nextZoom-w),nx)),math.max(0,math.min(math.max(0,CH*nextZoom-h),ny)))
  self.zoom=nextZoom;ctx.dirty()
 end
 U.button(parent,"ZoomOut","−",x,y-58,64,50,function() zoom(z-.15) end)
 U.button(parent,"ZoomIn","+",x+70,y-58,64,50,function() zoom(z+.15) end)
 U.button(parent,"FitTree","全图",x+140,y-58,90,50,function() zoom(math.min(w/CW,h/CH)) end)
 U.button(parent,"FocusTech","定位",x+236,y-58,90,50,function()
  local nx,ny=M.position(C.Tech.nodes[self.tech]);self.zoom=.85;self.nextCanvas=Vector2.new(math.max(0,nx*.85-w/2),math.max(0,ny*.85-h/2));ctx.dirty()
 end)
 local ready=nil;for _,id in ipairs(C.Tech.order) do if R.techState(s.profile,id,C)=="ready" then ready=id;break end end
 local nextButton=U.button(parent,"FindReadyTech","找可研究",x+332,y-58,132,50,function()
  if not ready then return end
  self.tech=ready;self.branch=C.Tech.nodes[ready].column;local nx,ny=M.position(C.Tech.nodes[ready]);self.zoom=.85
  self.nextCanvas=Vector2.new(math.max(0,math.min(math.max(0,CW*.85-w),nx*.85-w/2)),math.max(0,math.min(math.max(0,CH*.85-h),ny*.85-h/2)));ctx.dirty()
 end)
 U.enabled(nextButton,ready~=nil)
 U.text(parent,"MapHelp","↗ 跨科前置：点节点后看右侧；绿框标出所需科技。",x,y+h+3,w,24,14,c.ink,false)
 return tree
end
return M
