-- 0.9 deterministic, authored wave groups. No RNG hidden in the renderer.
-- A queued group never disappears when the live-enemy cap is reached.
local E={}
function E.plan(node,wave)
 local groups={};local function add(at,kind,count,side)
  groups[#groups+1]={at=at,kind=kind,count=count,side=side or 0}
 end
 local extra=math.min(3,math.floor((wave-1)/4))+math.floor((node-1)/12)
 local pattern=wave==1 and "arrival" or wave==2 and "escort" or wave==3 and "air" or ({"rush","escort","air"})[(wave-4)%3+1]
 local name,tip
 if pattern=="arrival" then
  name="着陆警戒";tip="主炮自动射击。清场后获得第一把副武器；先观察两侧接敌。"
  add(2,"crawler",2+extra,0);add(6,"crawler",2+extra,-1);add(10,"crawler",2+extra,1);add(14,"crawler",3+extra,0);add(18,"crawler",3+extra,-1)
 elseif pattern=="escort" then
  name="重甲护送";tip="甲壳虫吸收普通伤害，随后疾行虫突进。磁轨克甲，主炮可切换重甲优先。"
  for i=0,2 do add(2+i*6,"tank",1+math.floor(extra/2),i%2==0 and -1 or 1);add(3+i*6,"crawler",3+extra,i%2==0 and -1 or 1) end
  add(19,"runner",3+extra,0)
 elseif pattern=="air" then
  name="空地夹击";tip="第 5 / 12 / 19 秒出现空中编队。机枪优先拦截快敌；必要时切主炮为空中优先。"
  add(2,"crawler",3+extra,-1);add(5,"flyer",3+extra,0);add(9,"crawler",3+extra,1)
  add(12,"flyer",3+extra,0);add(16,"runner",2+extra,0);add(19,"flyer",2+extra,0)
 else
  name="疾行突围";tip="快速小群分三批冲线。电弧处理密集队列，喷焰覆盖近身漏网单位。"
  for i=0,2 do add(2+i*7,"crawler",3+extra,0);add(4+i*7,"runner",4+extra,i%2==0 and 1 or -1) end
 end
 local kinds,seen={},{};local count=0
 for _,g in ipairs(groups) do if not seen[g.kind] then seen[g.kind]=true;kinds[#kinds+1]=g.kind end;count=count+g.count end
 return {name=name,tip=tip,pattern=pattern,groups=groups,kinds=kinds,count=count,duration=24}
end
function E.intel(node,wave)
 local p=E.plan(node,wave)
 return {name=p.name,tip=p.tip,pattern=p.pattern,kinds=p.kinds,count=p.count,duration=p.duration}
end
return E
