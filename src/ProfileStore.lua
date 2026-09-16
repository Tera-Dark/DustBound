-- Cloud I/O is optional and never a prerequisite for the independent boot screen.
-- Read failure is BLOCKED, not an empty writable cloud profile. Guest mode is explicit.
local shared=game:GetService("ReplicatedStorage"):WaitForChild("FrontierShared",10)
assert(shared,"FrontierShared missing")
local R=require(shared:WaitForChild("Rules",10));local C=require(shared:WaitForChild("Config",10))
local P={}
function P.session(message)
 return {data=R.cleanProfile(nil),token="",persistent=false,busy=false,blocked=false,mode="local",revision=0,savedRevision=0,lastSaved=0,
 status=message or "本地试玩 · Stop 后不保存"}
end
function P.touch(record)
 record.revision=record.revision+1
 if record.persistent and not record.busy and not record.blocked and record.mode~="save_error" then record.status="有更新待保存" end
end
function P.open(userId,retryToken)
 local record=P.session()
 if not C.EnableCloudSave then return record end
 if game.GameId==0 or game.PlaceId==0 then record.status="未发布工程 · 本地试玩，不写入云端";return record end
 record.blocked=true;record.mode="read_error";record.status="正在读取云存档"
 local reason="暂时无法读取，或其他服务器仍持有此存档"
 local ok,result=pcall(function()
  local http=game:GetService("HttpService");record.token=type(retryToken)=="string" and retryToken~="" and retryToken or http:GenerateGUID(false)
  record.store=game:GetService("DataStoreService"):GetDataStore(C.SaveName)
  return record.store:UpdateAsync("u_"..userId,function(old)
   if old~=nil and (type(old)~="table" or type(old.data)~="table") then reason="云档结构异常，已阻止覆盖，请联系开发者检查";return nil end
   old=old or {}
   if type(old.data)=="table" and type(old.data.schema)=="number" and old.data.schema>5 then reason="云档版本较新，请更新游戏工程";return nil end
   local lock=type(old.lock)=="table" and old.lock or nil
   if lock and R.finite(lock.untilTime) and lock.untilTime>os.time() and lock.token~=record.token then reason="另一服务器仍持有存档；稍后重试";return nil end
   return {data=R.cleanProfile(old.data),lock={token=record.token,untilTime=os.time()+180},lastWriteId=old.lastWriteId}
  end)
 end)
 if ok and result and result.lock and result.lock.token==record.token then
  record.data=R.cleanProfile(result.data);record.persistent=true;record.blocked=false;record.mode="cloud";record.status="云存档已连接"
 else record.store=nil;record.status="云档读取失败："..reason;warn("[DUSTBOUND storage] load blocked: "..tostring(result)) end
 return record
end
function P.guest() local r=P.session("访客试玩 · 不合并、不覆盖云档，离开后不保存");r.mode="guest";return r end
function P.save(userId,record,release)
 if not record.persistent or not record.store or record.blocked then return false end
 if record.busy then
  if not release then return false end
  local untilTime=os.clock()+10
  repeat task.wait(.1) until not record.busy or os.clock()>untilTime
  if record.busy then return false end
 end
 record.busy=true;record.mode="saving";record.status="保存中…"
 local p=record.pending
 if not p then
  p={id=record.token..":"..tostring(record.revision),revision=record.revision,data=R.cleanProfile(record.data)};record.pending=p
 end
 local lost=false
 local ok,result=pcall(function()
  return record.store:UpdateAsync("u_"..userId,function(old)
   if type(old)~="table" or type(old.lock)~="table" or old.lock.token~=record.token then lost=true;return nil end
   -- Idempotent retries always write the same clean snapshot; no reward increment in this callback.
   return {data=p.data,lock=not release and {token=record.token,untilTime=os.time()+180} or nil,lastWriteId=p.id}
  end)
 end)
 record.busy=false
 if ok and result and result.lastWriteId==p.id then
  record.pending=nil;record.savedRevision=p.revision;record.lastSaved=os.time();record.mode="cloud"
  record.status=record.revision>p.revision and "部分更新已保存 · 仍有待保存修改" or "上次云保存成功"
  if release then
   -- A previous failed snapshot must be flushed before releasing a newer in-memory revision.
   record.persistent=false
  end
  return true
 end
 if lost then record.blocked=true;record.persistent=false;record.mode="lock_lost";record.status="存档锁已失效 · 已停止云写入，请重新加入，勿覆盖云档"
 else record.mode="save_error";record.status="保存失败 · 当前进度仅暂存内存，请重试后再离开" end
 warn("[DUSTBOUND storage] save failed: "..tostring(result));return false
end
-- Retry an outstanding write first, then flush any newer mutations. Never merge guest data into cloud.
function P.flush(userId,record,release)
 if record.pending then
  if not P.save(userId,record,false) then return false end
 end
 return P.save(userId,record,release)
end
return P
