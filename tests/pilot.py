from pathlib import Path
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
def pilot(loadout,overtime=False,mode="standard"):
 l=LuaRuntime(unpack_returned_tuples=True)
 c=l.execute((ROOT/'src/Config.lua').read_text());r=l.execute((ROOT/'src/Rules.lua').read_text());g=l.execute((ROOT/'src/Core.lua').read_text());c.Tech=l.execute((ROOT/'src/Tech.lua').read_text());c.Catalog=l.execute((ROOT/'src/Catalog.lua').read_text());s=g.new(c,r,r.cleanProfile(None))
 assert g.act(s,c,r,'loadout',loadout);g.start(s,c,r,mode)
 for tick in range(15000):
  if s.phase=='ended':break
  if s.phase=='decision':g.act(s,c,r,'decision','continue' if overtime else 'leave');continue
  if s.supply:
   options=list(s.supply.options.values());want='repair' if s.hull/s.maxHull<.65 else 'drill' if s.wave<6 else 'ammo'
   if want not in options:want=options[0]
   g.act(s,c,r,'supply',l.table_from({'token':s.supply.token,'id':want}))
  if tick%10==0:
   levels=lambda name:s.upgrades[name] or 0
   if s.hull/s.maxHull<.4 and s.ore>=r.price('repair',levels('repair'),c):g.act(s,c,r,'buy','repair')
   priorities=[]
   if levels('drill')<2:priorities.append('drill')
   if levels('damage')<3:priorities.append('damage')
   if levels('rate')<2:priorities.append('rate')
   if levels('barrel')<1:priorities.append('barrel')
   if levels('armor')<2:priorities.append('armor')
   priorities+=['damage','rate','barrel','regen','refinery']
   for name in priorities:
    price=r.price(name,levels(name),c)
    if price and s.ore>=price:g.act(s,c,r,'buy',name);break
  g.step(s,c,r,.1);s.events=l.table()
 print(mode,loadout,'overtime',overtime,'phase',s.phase,'seconds',round(s.elapsed,1),'wave',s.wave,'hull',round(s.hull,1),'kills',s.kills,'purchases',s.purchases)
 if s.result:print('  won',s.result.won,'alloy',s.result.alloy,'research',s.result.research)
 assert s.result and s.result.won,'Numerical pilot did not complete; inspect balance and phase progression'
if __name__=='__main__':
 print('NORMAL-STAT NUMERICAL PILOT. Not Roblox Studio or human playtesting.')
 pilot('machine',mode='tutorial');pilot('machine');pilot('machine',True)
