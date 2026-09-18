"""Browser review host for the actual engine-independent Lua Core.
Not a Roblox emulator: uses Lupa for rules; Canvas/HTML for presentation.
In-memory per-browser sessions, no cloud saves, and no demo resource injection.
Run: python preview/server.py --port 8080
"""
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from http.cookies import SimpleCookie
from urllib.parse import urlparse
import argparse, json, threading, time, secrets, sys
from lupa import LuaRuntime, lua_type
ROOT = Path(__file__).resolve().parents[1]

def plain(x):
    if lua_type(x) != 'table': return x
    keys = list(x.keys())
    if keys and all(isinstance(k, (int, float)) and k >= 1 and int(k) == k for k in keys) and set(keys) == set(range(1,len(keys)+1)):
        return [plain(x[i]) for i in range(1,len(keys)+1)]
    return {str(k):plain(v) for k,v in x.items()}

class Session:
    def __init__(self):
        self.lock=threading.RLock(); self.lua=LuaRuntime(unpack_returned_tuples=True)
        load=lambda n:self.lua.execute((ROOT/'src'/f'{n}.lua').read_text())
        self.c=load('Config');self.r=load('Rules');self.g=load('Core')
        for n in ['Tech','Catalog','RunSystems','ResearchWeb','Economy','Encounters']:self.c[n]=load(n)
        self.s=self.g.new(self.c,self.r,self.r.cleanProfile(None));self.last=time.monotonic();self.seen=self.last
    def tick(self):
        now=time.monotonic();left=min(now-self.last,2);self.last=now;self.seen=now
        while left>0.00001:
            dt=min(.1,left);self.g.step(self.s,self.c,self.r,dt);left-=dt
    def snapshot(self):
        s=plain(self.g.snapshot(self.s,self.c,self.r))
        s['events']=plain(self.s.events);self.s.events=self.lua.table()
        s['saveStatus']='浏览器评审 · 内存会话，不写入 Roblox 云档'
        s['techStates']={k:plain(self.r.techState(self.s.profile,k,self.c)[0]) for k in self.c.Tech.order.values()}
        return s
    def bootstrap(self):
        return {'catalog':plain(self.c.Catalog),'tech':plain(self.c.Tech),'relics':plain(self.c.RunSystems.relics),'upgrades':plain(self.c.Upgrades),'mounts':plain(self.c.WeaponMounts),'version':'0.9.0 FIRST CONTACT','state':self.snapshot()}

sessions={};session_lock=threading.Lock()
class Handler(SimpleHTTPRequestHandler):
    def __init__(self,*a,**kw):super().__init__(*a,directory=str(ROOT),**kw)
    def session(self):
        cookie=SimpleCookie();cookie.load(self.headers.get('Cookie',''))
        token=cookie.get('dustbound');key=token.value if token else None
        with session_lock:
            now=time.monotonic()
            for stale in [k for k,v in sessions.items() if now-v.seen>3600]:sessions.pop(stale,None)
            if key not in sessions:
                if len(sessions)>=64:raise RuntimeError('预览会话已满，请稍后重试')
                key=secrets.token_urlsafe(24);sessions[key]=Session()
            self.session_key=key;return sessions[key]
    def json(self,obj,status=200):
        data=json.dumps(obj,ensure_ascii=False,allow_nan=False).encode()
        self.send_response(status);self.send_header('Content-Type','application/json; charset=utf-8');self.send_header('Cache-Control','no-store')
        if hasattr(self,'session_key'):self.send_header('Set-Cookie',f'dustbound={self.session_key}; HttpOnly; SameSite=Lax; Path=/')
        self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
    def do_GET(self):
        path=urlparse(self.path).path
        if path in ['/api/state','/api/bootstrap']:
            try:
                session=self.session()
                with session.lock:
                    session.tick();self.json(session.bootstrap() if path.endswith('bootstrap') else session.snapshot())
            except Exception as e:self.json({'error':str(e)},500)
            return
        if path in ['/','/preview','/preview/']:self.path='/preview/index.html'
        # Do not expose source control, test data or arbitrary workspace files.
        elif not path.startswith(('/assets/','/preview/')):self.send_error(404);return
        if '..' in path or path.endswith('.py'):self.send_error(404);return
        return super().do_GET()
    def do_POST(self):
        if self.path!='/api/action':self.send_error(404);return
        origin=self.headers.get('Origin')
        if origin and urlparse(origin).netloc!=self.headers.get('Host'):self.json({'error':'Origin rejected'},403);return
        try:
            size=int(self.headers.get('Content-Length','0'))
            if size<=0 or size>8192:raise ValueError('Invalid request size')
            payload=json.loads(self.rfile.read(size));kind=payload.get('kind')
            if kind not in ['start','pause','abandon','menu','settings','settings_reset','buy','research','refund_talent','supply','reroll','recall','target_mode']:raise ValueError('Unknown action')
            data=payload.get('data');session=self.session()
            with session.lock:
                session.tick()
                if isinstance(data,(dict,list)):data=session.lua.table_from(data,recursive=True)
                result=session.g.act(session.s,session.c,session.r,kind,data)
                ok=result[0] if isinstance(result,tuple) else result
                self.json({'ok':bool(ok),'state':session.snapshot()})
        except (ValueError,TypeError,KeyError) as e:self.json({'error':str(e)},400)
        except Exception as e:self.json({'error':str(e)},500)
    def log_message(self,fmt,*args):
        if 'api/state' not in str(args):super().log_message(fmt,*args)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--port',type=int,default=8080);args=p.parse_args()
    print(f'DUSTBOUND review host: http://0.0.0.0:{args.port}',flush=True)
    ThreadingHTTPServer(('0.0.0.0',args.port),Handler).serve_forever()
