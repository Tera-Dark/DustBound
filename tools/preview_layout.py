"""Offline layout check: execute the actual Lua UI in a mock, serialize GUI -> HTML.
NOT a Roblox screenshot. Requires test dependencies; optional --capture uses Playwright.
"""
from pathlib import Path
import sys,html,base64,json,argparse
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from test_ui import host,client

def val(obj,key,default=None):
 try:
  v=obj[key];return default if v is None else v
 except:return default

def rgb(c):
 if c is None:return 'transparent'
 return 'rgb('+','.join(str(round(c[i])) for i in range(1,4))+')'
def dim(d,axis):
 if d is None:return '0px'
 return f'calc({val(d,axis+"s",0)*100}% + {val(d,axis+"o",0)}px)'
def render(obj):
 p=obj._props;cl=p.ClassName
 if cl not in ['ScreenGui','Frame','TextLabel','TextButton','TextBox','ImageLabel','ScrollingFrame']:return ''
 if p.Visible is False or p.Enabled is False:return ''
 children=list(obj._children.values())
 if cl=='ScreenGui':
  inset=36 if p.ScreenInsets=='CoreUISafeInsets' else 0
  return f'<div style="position:absolute;left:0;top:{inset}px;width:100%;height:calc(100% - {inset}px);z-index:{val(p,"DisplayOrder",0)}">'+''.join(render(c) for c in children)+'</div>'
 styles=['position:absolute','box-sizing:border-box','isolation:isolate']
 styles+=['left:'+dim(p.Position,'x'),'top:'+dim(p.Position,'y'),'width:'+dim(p.Size,'x'),'height:'+dim(p.Size,'y')]
 alpha=val(p,'BackgroundTransparency',0)
 if alpha<1 and p.BackgroundColor3 is not None:
  c=p.BackgroundColor3;styles.append(f'background:rgba({c[1]},{c[2]},{c[3]},{1-alpha})')
 a=p.AnchorPoint;anchor=val(a,'X',0),val(a,'Y',0)
 scale=next((val(c,'Scale',1) for c in children if c.ClassName=='UIScale'),1)
 styles.append(f'transform-origin:{anchor[0]*100}% {anchor[1]*100}%')
 styles.append(f'transform:translate({-anchor[0]*100}%,{-anchor[1]*100}%) rotate({val(p,"Rotation",0)}deg) scale({scale})')
 if p.ClipsDescendants or cl=='ScrollingFrame':styles.append('overflow:hidden')
 styles.append('z-index:'+str(val(p,'ZIndex',1)))
 for c in children:
  if c.ClassName=='UICorner':styles.append('border-radius:'+str(val(c.CornerRadius,'offset',0))+'px')
  if c.ClassName=='UIStroke':styles.append(f'outline:{val(c,"Thickness",1)}px solid {rgb(c.Color)}')
 if cl=='ImageLabel':
  r=p.ImageRectOffset;size=p.ImageRectSize
  if r is not None:
   styles+=['background-image:var(--atlas)','background-repeat:no-repeat',f'background-size:{1024/size.X*100}% {1024/size.Y*100}%',f'background-position:{r.X/(1024-size.X)*100 if size.X<1024 else 0}% {r.Y/(1024-size.Y)*100 if size.Y<1024 else 0}%']
 content=''
 if cl in ['TextLabel','TextButton','TextBox']:
  align=val(p,'TextXAlignment','Center');vertical=val(p,'TextYAlignment','Center')
  styles+=['display:flex','align-items:'+('flex-start' if vertical=='Top' else 'center'),'justify-content:'+('flex-start' if align=='Left' else 'flex-end' if align=='Right' else 'center'),'text-align:'+('left' if align=='Left' else 'right' if align=='Right' else 'center'),'white-space:pre-wrap','line-height:1.15',f'font-size:{val(p,"TextSize",14)}px','font-weight:'+('800' if 'Bold' in str(val(p,'Font','')) else '500'),'color:'+rgb(p.TextColor3)]
  if p.Text:content='<span>'+html.escape(str(p.Text))+'</span>'
  elif cl=='TextBox' and p.PlaceholderText:content='<span style="opacity:.55">'+html.escape(str(p.PlaceholderText))+'</span>'
 child_html=''.join(render(c) for c in children)
 if cl=='ScrollingFrame':
  offset=val(p.CanvasPosition,'Y',0);child_html=f'<div style="position:absolute;inset:0;transform:translateY(-{offset}px)">'+child_html+'</div>'
 content+=child_html
 return '<div data-name="'+html.escape(str(p.Name))+'" style="'+';'.join(styles)+'">'+content+'</div>'

