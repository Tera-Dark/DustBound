-- Development graph adapter. Old persistent IDs/ownership survive; choices replace mandatory chains.
local W={}
local function clone(raw)
 if type(raw)~="table" then return raw end
 local out={};for k,v in pairs(raw) do out[k]=clone(v) end;return out
end
local localPositions={{0,0},{176,-66},{176,66},{352,-66},{352,66},{528,-66},{528,66},{704,0}}
function W.build(old)
 local t=clone(old)
 for col,branch in ipairs(t.branches) do
  local prefix=branch.id.."_"
  for tier=1,8 do
   local n=t.nodes[prefix..tier];n.prereqs={};n.anyPrereqs={}
   if tier==2 or tier==3 then n.prereqs={prefix.."1"}
   elseif tier==4 or tier==5 then n.anyPrereqs={prefix.."2",prefix.."3"}
   elseif tier==6 or tier==7 then n.anyPrereqs={prefix.."4",prefix.."5"}
   elseif tier==8 then n.anyPrereqs={prefix.."6",prefix.."7"} end
   -- Optional bridges, never a compulsory trek through another full branch.
   if tier==5 then n.anyPrereqs[#n.anyPrereqs+1]=t.branches[col%6+1].id.."_2" end
   if tier==7 then n.anyPrereqs[#n.anyPrereqs+1]=t.branches[(col+4)%6+1].id.."_4" end
   local pos=localPositions[tier]
   n.mapX=140+((col-1)%2)*940+pos[1]
   n.mapY=200+math.floor((col-1)/2)*360+pos[2]
  end
 end
 return t
end
function W.prerequisiteState(profile,node)
 for _,pre in ipairs(node.prereqs or {}) do if not profile.tech[pre] then return false,{pre},"all" end end
 if #(node.anyPrereqs or {})>0 then
  for _,pre in ipairs(node.anyPrereqs) do if profile.tech[pre] then return true,{},"any" end end
  return false,clone(node.anyPrereqs),"any"
 end
 return true,{},"all"
end
-- Same-family connections have short orthogonal segments. Cross-family bridges are portals.
function W.edges(tree,id)
 local node=tree.nodes[id];local out={}
 for _,group in ipairs({{ids=node.prereqs,mode="all"},{ids=node.anyPrereqs,mode="any"}}) do
  for _,pre in ipairs(group.ids or {}) do
   local p=tree.nodes[pre];local edge={from=pre,to=id,mode=group.mode,portal=p.branch~=node.branch}
   if not edge.portal then
    local sx,tx=p.mapX+64,node.mapX-64;local mid=(sx+tx)/2
    edge.points={{sx,p.mapY},{mid,p.mapY},{mid,node.mapY},{tx,node.mapY}}
   end
   out[#out+1]=edge
  end
 end
 return out
end
return W
