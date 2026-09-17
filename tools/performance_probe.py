"""Deterministic mock operation counts. NOT FPS, CPU benchmarks or GPU measurements."""
from pathlib import Path
import sys,json,argparse
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tests'))
from test_ui import host,client,visit,to_mining,healthy

def measure(scenario,source_root=ROOT):
 l,t,p=host(sourceRoot=source_root);t.enableClient(p,(Path(source_root)/"src/Client.client.lua").read_text(),False)
 if scenario!='idle':
  visit(t,p,'▶  开始标准远征')
  if scenario=='planner':
   s=to_mining(l,t,p)
   t.action(p,'supply',l.table_from({'token':s.supply.token,'id':'drill'}))
   t.render(.2);visit(t,p,'情报 / 经营台')
  elif scenario=='pause':visit(t,p,'Ⅱ')
 keys=['instances','destroyed','assignments']
 before={k:t.counters[k] for k in keys}
 for i in range(600):
  if i%6==0:t.step(.1)
  t.render(1/60)
 healthy(t,p)
 return {k:t.counters[k]-before[k] for k in keys}
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--output');parser.add_argument('--source-root',default=str(ROOT));args=parser.parse_args()
 data={'description':'600 mock frames + 10 simulated seconds. Operation counts only, NOT hardware performance.', 'scenarios':{s:measure(s,Path(args.source_root)) for s in ['idle','planner','pause','combat']}}
 text=json.dumps(data,ensure_ascii=False,indent=2)
 print(text)
 if args.output:Path(args.output).write_text(text+'\n')
