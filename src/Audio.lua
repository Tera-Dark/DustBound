-- Local pooled feedback. Built-in compatibility pings do not need uploaded asset permissions.
-- For full original effects upload assets/audio/*.wav and assign C.SoundIds (never use local paths in SoundId).
local A={}
local map={lowhull="warning",readywave="supply",shot="cannon",impact="impact",upgrade="upgrade",deposit="deposit",accepted="supply",supply="supply",["end"]="victory"}
local pitches={cannon=.48,machine=1.7,arc=1.15,impact=.65,warning=.72,upgrade=1.25,deposit=1.6,supply=.9,victory=1.4,defeat=.6,click=1.9}
function A.new(C)
 local self={pool={},at={},clock=0,volume=.65,musicVolume=.25,mode="内置兼容提示音",music=nil,focused=true,muted=false,cfg={}}
 local root=Instance.new("Folder");root.Name="DustboundAudio";root.Parent=game:GetService("SoundService")
 local configured=false
 for _,id in pairs(C.SoundIds) do if type(id)=="number" and id>0 then configured=true end end
 if configured then self.mode="自定义音效已配置（加载权限需实测）" end
 local function refreshMute()
  local muted=self.cfg.masterMuted==true or (not self.focused and self.cfg.muteUnfocused~=false)
  if muted and not self.muted then for _,snd in pairs(self.pool) do pcall(function() snd:Stop() end) end end
  self.muted=muted
  if self.music then self.music.Volume=muted and 0 or self.musicVolume*.35 end
 end
 function self.settings(settings)
  self.cfg=settings;self.volume=settings.sfx;self.musicVolume=settings.music;refreshMute()
 end
 function self.focus(focused) self.focused=focused;refreshMute() end
 function self.play(key)
  if self.volume<=0 or self.muted then return end
  local delay=key=="warning" and 4 or key=="drill" and .62 or key=="machine" and .16 or key=="cannon" and .3 or .12
  if self.clock-(self.at[key] or -100)<delay then return end;self.at[key]=self.clock
  local sound=self.pool[key]
  if not sound then
   sound=Instance.new("Sound");sound.Name="SFX_"..key
   local id=C.SoundIds[key];local custom=type(id)=="number" and id>0
   sound.SoundId=custom and "rbxassetid://"..id or "rbxasset://sounds/electronicpingshort.wav"
   sound.PlaybackSpeed=custom and 1 or (pitches[key] or 1);sound.Parent=root;self.pool[key]=sound
  end
  sound.Volume=self.volume*((key=="machine" or key=="cannon") and .07 or .22)
  pcall(function() sound:Stop();sound:Play() end)
 end
 function self.events(events)
  for _,e in ipairs(events) do
   local key=map[e.kind]
   if e.kind=="shot" then key=e.weapon=="machine" and "machine" or e.weapon=="arc" and "arc" or "cannon" end
   if e.kind=="end" then key=e.won and "victory" or "defeat" end
   if key then self.play(key) end
  end
 end
 function self.update(dt,paused,s)
  self.clock=self.clock+dt
  if paused and not self.wasPaused then for _,snd in pairs(self.pool) do pcall(function() snd:Stop() end) end end
  self.wasPaused=paused
  if s and not paused and not s.supply and s.stage=="mining" and type(C.SoundIds.drill)=="number" and C.SoundIds.drill>0 then
   for _,r in ipairs(s.robots) do if r.state=="drilling" then self.play("drill");break end end
  end
  local id=C.SoundIds.music
  if type(id)=="number" and id>0 and not self.music then
   self.music=Instance.new("Sound");self.music.Name="Music";self.music.SoundId="rbxassetid://"..id;self.music.Looped=true;self.music.Volume=(paused or self.muted) and 0 or self.musicVolume*.35;self.music.Parent=root;pcall(function() self.music:Play() end)
  end
  if self.music then self.music.Volume=(paused or self.muted) and 0 or self.musicVolume*.35 end
 end
 return self
end
return A
