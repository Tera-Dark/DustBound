-- Actual Luau CLI checks. No Roblox API/FPS emulation.
local C=require('../src/Config')
C.Tech=require('../src/Tech');C.Catalog=require('../src/Catalog')
C.RunSystems=require('../src/RunSystems');C.ResearchWeb=require('../src/ResearchWeb');C.Economy=require('../src/Economy');C.Encounters=require('../src/Encounters')
local R=require('../src/Rules');local G=require('../src/Core');local M=C.RunSystems
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local s=G.new(C,R,R.cleanProfile(nil));check(G.start(s,C,R),"start")
for id,n in pairs(C.Tech.nodes) do
 for _,pre in ipairs(n.anyPrereqs or {}) do check(C.Tech.nodes[pre].tier<n.tier,"acyclic alternatives "..id) end
 for _,pre in ipairs(n.prereqs) do check(C.Tech.nodes[pre].tier<n.tier,"acyclic mandatory "..id) end
end
for seed=1,50 do
 local run=M.new(seed,nil,seed)
 for wave=1,20 do
  run.phase="combat";check(M.waveCleared(run,wave,20),"clear")
  if run.offer then
   local token,id=run.offer.token,run.offer.choices[1];local gold=run.gold
   check(M.choose(run,token,id),"free choice");check(run.gold==gold,"no draft cost");check(not M.choose(run,token,id),"stale token")
  end
  if wave<20 then
   for _=1,120 do
    M.tickMining(run,.25)
    check(run.gold==120+run.goldMined-run.spent,"robot ledger conservation")
    for _,robot in ipairs(run.robots) do check(robot.x>=robot.baseX and robot.x<=robot.mineX,"physical movement bounds") end
   end
   check(run.phase=="combat","mining terminates")
  end
 end
 check(#run.weapons==4,"four auxiliaries")
end
print("AUDIT NATIVE PASS",checks)
