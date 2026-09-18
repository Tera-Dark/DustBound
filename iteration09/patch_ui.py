from pathlib import Path
p=Path('preview/app.js');s=p.read_text().replace('canvas,ctx,modalOrigin;','canvas,ctx,modalOrigin,recallToken;')
s=s.replace('<div class="battle-dock">','<div class="tactical-bar"><div class="target-controls" aria-label="主炮目标优先级"><small>主炮优先</small><button data-aim="nearest">近身</button><button data-aim="air">空中</button><button data-aim="armor">重甲</button></div><span id="encounterIntel"></span><button class="secondary" id="recall">提前收队 →</button></div><div class="battle-dock">')
s=s.replace("$('#stageHint').textContent=mining?`采矿窗口 / ${Math.ceil(state.breakLeft)}s`:`${state.wave>=3?'空袭信号已激活':'空域监测中'} / 地面双侧进攻`;", "$('#stageHint').textContent=mining?(state.prepare?.recalling?'工蜂回收中 / 货物保留':`采矿窗口 / ${Math.ceil(state.breakLeft)}s`):`${state.encounter.name} / ${state.encounter.count} 个信号`;$('#encounterIntel').textContent=mining?`下一波 · ${state.nextEncounter?.name||'—'} / 在途 ${state.prepare?.retainedCargo||0} · 继续预计再采 ${state.prepare?.futureOre||0}`:`${state.encounter.tip}`;$('#recall').hidden=!mining;$('#recall').disabled=state.paused||!!state.supply||!!state.prepare?.recalling;$$('[data-aim]').forEach(b=>{b.classList.toggle('selected',b.dataset.aim===state.targetMode);b.setAttribute('aria-pressed',b.dataset.aim===state.targetMode);b.disabled=state.paused||!!state.supply;});")
s=s.replace('1-state.breakLeft/30','1-state.breakLeft/(state.prepare?.duration||18)').replace("'工蜂钻探 → 载货返航 → 入库获得金矿。整备结束后自动迎战。'","'提前收队保留已采货物，放弃未完成钻探。倒计时结束也会安全返航。'")
s=s.replace("(i*4)","([0,1,4,8,12][i])")
s=s.replace("return modal;}\nfunction closeModal", "if(modal==='confirmRecall'&&(state.stage!=='mining'||state.prepare?.recalling)){modal='';recallToken=null;}return modal;}\nfunction closeModal")
s=s.replace("state.result?.runId,state.relics]", "state.result?.runId,state.relics,(m==='combat'||m==='mining')?state.investments:null,m==='confirmRecall'?state.prepare:null]")
s=s.replace("id=\"modalClose\" aria-label", "id=\"modalDismiss\" aria-label")
s=s.replace("const d=meta.upgrades[id],price=state.prices[id],level=state.upgrades[id]||0;", "const d=meta.upgrades[id],v=state.investments[id],price=v.price,level=v.level;")
s=s.replace('${esc(d.description)}</p><button class="${price&&state.ore>=price?', '${esc(v.detail)}</p><button class="${v.canBuy?').replace("${!price||state.ore<price?'disabled':''}","${!v.canBuy?'disabled':''}").replace("${price?'投资 · '+price+' 金矿':'已达上限'}", "${v.canBuy?'投资 · '+price+' 金矿':esc(v.reason)+(price?' · '+price+' 金矿':'')}")
s=s.replace("else if(m==='mining'||m==='combat')", """else if(m==='confirmRecall'){const f=state.prepare;html=modalShell('PREPARATION / 收队确认','用矿量，换取更快推进。',`<p class="small">下一波：${esc(state.nextEncounter?.name)}。${esc(state.nextEncounter?.tip)}</p><div class="recall-quote"><b>已采在途 ${f.retainedCargo} 金矿：全部保留</b><p>继续到计时结束，预计还能采到约 ${f.futureOre} 金矿。</p><p>现在收队将放弃未完成钻探；工蜂返航最多约 ${Math.ceil(f.returnEta)} 秒。</p></div><p class="small">按当前机器人与速度估算，不含后续投资。面板不会暂停采矿，确认时以服务器当前状态为准。</p>`,'<button class="secondary" id="modalClose">继续采矿</button><button class="primary" id="confirmRecall">确认收队 →</button>',false,false);}
else if(m==='mining'||m==='combat')""")
s=s.replace('完成第 1 / 5 / 9 / 13 / 17 波','完成第 2 / 5 / 9 / 13 / 17 波').replace('清场后有 30 秒整备窗口。','首两次整备各 18 秒，之后 14 秒，可提前收队。').replace('主炮自动瞄准。爬行怪从两侧接近，掠翼虫第 3 波起从天空进攻。','主炮支持近身、空中、重甲优先。第一波后选副武器，第 2 波护甲编队，第 3 波空地夹击。')
s=s.replace('${esc(d.detail||d.desc)}</p><button', '${esc(d.detail||d.tip||d.desc)}</p><button')
s=s.replace('选择期间战斗与采矿暂停</p><div class="offer-grid">','选择期间战斗与采矿暂停</p><p class="intel-brief">下一波 · ${esc(state.nextEncounter?.name)}：${esc(state.nextEncounter?.tip)}</p><div class="offer-grid">')
s=s.replace("</p>`,'<button class=\"primary\" id=\"returnMenu\">", "</p><div class=\"recap\"><b>火力贡献</b>${Object.entries(r.recap?.weaponDamage||{}).sort((a,b)=>b[1]-a[1]).map(([id,n])=>`<div class=\"stat-row\"><span>${esc(meta.catalog.weapons[id]?.name||id)}</span><b>${Math.round(n)}</b></div>`).join('')}<p>最高承伤：${r.recap?.worstWave?'第 '+r.recap.worstWave+' 波 · '+Math.round(r.recap.worstTaken)+' 点':'未承伤'}</p><p>${esc(r.recap?.tip)}</p></div>`,'<button class=\"primary\" id=\"returnMenu\">")
s=s.replace("if(b.dataset.buy){", "if(b.dataset.aim){await post('target_mode',b.dataset.aim);return;}if(b.id==='recall'){recallToken=state.prepare?.token;modal='confirmRecall';renderModal();return;}if(b.id==='confirmRecall'){b.disabled=true;modal='';await post('recall',{token:recallToken});recallToken=null;renderModal();return;}if(b.dataset.buy){")
s=s.replace("case 'resume':case 'modalClose':", "case 'resume':case 'modalDismiss':case 'modalClose':")
s=s.replace("e.kind==='tank'?'tankBody':'crawlerBody'", "e.kind==='tank'?'tankBody':e.kind==='runner'?'runnerBody':'crawlerBody'")
s=s.replace("'crawlerBody','tankBody','drillBit'", "'crawlerBody','runnerBody','tankBody','drillBit'")
s=s.replace("if(state.wave>=3)label", "if(state.encounter?.pattern==='air')label")
# Keep focus across quote / health updates instead of discarding keyboard focus.
s=s.replace("$('#modalRoot').innerHTML=html;if(!had)", "const focused=document.activeElement;const focusKey=focused?.id?'#'+focused.id:focused?.dataset.buy?'[data-buy=\"'+focused.dataset.buy+'\"]':null;$('#modalRoot').innerHTML=html;if(had&&focusKey)$('#modalRoot '+focusKey)?.focus({preventScroll:true});if(!had)")
p.write_text(s)
p=Path('preview/style.css');s=p.read_text()+'''\n/* 0.9 / authoritative tactical choices */
.tactical-bar{display:flex;align-items:center;gap:20px;padding:13px 18px;background:#20353c;border-top:1px solid #a3c5a226;min-height:76px}.target-controls{display:flex;gap:5px;align-items:center;flex-shrink:0}.target-controls small{margin-right:6px;color:var(--muted)}.target-controls button{padding:9px 13px;color:var(--text);border:1px solid #a3c5a244;background:transparent;border-radius:5px}.target-controls button.selected{color:#17332d;background:var(--mint)}#encounterIntel{font-size:12px;line-height:1.7;flex:1;color:#d2d9bd}#recall{flex-shrink:0}.recall-quote,.recap,.intel-brief{padding:18px;background:#172c32;border:1px solid #98c5ac40;border-radius:8px;color:#d1dfc9;line-height:1.8}.recap p{font-size:13px;margin-top:12px}.intel-brief{margin:12px 0;font-size:13px}.shop-card p{min-height:42px}.shop-card button:disabled{opacity:.6}
@media(max-width:800px){.tactical-bar{flex-wrap:wrap;gap:12px}.target-controls{flex:1}.target-controls button{padding:10px}#encounterIntel{order:3;flex-basis:100%}#recall{font-size:12px;padding:10px}.recap{padding:12px}}
''';p.write_text(s)
p=Path('preview/index.html');p.write_text(p.read_text().replace('0.8.0 / FRONTIER EDITION','0.9.0 / FIRST CONTACT'))
p=Path('preview/server.py');p.write_text(p.read_text().replace("'0.8.0 FRONTIER'","'0.9.0 FIRST CONTACT'"))
# Native parity: no currency / targeting authority is put in the client.
p=Path('src/Frontier.lua');s=p.read_text().replace('0.8 / FRONTIER','0.9 / FIRST CONTACT').replace('function F.battleHud(ctx,parent,s,view,open)','function F.battleHud(ctx,parent,s,view,open,send)')
s=s.replace(' local dock=U.panel(parent,"BattleDock"', ''' local tactics=U.panel(parent,"TacticalBar",0,-68,1380,56,c.cream)
 for i,v in ipairs({{"nearest","近身"},{"air","空中"},{"armor","重甲"}}) do
  local btn=U.button(tactics,"Aim_"..v[1],"主炮 / "..v[2],12+(i-1)*147,8,137,40,function() send("target_mode",v[1]) end,s.targetMode==v[1]);btn.TextSize=16;U.enabled(btn,not s.paused and not s.supply)
 end
 U.text(tactics,"WaveIntel",s.stage=="mining" and "下波 / "..(s.nextEncounter and s.nextEncounter.name or "—") or "当前 / "..(s.encounter and s.encounter.name or "—"),478,7,560,42,18,c.ink,true)
 local recall=U.button(tactics,"Recall","提前收队 →",1118,8,246,40,function() open("confirm_recall") end,true)
 recall.TextSize=17;recall.Visible=s.stage=="mining";U.enabled(recall,s.prepare and not s.prepare.recalling and not s.supply and not s.paused or false)
 local dock=U.panel(parent,"BattleDock"''')
