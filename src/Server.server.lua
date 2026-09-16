-- DUSTBOUND 0.5: authoritative gameplay, explicit cloud failure modes and bounded analytics.
local Players=game:GetService("Players");local RS=game:GetService("ReplicatedStorage");local RunService=game:GetService("RunService")
Players.CharacterAutoLoads=false
local function ensure(parent,class,name) local o=parent:FindFirstChild(name);if not o then o=Instance.new(class);o.Name=name;o.Parent=parent end;return o end
local net=ensure(RS,"Folder","FrontierNetwork")
local Action=ensure(net,"RemoteEvent","Action");local State=ensure(net,"RemoteEvent","State");local FX=ensure(net,"RemoteEvent","FX")
local status=ensure(net,"StringValue","BootStatus");local failure=ensure(net,"StringValue","BootError");status.Value="STARTING";failure.Value=""
local function report(err) status.Value="ERROR";failure.Value=tostring(err):sub(1,3000);warn("[DUSTBOUND] "..tostring(err)) end
local function launch()
 local shared=RS:WaitForChild("FrontierShared",10);assert(shared,"FrontierShared missing")
 local C=require(shared:WaitForChild("Config",10));C.Tech=require(shared:WaitForChild("Tech",10));C.Catalog=require(shared:WaitForChild("Catalog",10));C.Supplies=C.Catalog.supplies
 local R=require(shared:WaitForChild("Rules",10));local Core=require(shared:WaitForChild("Core",10));local Guide=require(shared:WaitForChild("Guide",10))
 local Profiles=require(script:WaitForChild("ProfileStore",10));local Telemetry=require(script:WaitForChild("Telemetry",10))
 local sessions={}
 local function send(player,s)
  Telemetry.consume(s.telemetry,player,C,s.game)
  local packet=Core.snapshot(s.game,C,R);packet.saveStatus=s.profile.status;packet.storage={mode=s.profile.mode,blocked=s.profile.blocked,busy=s.storageBusy or s.profile.busy,lastSaved=s.profile.lastSaved,dirty=s.profile.revision>s.profile.savedRevision}
  packet.telemetry=Telemetry.summary(s.telemetry);packet.ack=s.lastRequest or 0;packet.actionResult=s.actionResult
  packet.recommendation=Guide.recommend(packet,C,R);packet.forecast=Guide.forecast(packet)
  State:FireClient(player,packet)
  if #s.game.events>0 then FX:FireClient(player,s.game.events);s.game.events={} end
 end
 local function save(player,s,release)
  if not s.profile.persistent then return false end
  local ok=Profiles.flush(player.UserId,s.profile,release)
  if not ok then Telemetry.record(s.telemetry,player,C,"save_failure",1,s.game) end
  if player.Parent then send(player,s) end
  return ok
 end
 local function join(player)
  local ok,err=xpcall(function()
   if sessions[player] then return end
   local record=Profiles.open(player.UserId)
   if not player.Parent then Profiles.flush(player.UserId,record,true);return end
   if player.Character then player.Character:Destroy() end
   local s={profile=record,game=Core.new(C,R,record.data),telemetry=Telemetry.new(),tokens=24,rateAt=os.clock(),lastAction=-1,lastRequest=0,storageBusy=false}
   sessions[player]=s;send(player,s)
  end,debug.traceback);if not ok then report(err) end
 end
 Players.PlayerAdded:Connect(join);for _,p in ipairs(Players:GetPlayers()) do task.spawn(join,p) end
 Action.OnServerEvent:Connect(function(player,kind,data,requestId)
  local s=sessions[player];if not s or type(kind)~="string" then return end
  local now=os.clock();s.tokens=math.min(24,s.tokens+(now-s.rateAt)*12);s.rateAt=now
  if s.tokens<1 then return end;s.tokens=s.tokens-1
  if kind=="ready" then send(player,s);return end
  -- Request IDs suppress duplicate actions. Legacy clients without IDs still pass gameplay validation.
  if requestId~=nil then
   if not R.finite(requestId) or requestId%1~=0 or requestId<=0 or requestId>100000000 then return end
   if requestId<=s.lastRequest then send(player,s);return end
   s.lastRequest=requestId
  end
  if kind~="ui_ready" and kind~="view" and now-s.lastAction<.12 then s.actionResult="操作过快，请稍后再试";send(player,s);return end;if kind~="ui_ready" and kind~="view" then s.lastAction=now end
  local ok,err=xpcall(function()
   if kind=="ui_ready" then
    if not s.telemetry.uiReady then
     s.telemetry.uiReady=true
     if data=="touch" or data=="keyboard" or data=="gamepad" then s.telemetry.input=data end
     Telemetry.record(s.telemetry,player,C,"ui_ready",now-s.telemetry.joined,s.game)
    end
    send(player,s);return
   end
   if kind=="view" and (data=="research" or data=="codex" or data=="settings") then Telemetry.record(s.telemetry,player,C,"open_"..data,1,s.game);send(player,s);return end
   if kind=="save_retry" then
    if s.storageBusy then return end
    if s.profile.mode=="read_error" and s.game.phase=="menu" then
     s.storageBusy=true;send(player,s)
     task.spawn(function()
      local record=Profiles.open(player.UserId,s.profile.token)
      if not player.Parent then Profiles.flush(player.UserId,record,true);return end
      s.profile=record;s.game=Core.new(C,R,record.data);s.storageBusy=false;send(player,s)
     end)
    elseif s.profile.persistent then task.spawn(function() save(player,s,false) end) end
    return
   end
   if kind=="guest" and data=="confirm" and s.profile.mode=="read_error" and not s.storageBusy then
    s.profile=Profiles.guest();s.game=Core.new(C,R,s.profile.data);send(player,s);return
   end
   if s.profile.blocked or s.storageBusy then s.actionResult="云档未就绪：重试读取，或明确选择不保存的访客试玩";send(player,s);return end
   local accepted=Core.act(s.game,C,R,kind,data)
   s.actionResult=accepted and "" or "操作未生效：请检查状态、资源或解锁条件"
   if accepted then Profiles.touch(s.profile) end
   send(player,s)
   if accepted and (kind=="research" or kind=="start" or kind=="abandon" or kind=="loadout" or kind=="preset" or kind=="settings" or kind=="target" or s.game.phase=="ended") then
    task.spawn(function() save(player,s,false) end)
   end
  end,debug.traceback);if not ok then report(err) end
 end)
 Players.PlayerRemoving:Connect(function(player)
  local s=sessions[player];if not s then return end;sessions[player]=nil
  Telemetry.record(s.telemetry,player,C,"disconnect",s.game.elapsed,s.game)
  Profiles.touch(s.profile);save(player,s,true)
 end)
 local accumulator,sendClock=0,0
 RunService.Heartbeat:Connect(function(dt)
  accumulator=math.min(.3,accumulator+dt);sendClock=sendClock+dt
  while accumulator>=C.Tick do
   accumulator=accumulator-C.Tick
   for player,s in pairs(sessions) do if not s.fault and not s.profile.blocked then
    local previous=s.game.phase
    local ok,err=xpcall(function() Core.step(s.game,C,R,C.Tick) end,debug.traceback)
    if not ok then s.fault=true;report(err) end
    if previous~="ended" and s.game.phase=="ended" then
     for key,value in pairs(s.game.timing) do Telemetry.record(s.telemetry,player,C,"time_"..key,value,s.game) end
     Profiles.touch(s.profile);task.spawn(function() save(player,s,false) end)
    end
   end end
  end
  if sendClock>=C.SnapshotInterval then sendClock=0;for player,s in pairs(sessions) do local ok,err=xpcall(function() send(player,s) end,debug.traceback);if not ok then report(err) end end end
 end)
 task.spawn(function() while task.wait(45) do for p,s in pairs(sessions) do Profiles.touch(s.profile);task.spawn(function() save(p,s,false) end) end end end)
 game:BindToClose(function()
  local pending=0
  for p,s in pairs(sessions) do pending=pending+1;Profiles.touch(s.profile);task.spawn(function() save(p,s,true);pending=pending-1 end) end
  local deadline=os.clock()+25;while pending>0 and os.clock()<deadline do task.wait(.1) end
 end)
 if status.Value~="ERROR" then status.Value="READY" end
 print("[DUSTBOUND 0.5.0] native GUI + tutorial + planning console ready")
end
local ok,err=xpcall(launch,debug.traceback);if not ok then report(err) end
