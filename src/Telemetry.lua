-- Server-only bounded diagnostics; optional Roblox custom events. No external endpoints.
local T={}
local allowed={ui_ready=true,run_start=true,next_run_start=true,first_purchase=true,wave_clear=true,supply_accept=true,
 first_robot_deposit=true,run_end=true,tutorial_complete=true,research_complete=true,research_target=true,pause=true,resume=true,
 abandon=true,save_failure=true,disconnect=true,open_research=true,open_codex=true,open_settings=true,client_error=true,
 time_combat=true,time_clearing=true,time_mining=true,time_supply=true,time_pause=true}
function T.new() return {counts={},recent={},sent=0,failed=0,input="unknown",uiReady=false,joined=os.clock(),status="仅本地诊断"} end
function T.record(t,player,C,name,value,s)
 if not allowed[name] then return end
 value=type(value)=="number" and value==value and math.max(0,math.min(7200,value)) or 1
 t.counts[name]=(t.counts[name] or 0)+1
 t.recent[#t.recent+1]={name=name,value=value,wave=s and s.wave or 0};if #t.recent>48 then table.remove(t.recent,1) end
 if not C.EnableAnalytics or game.GameId==0 then return end
 local okStudio,studio=pcall(function() return game:GetService("RunService"):IsStudio() end)
 if not okStudio or studio then t.status="Studio 仅本地诊断";return end
 local ok=pcall(function()
  game:GetService("AnalyticsService"):LogCustomEvent(player,name,value,{CustomField01=C.Version,CustomField02=s and s.mode or "menu",CustomField03=t.input})
 end)
 if ok then t.sent=t.sent+1;t.status="已调用平台分析 API（面板接收待核验）" else t.failed=t.failed+1;t.status="分析 API 失败 · 本地事件仍保留" end
end
function T.consume(t,player,C,s)
 for _,event in ipairs(s.metrics or {}) do T.record(t,player,C,event.name,event.value,s) end
 s.metrics={}
end
function T.summary(t)
 local total=0;for _,n in pairs(t.counts) do total=total+n end
 return {total=total,status=t.status,sent=t.sent,failed=t.failed,counts=t.counts}
end
return T
