"""Record actual Lua Motion/Client transforms through the offline GUI mock.
This is NOT Roblox engine footage. Used only to inspect animation timing/rig layout.
Optional deps: playwright, Pillow, imageio-ffmpeg + playwright install chromium.
"""
from pathlib import Path
import sys,base64,io
from PIL import Image
import imageio_ffmpeg
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'));sys.path.insert(0,str(ROOT/'tests'))
from preview_layout import render
from test_ui import host,client,healthy

def scenario(mining=False):
 lua,t,p=host(unpublished=True);client(t,p);t.click(p,'▶  开始标准远征');s=t.session(p).game
 if mining:
  s.wave=3;s.waveElapsed=28;s.enemies=lua.table();s.projectiles=lua.table();t.step(.2)
  t.action(p,'supply',lua.table_from({'token':s.supply.token,'id':s.supply.options[1]}))
 else:
  s.wave=5;s.elapsed=5;s.ore=800;s.upgrades.damage=1
  enemies=[]
  for i in range(7):
   kind=['crawler','runner','tank','spitter','elite','crawler','runner'][i]
   enemies.append(lua.table_from({'id':i+1,'kind':kind,'hp':180 if kind=='elite' else 80,'maxHp':180 if kind=='elite' else 80,'x':830+(i%4)*135,'y':408+(i%3)*25,'attack':0,'speed':35,'burn':0,'spawnAt':0,'attackAt':-100,'hitAt':-100}))
  s.enemies=lua.table_from(enemies);s.serial=7;s.spawnClock=-100;s.noticeLeft=0
  t.action(p,'ready')
 return lua,t,p,s

def main():
 atlas=base64.b64encode((ROOT/'assets/dustbound-atlas.png').read_bytes()).decode()
 fps=24;w,h=1152,648
 writer=imageio_ffmpeg.write_frames(str(ROOT/'docs/offline-motion.mp4'),(w,h),fps=fps,codec='libx264',quality=8,macro_block_size=2,output_params=['-movflags','+faststart'])
 writer.send(None)
 with sync_playwright() as pw:
  browser=pw.chromium.launch(headless=True,args=['--no-sandbox']);page=browser.new_page(viewport={'width':w,'height':h})
  page.set_content('<html><head><meta charset="utf-8"><style>html,body{margin:0;overflow:hidden;font-family:Arial,"Noto Sans CJK SC",sans-serif}#viewport{width:1440px;height:810px;position:absolute;transform:scale(.8);transform-origin:0 0;--atlas:url(data:image/png;base64,'+atlas+')}#caption{position:fixed;top:5px;left:7px;z-index:99999;color:#fff;background:#172131;padding:5px 10px;border-radius:4px;font-size:12px}</style></head><body><div id="viewport"></div><div id="caption"></div></body></html>')
  for mining,seconds in [(False,6),(True,8)]:
   lua,t,p,s=scenario(mining);acc=0
   for i in range(seconds*fps):
    acc+=1/fps
    if acc>=.1:acc-=.1;t.step(.1)
    t.render(1/fps);healthy(t,p)
    caption='0.5 离线示例状态 · 非 Studio 实录 | '+('机器人出库 / 钻探 / 返航 / 入账' if mining else '关节步态 / 炮塔后坐 / 飞行弹丸与命中')
    page.evaluate('([html,caption])=>{document.getElementById("viewport").innerHTML=html;document.getElementById("caption").textContent=caption}',[''.join(render(g) for g in p.PlayerGui.GetChildren(p.PlayerGui).values() if g.ClassName=='ScreenGui'),caption])
    image=Image.open(io.BytesIO(page.screenshot())).convert('RGB');writer.send(image.tobytes())
  browser.close()
 writer.close()
 print('Wrote docs/offline-motion.mp4: 14s, 24fps, actual Lua GUI transforms via mock, NOT Studio footage.')
if __name__=='__main__':main()
