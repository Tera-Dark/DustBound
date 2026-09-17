"""Self-contained tabbed preview of actual Lua GUI snapshots, not a playable game."""
from pathlib import Path
import base64,re,json
ROOT=Path(__file__).resolve().parents[1]
views=[('research','科技全图'),('research-zoom','科技近景'),('campaign','星球航图'),('codex','武器图鉴'),('codex-monsters','怪物图鉴'),('workshop','武器工坊')]
parts=[]
for i,(key,label) in enumerate(views):
 page=(ROOT/'.cache/previews'/f'offline-{key}.html').read_text()
 body=page.split('<body>',1)[1].split('</body>',1)[0]
 body=re.sub(r'<div style="position:fixed;left:4px;top:2px;z-index:99999.*?</div>','',body)
 parts.append('<section class="shot" id="v'+str(i)+'"'+(' hidden' if i else '')+'>'+body+'</section>')
atlas=base64.b64encode((ROOT/'assets/dustbound-atlas.png').read_bytes()).decode()
gallery=base64.b64encode((ROOT/'assets/expedition-gallery-runtime.png').read_bytes()).decode()
buttons=''.join('<button data-tab="'+str(i)+'" class="'+('active' if i==0 else '')+'">'+v[1]+'</button>' for i,v in enumerate(views))
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>DUSTBOUND 0.6.1 / 星球远征</title><style>
*{box-sizing:border-box}html,body{margin:0;background:#222537;color:#f7f1db;font-family:Arial,"Noto Sans CJK SC",sans-serif;height:100%;overflow:hidden}header{height:112px;padding:12px 20px;background:#f7f1db;color:#222537;border-bottom:3px solid #222537}h1{font-size:19px;margin:0 0 7px}p{font-size:12px;margin:0 0 8px}nav{display:flex;gap:7px;overflow-x:auto}button{white-space:nowrap;background:#fff9e9;border:2px solid #222537;border-radius:8px;padding:7px 12px;cursor:pointer;color:#222537;font-weight:bold}button.active{background:#ea8c3d}#viewport{position:relative;width:100%;height:calc(100% - 112px)}#stage{position:absolute;width:1440px;height:810px;transform-origin:top left}.shot{position:absolute;inset:0;width:1440px;height:810px}.shot[hidden]{display:none}
body{--atlas:url(data:image/png;base64,'''+atlas+''');--gallery:url(data:image/png;base64,'''+gallery+''')}</style><header><h1>DUSTBOUND 0.6.1 · 星球远征 / 科技树 / 插画图鉴</h1><p>真实 Lua GUI 的离线布局转换，可切换页签；不是可玩游戏或 Studio 实机画面。游戏内支持科技树拖动与缩放。</p><nav>'''+buttons+'''</nav></header><main id="viewport"><div id="stage">'''+''.join(parts)+'''</div></main><script>
const stage=document.getElementById('stage'),vp=document.getElementById('viewport');
function fit(){const s=Math.min(vp.clientWidth/1440,vp.clientHeight/810);stage.style.transform='scale('+s+')';stage.style.left=(vp.clientWidth-1440*s)/2+'px';stage.style.top='0px'}
for(const b of document.querySelectorAll('button[data-tab]'))b.onclick=()=>{for(const v of document.querySelectorAll('.shot'))v.hidden=v.id!=='v'+b.dataset.tab;for(const t of document.querySelectorAll('button[data-tab]'))t.classList.toggle('active',t===b)};
window.addEventListener('resize',fit);fit();
</script></html>'''
output=ROOT.parent/'DustBound-0.6.1-preview.html';output.write_text(page);print(output,output.stat().st_size)
