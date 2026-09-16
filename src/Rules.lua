local R = {}
function R.clamp(v,a,b) return math.max(a,math.min(b,v)) end
function R.finite(v) return type(v)=="number" and v==v and v>-math.huge and v<math.huge end
local branches={fort=true,industry=true,ballistics=true,energy=true,logistics=true,expedition=true}
local codexIds={weapons={cannon=true,machine=true,arc=true,rail=true,flame=true,mortar=true},enemies={crawler=true,runner=true,tank=true,spitter=true,elite=true,warden=true},supplies={repair=true,drill=true,ammo=true,ore=true,shield=true,drones=true,overclock=true}}
function R.cleanProfile(raw)
 local p={schema=5,tutorialCompleted=false,runSerial=0,settledSerial=0,targetResearch="",loadout="machine",settings={reducedMotion=false,damageNumbers=true,sfx=.65,music=.25},presets={"machine","machine"},alloy=0,research=0,crystals=0,cores=0,runs=0,wins=0,bestWave=0,tech={},codex={weapons={},enemies={},supplies={}}}
 if type(raw)~="table" then return p end
 for _,key in ipairs({"alloy","research","crystals","cores","runs","wins","bestWave","runSerial","settledSerial"}) do
  if R.finite(raw[key]) then p[key]=math.floor(R.clamp(raw[key],0,key=="bestWave" and 12 or 100000000)) end
 end
 if type(raw.tech)=="table" then for id,v in pairs(raw.tech) do
  if type(id)=="string" and v==true then local branch,tier=id:match("^([a-z]+)_([1-8])$");if branch and tier and branches[branch] then p.tech[id]=true end end
 end end
 if raw.schema~=4 and raw.schema~=5 then
  for old,branch in pairs({armor="fort",drill="industry",power="ballistics"}) do
   local n=R.finite(raw[old]) and math.floor(R.clamp(raw[old],0,2)) or 0
   for i=1,n do p.tech[branch.."_"..i]=true end
  end
 end
 if type(raw.codex)=="table" then for group,ids in pairs(codexIds) do
  if type(raw.codex[group])=="table" then for id in pairs(ids) do
   local count=raw.codex[group][id];if R.finite(count) then p.codex[group][id]=math.floor(R.clamp(count,0,100000000)) end
  end end
 end end
 p.tutorialCompleted=raw.tutorialCompleted==true
 if type(raw.targetResearch)=="string" then local b,n=raw.targetResearch:match("^([a-z]+)_([1-8])$");if b and n and branches[b] then p.targetResearch=raw.targetResearch end end
 if type(raw.loadout)=="string" and codexIds.weapons[raw.loadout] and raw.loadout~="cannon" then p.loadout=raw.loadout end
 if type(raw.presets)=="table" then for i=1,2 do local id=raw.presets[i];if type(id)=="string" and codexIds.weapons[id] and id~="cannon" then p.presets[i]=id end end end
 if type(raw.settings)=="table" then
  for _,key in ipairs({"reducedMotion","damageNumbers"}) do if type(raw.settings[key])=="boolean" then p.settings[key]=raw.settings[key] end end
  for _,key in ipairs({"sfx","music"}) do if R.finite(raw.settings[key]) then p.settings[key]=R.clamp(raw.settings[key],0,1) end end
 end
 p.runSerial=math.max(p.runSerial,p.settledSerial)
 return p
end
function R.record(p,group,id,count) local g=p.codex[group];if g and codexIds[group][id] then g[id]=(g[id] or 0)+(count or 1) end end
function R.bonuses(p,C)
 local b={}
 for id in pairs(p.tech) do local n=C.Tech.nodes[id];if n then for effect,v in pairs(n.effects) do b[effect]=(b[effect] or 0)+v end end end
 return b
end
function R.unlocked(p,definition) return definition and (not definition.tech or p.tech[definition.tech]==true) or false end
function R.techState(p,id,C)
 local n=C.Tech.nodes[id];if not n then return "invalid","未知研究" end
 if p.tech[id] then return "owned","已完成" end
 for _,pre in ipairs(n.prereqs) do if not p.tech[pre] then return "locked","前置："..C.Tech.nodes[pre].name end end
 if p.bestWave<n.minWave then return "locked","需完成第 "..n.minWave.." 波整备" end
 for _,key in ipairs({"alloy","research","crystals","cores"}) do if p[key]<n.cost[key] then return "poor","研究资源不足" end end
 return "ready","可研究"
end
function R.research(p,id,C)
 local state,msg=R.techState(p,id,C);if state~="ready" then return false,msg end
 for key,v in pairs(C.Tech.nodes[id].cost) do p[key]=p[key]-v end
 p.tech[id]=true;return true,"研究完成："..C.Tech.nodes[id].name.." · 下次远征生效"
end
function R.price(id,level,C)
 local d=C.Upgrades[id]
 if not d or not R.finite(level) or level<0 or level>=d.cap then return nil end
 return math.floor(d.cost*d.growth^level+0.5)
end
function R.settlement(won,ore,mined,kills,refinery,overtime,bonuses)
 local b=bonuses or {}
 local alloy=math.floor(math.max(0,ore)*(won and 1 or (.35+(b.lossRetention or 0)))*(1+(b.alloy or 0)))
 local base=math.floor(math.max(0,mined)/70)+math.floor(math.max(0,kills)/12)+(won and 10 or 2)+(overtime and won and 25 or 0)
 return alloy,math.floor(base*(1+refinery*.2)*(1+(b.research or 0)))
end
return R