def make(mode):
 mobile=mode.startswith('mobile-');scene=mode.replace('mobile-','')
 width,height=(844,390) if mobile else (1440,810)
 lua,t,p=host(unpublished=True);client(t,p,mobile)
 game=t.session(p).game
 if scene in ['gameplay','mining','supply','planner','result','pause']:
  t.click(p,'3 波教学 · 推荐')
  if scene=='gameplay':
   t.action(p,'buy','damage');game.wave=2;game.ore=190
   for i in range(150):
    t.step(.1);t.render(.1)
  elif scene=='result':
   t.action(p,'buy','damage')
   for i in range(4000):
    if game.phase=='ended':break
    if game.supply:t.action(p,'supply',lua.table_from({'token':game.supply.token,'id':game.supply.options[1]}))
    if i%10==0 and game.ore>=100 and not game.upgrades.drill:t.action(p,'buy','drill')
    t.step(.1)
   assert game.phase=='ended'
   t.action(p,'ready')
  else:
   game.wave=1;game.waveElapsed=28;game.enemies=lua.table();game.projectiles=lua.table();t.step(.2)
   if scene!='supply':
    t.action(p,'supply',lua.table_from({'token':game.supply.token,'id':game.supply.options[1]}))
    for i in range(300 if scene=='result' else 86):
     t.step(.1)
     for _ in range(6):t.render(1/60)
    if scene=='planner':t.click(p,'情报 / 经营台')
    if scene=='pause':t.click(p,'Ⅱ')
 elif scene=='research':
  game.profile.alloy=480;game.profile.research=85;game.profile.bestWave=5;game.profile.targetResearch='energy_2'
  for id in ['fort_1','industry_1','ballistics_1']:game.profile.tech[id]=True
  t.action(p,'ready');t.click(p,'研究中心')
 elif scene=='settings':t.click(p,'设置')
 elif scene=='codex':t.click(p,'远征图鉴')
 t.render(.2)
 err=p.PlayerGui.GetAttribute(p.PlayerGui,'FrontierClientError');assert not err,err
 content=''.join(render(g) for g in p.PlayerGui.GetChildren(p.PlayerGui).values())
 atlas=base64.b64encode((ROOT/'assets/dustbound-atlas.png').read_bytes()).decode()
 page='<!doctype html><html><head><meta charset="utf-8"><title>Offline GUI / NOT Roblox Studio</title><style>html,body{margin:0;width:'+str(width)+'px;height:'+str(height)+'px;overflow:hidden;font-family:Arial,"Noto Sans CJK SC",sans-serif}body{--atlas:url(data:image/png;base64,'+atlas+')}</style></head><body>'+content+'<div style="position:fixed;left:4px;top:2px;z-index:99999;font:10px Arial,sans-serif;color:#152d3c;background:#f7f1dbdd;padding:2px 5px">离线 UI 排版 / 非 Studio 实机 · '+mode+'</div></body></html>'
 folder=ROOT/'.cache/previews';folder.mkdir(parents=True,exist_ok=True)
 file=folder/f'offline-{mode}.html';file.write_text(page);return file,width,height
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--capture',action='store_true');args=parser.parse_args()
 modes=['menu','gameplay','research','result','mobile-menu','mobile-gameplay','mobile-mining','mobile-research','mobile-supply','mobile-planner','mobile-settings','mobile-result']
 files=[make(mode) for mode in modes]
 if args.capture:
  from playwright.sync_api import sync_playwright
  with sync_playwright() as p:
   browser=p.chromium.launch(headless=True,args=['--no-sandbox'])
   for f,w,h in files:
    page=browser.new_page(viewport={'width':w,'height':h},device_scale_factor=1)
    page.goto(f.as_uri());page.screenshot(path=str(ROOT/'docs'/f.with_suffix('.png').name));page.close()
   browser.close()
 print('Offline actual Lua GUI layouts rendered. NOT Studio captures.')
