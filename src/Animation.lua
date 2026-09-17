-- Engine-independent presentation math. No damage, mining income or authoritative clocks.
local A={}
function A.clamp(v,a,b) return math.max(a,math.min(b,v)) end
function A.alpha(rate,dt) return 1-math.exp(-rate*math.max(0,dt)) end
function A.smooth(t) t=A.clamp(t,0,1);return t*t*(3-2*t) end
function A.spring(x,v,omega,dt)
 local e=math.exp(-omega*dt);local j=(v+omega*x)*dt
 return (x+j)*e,(v-omega*j)*e
end
function A.robotPhase(r,since,cycle)
 return (r.t+math.max(0,since-(r.delay or 0))/math.max(.01,cycle))%1
end
function A.robotPath(phase,id)
 local mine=755+(id-1)*112;local x,deploy,state
 if phase<.25 then x=385+(mine-385)*A.smooth(phase/.25);deploy=0;state="outbound"
 elseif phase<.28 then x=mine;deploy=A.smooth((phase-.25)/.03);state="deploying"
 elseif phase<.68 then x=mine;deploy=1;state="drilling"
 elseif phase<.72 then x=mine;deploy=1-A.smooth((phase-.68)/.04);state="retracting"
 elseif phase<.95 then x=mine+(385-mine)*A.smooth((phase-.72)/.23);deploy=0;state="returning"
 else x=385;deploy=0;state="unloading" end
 return x,deploy,state
end
function A.enemyX(previous,current,at,now,range)
 if previous and at>previous.at and now<at then
  local t=A.clamp((now-previous.at)/(at-previous.at),0,1)
  return previous.x+(current.x-previous.x)*t
 end
 return math.max(range,current.x-current.speed*A.clamp(now-at,0,.2))
end
function A.projectile(p,now)
 local q=A.clamp((now-p.born)/math.max(.001,p.duration),0,1)
 local dx,dy=p.tx-p.x,p.ty-p.y;local arc=p.arc or 0
 return p.x+dx*q,p.y+dy*q-4*arc*q*(1-q),math.deg(math.atan2(dy-4*arc*(1-2*q),dx)),q
end
function A.mountWeapon(snapshot,slot)
 if snapshot.weaponSlots then
  local entry=snapshot.weaponSlots[slot]
  return entry and entry.enabled and entry.weapon or nil
 end
 if slot==1 then return "cannon" elseif slot==2 then return snapshot.loadout end
 return nil
end
return A