p.write_text(s)
p=Path('src/Client.client.lua');s=p.read_text().replace('local shopButtons={};','local shopButtons={};local recallToken=nil;local recallText=nil;')
s=s.replace('local function open(v) view=v;dirty=true end','local function open(v) if v=="confirm_recall" then recallToken=snap.prepare and snap.prepare.token end;view=v;dirty=true end')
s=s.replace('F.battleHud({U=U,C=C,Art=Art},hud,snap,view,open)', 'F.battleHud({U=U,C=C,Art=Art},hud,snap,view,open,send)')
s=s.replace('  elseif modalView=="mining" or modalView=="combat" then','''  elseif modalView=="confirm_recall" and snap.prepare then
   text(panel,"Title","提前收队 / 用矿量换取更快推进",28,12,1080,60,30,true)
   text(panel,"NextWave","下一波："..snap.nextEncounter.name.."\n"..snap.nextEncounter.tip,28,80,1080,100,22)
   recallText=text(panel,"RecallQuote","",28,192,1080,120,25,true)
   text(panel,"RecallNote","按当前机器人配置估算；面板不会暂停采矿。确认时以服务器状态为准。",28,334,1080,48,18)
   button(panel,"CancelRecall","继续采矿",28,416,510,64,close)
   button(panel,"ConfirmRecall","确认收队 →",570,416,560,64,function() local token=recallToken;open(nil);send("recall",{token=token}) end,true)
  elseif modalView=="mining" or modalView=="combat" then''')
