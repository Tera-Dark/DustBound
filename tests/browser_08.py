"""Real Chromium review of the browser presentation, not a Roblox engine test.
Start preview/server.py first. Run python tests/browser_08.py.
"""
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
with sync_playwright() as p:
    b=p.chromium.launch(headless=True)
    page=b.new_page(viewport={'width':1440,'height':1000},device_scale_factor=1)
    errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
    def shot(name):
        page.screenshot(path=str(ROOT/'docs/preview-08'/f'{name}.png'),full_page=True)
    page.goto('http://localhost:8080');page.get_by_role('heading',name='DUSTBOUND',exact=True).wait_for();shot('home')
    page.locator('.hero [data-nav="campaign"]').click();page.locator('#depart').wait_for();shot('campaign')
    assert page.locator('[data-node="2"]').is_disabled()
    page.locator('#depart').click();page.locator('#battleCanvas').wait_for();page.wait_for_timeout(500);shot('battle')
    page.locator('#pause').click();page.get_by_role('button',name='继续远征 →').wait_for();page.get_by_role('button',name='继续远征 →').click()
    page.locator('[data-modal="mining"]').click();page.get_by_role('heading',name='让每一趟采掘更有价值。').wait_for();page.locator('[data-buy="move"]').click();page.wait_for_timeout(600)
    assert '30' in page.locator('#oreText').inner_text()
    page.locator('#modalClose').first.click();page.locator('#pause').click();page.locator('[data-modal="abandon"]').click();page.locator('#confirmAbandon').click();page.locator('.hero').wait_for()
    page.locator('nav [data-nav="research"]').click();page.locator('[data-tech="industry_3"]').click();shot('research')
    assert page.locator('#researchBuy').is_disabled()
    page.locator('nav [data-nav="codex"]').click();page.locator('[data-codex="enemies"]').click();shot('codex')
    assert page.locator('.codex-card').count()==3
    page.locator('#settingsButton').click();page.locator('[data-setting="masterMuted"]').click();page.wait_for_timeout(300);shot('settings')
    assert page.locator('[data-setting="masterMuted"]').get_attribute('aria-checked')=='true'
    page.set_viewport_size({'width':390,'height':844});page.locator('nav [data-nav="home"]').click();shot('mobile')
    assert not page.evaluate('document.documentElement.scrollWidth>innerWidth'), 'mobile horizontal overflow'
    for target in ['campaign','research','codex']:
        page.locator(f'nav [data-nav="{target}"]').click()
        assert not page.evaluate('document.documentElement.scrollWidth>innerWidth'), target+' horizontal overflow'
    assert not errors,errors
    print('BROWSER PASS: boot, campaign locks, deploy, pause/resume, purchase, abandon, research, codex, settings, mobile layout. No uncaught JS errors.')
    b.close()
