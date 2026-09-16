-- Minimal host for server logic tests. NOT an emulator or a Roblox engine test.
-- Geometry/rendering, replication, physics and platform API behavior are not validated.
local clock=0
local options=MOCK or {}
local counters={getDataStore=0,updates=0}
local realOS=os
os={clock=function() return clock end,time=realOS.time}
math.atan2=math.atan2 or function(y,x) return math.atan(y,x) end
local function signal()
    local s={callbacks={}}
    function s:Connect(f) self.callbacks[#self.callbacks+1]=f; return {Disconnect=function() end} end
    function s:Fire(...) for _,f in ipairs(self.callbacks) do f(...) end end
    return s
end
local vector={}
vector.__index=function(v,k)
    if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    if k=="Unit" then local m=math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z); return Vector3.new(v.X/m,v.Y/m,v.Z/m) end
    return vector[k]
end
function vector.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function vector.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function vector.__mul(a,b) if type(a)=="number" then a,b=b,a end; return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
function vector.__div(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
function vector:Lerp(b,t) return self+(b-self)*t end
Vector3={new=function(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vector) end}
Vector3.zero=Vector3.new(); Vector3.one=Vector3.new(1,1,1)
local cf={}
cf.__index=cf
cf.__mul=function(a,b) return CFrame.new(a.Position+b.Position) end
CFrame={new=function(x,y,z) return setmetatable({Position=type(x)=="table" and x or Vector3.new(x,y,z)},cf) end}
CFrame.Angles=function() return CFrame.new() end
CFrame.lookAt=function(pos) return CFrame.new(pos) end
Color3={fromRGB=function(...) return {...} end,new=function(...) return {...} end}
UDim2={fromOffset=function(x,y) return {xs=0,xo=x,ys=0,yo=y} end,fromScale=function(x,y) return {xs=x,xo=0,ys=y,yo=0} end}
Enum=setmetatable({},{__index=function(t,k)
    if API_CONTRACT then assert(API_CONTRACT.enums[k],"Unknown Roblox enum "..k) end
    local v=setmetatable({},{__index=function(_,n)
        if API_CONTRACT then assert(API_CONTRACT.enums[k][n],"Unknown Roblox enum item "..k.."."..n) end
        return n
    end}); rawset(t,k,v); return v
end})
local methods={}
local meta={}
meta.__index=function(t,k)
    if methods[k] then return methods[k] end
    if t._props[k]~=nil then return t._props[k] end
    for _,c in ipairs(t._children) do if c.Name==k then return c end end
end
meta.__newindex=function(t,k,v)
    local info=debug.getinfo(2,"S")
    if API_CONTRACT and info and (info.source:find("Frontier") or info.source=="Art" or info.source=="Motion" or info.source=="Panels" or info.source=="UI" or info.source=="Audio") then
        local known=API_CONTRACT.properties[t.ClassName]
        assert(known and known[k],"Unknown Roblox property "..t.ClassName.."."..k)
        local kind=known[k]
        if kind.name=="bool" then assert(type(v)=="boolean",k.." requires boolean") end
        if kind.name=="string" then assert(type(v)=="string",k.." requires string") end
        if kind.category=="Enum" then assert(API_CONTRACT.enums[kind.name][v],k.." requires enum "..kind.name) end
    end
    if k=="Parent" then
        local old=t._props.Parent
        if old then for i,c in ipairs(old._children) do if c==t then table.remove(old._children,i); break end end end
        t._props.Parent=v
        if v then v._children[#v._children+1]=t end
    else t._props[k]=v end
end
Instance={new=function(class)
    local t=setmetatable({_props={ClassName=class,Name=class},_children={}},meta)
    t.Activated=signal(); t.InputBegan=signal(); t.FocusLost=signal()
    if class=="RemoteEvent" then t.OnServerEvent=signal(); t.OnClientEvent=signal(); t.messages={} end
    return t
end}
function methods:FindFirstChild(name) for _,c in ipairs(self._children) do if c.Name==name then return c end end end
function methods:IsA(class) return self.ClassName==class or (class=="GuiObject" and (self.ClassName=="Frame" or self.ClassName=="TextButton" or self.ClassName=="TextLabel" or self.ClassName=="TextBox" or self.ClassName=="ImageLabel" or self.ClassName=="ScrollingFrame" or self.ClassName=="TextBox")) end
function methods:GetAttribute(name) return self._props["attr_"..name] end
function methods:SetAttribute(name,value) self._props["attr_"..name]=value end
function methods:RemoveDefaultLoadingScreen() self.removed=true end
function methods:WaitForChild(name,timeout)
    local item=self[name]
    if not item and not timeout then error("Missing child "..name.." under "..self.Name) end
    return item
end
function methods:Destroy() self.Parent=nil; self.destroyed=true; local list={table.unpack(self._children)}; for _,c in ipairs(list) do c:Destroy() end end
function methods:GetPivot() return self.pivot or (self.PrimaryPart and self.PrimaryPart.CFrame) or CFrame.new() end
function methods:PivotTo(value) self.pivot=value end
function methods:FireClient(player,...)
    self.messages[#self.messages+1]={player=player,args={...}}
    if self.Name=="State" then self.last=(...) end
    if self.OnClientEvent and player==game:GetService("Players").LocalPlayer then self.OnClientEvent:Fire(...) end
    if #self.messages>30 then table.remove(self.messages,1) end
end
function methods:GetPlayers() return {} end
function methods:Play() self.playCount=(self.playCount or 0)+1 end
function methods:Stop() end
function methods:IsStudio() return not options.production end
function methods:GetGuiInset() return Vector2.new(0,36),Vector2.new(0,0) end
function methods:LogCustomEvent(...) counters.analytics=(counters.analytics or 0)+1 end
function methods:ClearAllChildren() local list={table.unpack(self._children)};for _,c in ipairs(list) do c:Destroy() end end
function methods:CreateEditableImage(opts)
    if options.imageDisabled then error("EditableImage disabled") end
    local image={Size=opts.Size}
    function image:WritePixelsBuffer(_,size,buf) assert(buf.length==size.X*size.Y*4,"RGBA size mismatch") end
    function image:Destroy() self.destroyed=true end
    return image
end
buffer={fromstring=function(s) return {length=#s} end}
Content={fromObject=function(image) return {image=image} end}
local services={}
function service(name) if not services[name] then local s=Instance.new(name); s.Name=name; services[name]=s end; return services[name] end
workspace=service("Workspace")
game={GameId=options.unpublished and 0 or 123,PlaceId=options.unpublished and 0 or 456,GetService=function(_,name) return service(name) end,BindToClose=function(_,f) game.close=f end}
service("Players").PlayerAdded=signal(); service("Players").PlayerRemoving=signal()
service("RunService").Heartbeat=signal()
local db={}; local failStore=false
function methods:GetDataStore()
    counters.getDataStore=counters.getDataStore+1
    if options.constructorError then error("You must publish this place to the web to access DataStore.") end
    return {UpdateAsync=function(_,key,fn)
    counters.updates=counters.updates+1
    if failStore then error("API unavailable") end
    local value=fn(db[key]); if options.replayCallback then value=fn(db[key]) end
    if value~=nil then
      db[key]=value
      if options.commitThenError then options.commitThenError=false;error("commit response lost") end
      return value
    end
    return nil
end} end
local guid=0
function methods:GenerateGUID() guid=guid+1; return "test-token-"..guid end
Random={new=function(seed)
    local state=seed or 123
    local function number() state=(state*48271)%2147483647; return state/2147483647 end
    return {NextNumber=function(_,a,b) return (a or 0)+number()*((b or 1)-(a or 0)) end,NextInteger=function(_,a,b) return a+math.floor(number()*(b-a+1)) end}
end}
warn=function() end
local tasks={}
task={spawn=function(f,...) tasks[#tasks+1]={f=f,args={...}} end,wait=function(n) return coroutine.yield(n or 0.1) end}
local function drain()
    local pending=tasks; tasks={}
    for _,t in ipairs(pending) do
        local co=coroutine.create(t.f); local ok,err=coroutine.resume(co,table.unpack(t.args)); assert(ok,err)
        -- Periodic background tasks stop at their first wait. Save tasks run to completion.
    end
end
local shared=Instance.new("Folder"); shared.Name="FrontierShared"; shared.Parent=service("ReplicatedStorage")
local root=Instance.new("Script"); root.Name="FrontierServer"
for _,name in ipairs({"Config","Rules","Core","Art","ArtData","Tech","Catalog","Panels","Motion","UI","Guide","Audio"}) do local m=Instance.new("ModuleScript"); m.Name=name; m.source=SOURCES[name]; m.Parent=shared end
local profile=Instance.new("ModuleScript"); profile.Name="ProfileStore"; profile.source=SOURCES.ProfileStore; profile.Parent=root
local telemetry=Instance.new("ModuleScript");telemetry.Name="Telemetry";telemetry.source=SOURCES.Telemetry;telemetry.Parent=root
local cache={}
require=function(module)
    if cache[module] then return cache[module] end
    local env=setmetatable({script=module},{__index=_G})
    local f=assert(load(module.source,module.Name,"t",env)); local value=f()
    if module.Name=="Config" and options.cloud~=nil then value.EnableCloudSave=options.cloud end
    cache[module]=value; return value
end
if not options.noServer then assert(load(SOURCES.Server,"FrontierServer","t",setmetatable({script=root},{__index=_G})))() end
drain()
local Test={}
function Test.join(id)
    local p=Instance.new("Player"); p.UserId=id or 42; p.Parent=service("Players"); service("Players").PlayerAdded:Fire(p); drain(); return p
end
function Test.action(p,kind,data)
    clock=clock+0.2
    service("ReplicatedStorage").FrontierNetwork.Action.OnServerEvent:Fire(p,kind,data); drain()
end
function Test.state(p) Test.action(p,"ready"); return service("ReplicatedStorage").FrontierNetwork.State.last end
function Test.step(seconds)
    for i=1,math.floor(seconds*10+0.5) do clock=clock+0.1; service("RunService").Heartbeat:Fire(0.1); drain() end
end
function Test.runFor(p,seconds,autoUpgrade)
    for i=1,math.floor(seconds*10+0.5) do
        Test.step(0.1)
        local s=service("ReplicatedStorage").FrontierNetwork.State.last
        if autoUpgrade and s and s.pending then
            local id=s.pending.options[1]
            for _,candidate in ipairs(s.pending.options) do
                if candidate=="cannon" or candidate=="arc" then id=candidate; break end
            end
            Test.action(p,"upgrade",{token=s.pending.token,id=id})
        end
    end
end
function Test.drive(p,x,z,seconds)
    for i=1,math.floor(seconds*5+0.5) do Test.action(p,"move",{x=x,z=z}); Test.step(0.2) end
end
function Test.leave(p) service("Players").PlayerRemoving:Fire(p); p.Parent=nil; drain() end
function Test.failStore(v) failStore=v end
function Test.session(p)
    local callback=service("RunService").Heartbeat.callbacks[1]
    for i=1,30 do local name,value=debug.getupvalue(callback,i); if name=="sessions" then return value[p] end end
    error("sessions upvalue not found")
end
function Test.place(p,x,z)
    local s=Test.session(p); s.pos=s.origin+Vector3.new(x,4,z); s.input=Vector3.zero; s.drilling=false
end
function Test.enableClient(p,source,touch)
    local vec2={}; vec2.__index=vec2
    function vec2.__add(a,b) return Vector2.new(a.X+b.X,a.Y+b.Y) end
    function vec2.__sub(a,b) return Vector2.new(a.X-b.X,a.Y-b.Y) end
    function vec2.__div(a,b) return Vector2.new(a.X/b,a.Y/b) end
    function vec2.__mul(a,b) return Vector2.new(a.X*b,a.Y*b) end
    Vector2={new=function(x,y) return setmetatable({X=x,Y=y},vec2) end}; Vector2.zero=Vector2.new(0,0)
    UDim2.new=function(xs,xo,ys,yo) return {xs=xs,xo=xo,ys=ys,yo=yo} end; UDim={new=function(scale,offset) return {scale=scale,offset=offset} end}
    function methods:GetChildren() return {table.unpack(self._children)} end
    function methods:IsA(class) return self.ClassName==class or (class=="GuiObject" and (self.ClassName=="Frame" or self.ClassName=="TextButton" or self.ClassName=="TextLabel" or self.ClassName=="TextBox" or self.ClassName=="ImageLabel" or self.ClassName=="ScrollingFrame")) end
    function methods:FireServer(...) self.OnServerEvent:Fire(p,...) end
    function methods:SetCoreGuiEnabled() end
    function methods:GetFocusedTextBox() return nil end
    function methods:IsKeyDown(key) return self.keys and self.keys[key] or false end
    service("Players").LocalPlayer=p
    local pg=p:FindFirstChild("PlayerGui")
    if not pg then pg=Instance.new("PlayerGui"); pg.Name="PlayerGui"; pg.Parent=p end
    local uis=service("UserInputService"); uis.TouchEnabled=touch or false; uis.keys={}
    for _,name in ipairs({"InputChanged","InputEnded","InputBegan","WindowFocusReleased","WindowFocused"}) do uis[name]=signal() end
    service("RunService").RenderStepped=service("RunService").RenderStepped or signal()
    local cam=Instance.new("Camera"); cam.ViewportSize=Vector2.new(options.width or (touch and 844 or 1440),options.height or (touch and 390 or 810)); workspace.CurrentCamera=cam
    assert(load(source,"FrontierClient"))()
    Test.render(0.1)
end
function Test.render(dt) service("RunService").RenderStepped:Fire(dt or 0.1) end
function Test.findGui(p,content)
    local function search(node)
        if node.Visible==false or node.Enabled==false then return nil end
        if node.Text==content then return node end
        for _,child in ipairs(node._children) do local found=search(child); if found then return found end end
    end
    return search(p.PlayerGui)
end
function Test.click(p,content)
    local b=Test.findGui(p,content); assert(b,"GUI not found: "..content)
    clock=clock+0.3; b.Activated:Fire(); drain(); Test.render(0.1)
end
function Test.key(key,pressed)
    local uis=service("UserInputService"); uis.keys[key]=pressed
    if pressed then uis.InputBegan:Fire({KeyCode=key},false) end
end
function Test.boot(p,source)
    Test.enableClient(p,"",false)
    assert(load(source,"FrontierBoot"))()
    Test.render(0.3)
end
function Test.dropNetwork() local n=service("ReplicatedStorage").FrontierNetwork; if n then n:Destroy() end end
function Test.network() return service("ReplicatedStorage").FrontierNetwork end
function Test.advanceClock(seconds) clock=clock+seconds end
function Test.clientRun(source) assert(load(source,"FrontierClient"))() end
Test.counters=counters
Test.db=db
function Test.module(name) return require(shared:FindFirstChild(name) or root:FindFirstChild(name)) end
return Test
