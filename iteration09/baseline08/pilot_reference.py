"""Deterministic, ordinary-stat campaign pilot. No resource injection or invincibility."""
from pathlib import Path
import json
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
def setup():
 l=LuaRuntime(unpack_returned_tuples=True)
 c=l.execute((ROOT/'src/Config.lua').read_text());r=l.execute((ROOT/'src/Rules.lua').read_text());g=l.execute((ROOT/'src/Core.lua').read_text())
 c.Tech=l.execute((ROOT/'src/Tech.lua').read_text());c.Catalog=l.execute((ROOT/'src/Catalog.lua').read_text())
 
 for name in ['RunSystems','ResearchWeb','Economy']:c[name]=l.execute((ROOT/('src/'+name+'.lua')).read_text())
 return l,c,r,g,g.new(c,r,r.cleanProfile(None))
def play(l,c,r,g,s,node):
 assert g.start(s,c,r,l.table_from({'node':node}))
 for tick in range(18000):
  if s.phase=='ended':break
  if s.supply:
   opts=list(s.supply.options.values());want=next((x for x in (['repairNet','reactor','battery','cargoRack','diamondBit','plating'] if s.supply.kind=='relic' else ['arc','mortar','rail','machine','flame']) if x in opts),opts[0])
   if want not in opts:want=opts[0]
   g.act(s,c,r,'supply',l.table_from({'token':s.supply.token,'id':want}))
  if tick%10==0:
   level=lambda n:s.upgrades[n] or 0
   if s.hull/s.maxHull<.55 and r.price('repair',level('repair'),c) and s.ore>=r.price('repair',level('repair'),c):g.act(s,c,r,'buy','repair')
   priorities=[]
   for name,cap in [('cargo',1),('dig',1),('damage',3),('rate',2),('barrel',1),('robots',1),('armor',2)]:
    if level(name)<cap:priorities.append(name)
   priorities+=['damage','rate','barrel','regen','armor']
   for name in priorities:
    price=r.price(name,level(name),c)
    if price and s.ore>=price:g.act(s,c,r,'buy',name);break
  g.step(s,c,r,.1);s.events=l.table()
 assert s.result,'Campaign stalled'
 return {'node':node,'won':bool(s.result.won),'wave':s.wave,'seconds':round(s.elapsed,1),'hull':round(s.hull),'kills':s.kills,'alloy':s.result.alloy,'research':s.result.research,'crystals':s.result.crystals,'cores':s.result.cores}
def research(c,r,g,s):
 bought=[]
 for tier in range(1,9):
  for b in ['ballistics','industry','fort','energy','logistics','expedition']:
   id=f'{b}_{tier}'
   if r.techState(s.profile,id,c)[0]=='ready':
    if g.act(s,c,r,'research',id):bought.append(id)

 return bought
def run():
 l,c,r,g,s=setup();rows=[]
 for node in range(1,25):
  bought=research(c,r,g,s);row=play(l,c,r,g,s,node);row['researchBefore']=bought;rows.append(row)
  if not row['won']:break
 return rows
if __name__=='__main__':
 rows=run();print(json.dumps(rows,ensure_ascii=False,indent=2))
 assert len(rows)==24 and all(x['won'] for x in rows)