s=s.replace('local b=button(panel,"Buy_"..id,d.name.."  Lv."..level.."\\n"..(price and price.." 金矿" or "已满级"),', 'local b=button(panel,"Buy_"..id,"",')
s=s.replace('shopButtons[id]=b;U.enabled(b,price~=false and price~=nil and snap.ore>=price and not snap.paused)', 'shopButtons[id]=b;b.TextSize=18;U.enabled(b,snap.investments[id].canBuy)')
s=s.replace('d.detail or d.desc or "独立攻击的副武器"','d.detail or d.tip or d.desc or "独立攻击的副武器"')
s=s.replace('"选择期间暂停战斗与采矿；没有购买费用。"','"下波："..(snap.nextEncounter and snap.nextEncounter.name or "—").." · 选择免费，期间暂停采矿。"')
s=s.replace('28,226,1060,96,24)', '28,213,1060,66,21)')
s=s.replace('   button(panel,"ReturnMenu"', '''   if r.recap then
    local totals={};for _,id in ipairs(C.Catalog.order.weapons) do if r.recap.weaponDamage[id] then totals[#totals+1]=C.Catalog.weapons[id].name.." "..math.floor(r.recap.weaponDamage[id]) end end
    text(panel,"WeaponDamage","火力贡献 / "..table.concat(totals," · "),28,284,1080,48,18)
    text(panel,"WorstWave",r.recap.worstWave>0 and "最高承伤：第 "..r.recap.worstWave.." 波 · "..math.floor(r.recap.worstTaken).." 点" or "全局未承伤",28,337,1080,32,20,true)
    text(panel,"RecapTip",r.recap.tip,28,374,690,100,19)
   end
   button(panel,"ReturnMenu"''')
