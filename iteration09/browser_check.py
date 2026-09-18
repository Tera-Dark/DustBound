"""Real-time first loop: no injected state, money, time or profile."""
from pathlib import Path
import time,json
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'iteration09/results';shots=OUT/'screens';shots.mkdir(exist_ok=True)
with sync_playwright() as p:
 browser=p.chromium.launch(headless=True);page=browser.new_page(viewport={'width':1440,'height':1100});errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
 def shot(n):page.screenshot(path=str(shots/(n+'.png')),full_page=True)
 page.goto('http://localhost:8080');page.locator('.hero').wait_for();page.locator('.hero [data-nav="campaign"]').click();page.locator('#depart').click();page.locator('#battleCanvas').wait_for();start=time.monotonic()
 page.locator('[data-modal="combat"]').click();assert page.locator('[data-buy="repair"]').is_disabled();assert '→' in page.locator('.shop-grid').inner_text();shot('investment')
 page.locator('[data-buy="damage"]').click();page.locator('#modalClose').click()
 page.locator('[data-aim="armor"]').click();page.wait_for_function("state.targetMode==='armor'")
 page.locator('[data-choice="arc"]').wait_for(timeout=50000);first=page.evaluate('state.elapsed');shot('first-weapon');page.locator('[data-choice="arc"]').click()
 page.wait_for_function('state.totalMined>0',timeout=12000);page.locator('#recall').click();page.locator('#confirmRecall').wait_for();shot('recall')
 page.locator('#confirmRecall').click();page.wait_for_function("state.wave===2",timeout=6000)
 page.locator('[data-aim="nearest"]').click();shot('escort')
 page.locator('[data-choice]').first.wait_for(timeout=65000);page.locator('[data-choice]').first.click()
 page.locator('#pause').click();page.wait_for_function('state.paused');before=page.evaluate('state.elapsed');page.wait_for_timeout(600);assert page.evaluate('state.elapsed')==before;page.locator('#resume').click()
 page.locator('[data-aim="air"]').click();page.wait_for_function("Object.values(state.enemies).some(e=>e.kind==='flyer')",timeout=50000);shot('air')
 page.wait_for_function("state.phase==='ended'",timeout=65000);shot('result');assert page.locator('.recap').count()==1
 result=page.evaluate('state.result');assert result['won'];assert result['recap']['weaponDamage']['arc']>0
 page.locator('#returnMenu').click();page.locator('nav [data-nav="research"]').click();page.locator('[data-tech="fort_1"]').click();page.locator('#researchBuy').click();page.wait_for_function('state.profile.tech.fort_1===true')
 page.locator('nav [data-nav="campaign"]').click();assert not page.locator('[data-node="2"]').is_disabled();assert page.locator('[data-node="3"]').is_disabled()
 page.set_viewport_size({'width':390,'height':844});page.locator('[data-node="2"]').click();page.locator('#depart').click();page.locator('#battleCanvas').wait_for();shot('mobile')
 assert page.evaluate('document.documentElement.scrollWidth<=window.innerWidth')
 page.locator('[data-modal="combat"]').click();shot('mobile-investment');assert page.evaluate('document.documentElement.scrollWidth<=window.innerWidth')
 assert not errors,errors
 (OUT/'browser.json').write_text(json.dumps({'method':'Real Chromium + actual Lua server; ordinary controls, fresh profile, no acceleration/injections. Not Roblox Studio.','firstWeaponSeconds':first,'wallSeconds':round(time.monotonic()-start,2),'result':result,'errors':errors,'mobileWidth':390,'mobileOverflow':False},ensure_ascii=False,indent=2))
 print('BROWSER PASS',result['seconds'],'sim seconds',round(time.monotonic()-start,1),'wall seconds');browser.close()
