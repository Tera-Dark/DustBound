"""Real-time browser first-wave + mining check; no state/time/resource injection.
Start preview/server.py first. Usually takes 35-60 seconds.
"""
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True)
    page=browser.new_page(viewport={'width':1440,'height':1000})
    errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
    page.goto('http://localhost:8080')
    page.locator('.hero [data-nav="campaign"]').click()
    page.locator('#depart').click()
    page.wait_for_function('state && state.enemies && Object.values(state.enemies).length >= 1',timeout=20000)
    page.screenshot(path=str(ROOT/'docs/preview-08/ground-combat.png'),full_page=True)
    page.locator('[data-choice]').first.wait_for(timeout=65000)
    gold=page.evaluate('state.ore')
    page.locator('[data-choice]').first.click()
    page.wait_for_function('!state.supply && Object.values(state.robots).some(r => r.state === "drilling")',timeout=10000)
    assert page.evaluate('state.ore')==gold
    page.screenshot(path=str(ROOT/'docs/preview-08/mining.png'),full_page=True)
    page.wait_for_function('state.totalMined > 0',timeout=10000)
    assert page.evaluate('state.ore === 120 + state.totalMined - state.ledger.spent')
    page.locator('#pause').click();page.wait_for_function('state.paused')
    before=page.evaluate('state.elapsed');page.wait_for_timeout(1100)
    assert page.evaluate('state.elapsed')==before
    page.locator('[data-modal="abandon"]').click();page.locator('#confirmAbandon').click();page.locator('.hero').wait_for()
    assert not errors,errors
    print('REAL-TIME GAMEPLAY PASS: ground combat, natural wave clear, free relic, actual drilling, return deposit, gold conservation, pause freeze. No injected resources or accelerated time; no uncaught JS errors.')
    browser.close()