s=s.replace('   snap=s;age=0', '   snap=s;age=0\n   if view=="confirm_recall" and (s.stage~="mining" or s.prepare and s.prepare.recalling) then view=nil;dirty=true end')
s=s.replace('s.phase..tostring(s.paused)', 's.phase..s.stage..tostring(s.targetMode)..tostring(s.prepare and s.prepare.recalling)..tostring(s.paused)')
s=s.replace('"采矿窗口 / 工蜂采掘后返航入库 · 倒计时结束自动迎战下一波"', '"采矿 / 已采在途 "..(snap.prepare and snap.prepare.retainedCargo or 0).." · 继续预计再采 "..(snap.prepare and snap.prepare.futureOre or 0).." 金矿；提前收队保留已采货物"')
s=s.replace('"防御协议 / 地面虫从两侧进攻 · 掠翼虫从上方突袭 · P 暂停"', '(snap.encounter and snap.encounter.tip or "主炮自动射击 · P 暂停")')
s=s.replace('local value=C.Upgrades[id].name.."  Lv."..level.."\\n"..(price and price.." 金矿" or "已满级")','local v=snap.investments[id];local value=C.Upgrades[id].name.."  Lv."..level.."\\n"..v.detail.."\\n"..(v.canBuy and price.." 金矿" or v.reason)')
s=s.replace('U.enabled(b,price and snap.ore>=price and not snap.paused or false)', 'U.enabled(b,v.canBuy)')
s=s.replace('   if not painted then', '''   if view=="confirm_recall" and recallText and snap.prepare then
    local f=snap.prepare;recallText.Text="已采在途 "..f.retainedCargo.." 金矿：全部保留\\n继续预计再采约 "..f.futureOre.." 金矿；收队将放弃未完成钻探\\n返航最多约 "..math.ceil(f.returnEta).." 秒"
   end
   if not painted then''')
p.write_text(s)
