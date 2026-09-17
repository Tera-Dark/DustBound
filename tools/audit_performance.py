"""Operation counts from actual Lua under a mock. Not Roblox engine timings."""
import sys,json,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tests'))
from test_ui import host,healthy
import zipfile
with zipfile.ZipFile(ROOT/'docs/audit-0.7/baseline-sources.zip') as z:z.extractall(ROOT/'.cache/audit-before')
rows=[]
for version,root in [('before',ROOT/'.cache/audit-before'),('after',ROOT)]:
 for fallback in [False,True]:
  begin=time.perf_counter();l,t,p=host(sourceRoot=root,imageDisabled=fallback)
  t.enableClient(p,(root/'src/Client.client.lua').read_text(),False)
  load=(time.perf_counter()-begin)*1000
  before={k:t.counters[k] for k in ['instances','assignments','destroyed','yields','pixelWrites']}
  for _ in range(180):t.render(1/60)
  idle=t.counters.assignments-before['assignments']
  t.click(p,'出发 · 第 1 关');t.click(p,'采矿投资');s=t.session(p).game
  n=t.counters.instances;d=t.counters.destroyed
  for _ in range(20):s.run.gold+=100;t.action(p,'ready');t.render(.1)
  healthy(t,p)
  rows.append(dict(version=version,fallback=fallback,hostAndClientWallMs=round(load,2),bootCounters=before,idle180FrameAssignments=idle,gold20UpdatesNewInstances=t.counters.instances-n,gold20UpdatesDestroyed=t.counters.destroyed-d))
(ROOT/'docs/audit-0.7/performance.json').write_text(json.dumps(rows,indent=2));print(json.dumps(rows,indent=2))
