"""Fresh profiles, real Lua step/action loop, unchanged save schema; not human play."""
import argparse,json,time
from pathlib import Path
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
def setup(version):
 src=ROOT/'src' if version=='09' else ROOT/'iteration09/baseline08'
 l=LuaRuntime(unpack_returned_tuples=True);c=l.execute((src/'Config.lua').read_text());c.Tech=l.execute((src/'Tech.lua').read_text());c.Catalog=l.execute((src/'Catalog.lua').read_text())
 for name in ['RunSystems','ResearchWeb','Economy']+(['Encounters'] if version=='09' else []):c[name]=l.execute((src/(name+'.lua')).read_text());getattr(c[name],'configure',None) and c[name].configure(c)
 r=l.execute((src/'Rules.lua').read_text());g=l.execute((src/'Core.lua').read_text());return l,c,r,g,g.new(c,r)
import sys
sys.path.insert(0,str(ROOT/'tests'))
from campaign_pilot import research
from lupa import lua_type
def convert(x):
 if lua_type(x)!='table':return x
 keys=list(x.keys())
 if keys and set(keys)==set(range(1,len(keys)+1)):return [convert(x[i]) for i in range(1,len(keys)+1)]
 return {str(k):convert(v) for k,v in x.items()}
def simulate(version,mode,recall=False,seed=0):
 l,c,r,g,s=setup(version);s.profile.runSerial=seed;rows=[];global_time=0;first_aux=None
 for node in range(1,25):
  before=research(c,r,g,s) if mode=='balanced' else []
  assert g.start(s,c,r,l.table_from({'node':node}))
  seen={};max_alive=0;offers=[];first_hit=None;buylog=[];weapon_damage={};collected=set()
  prepWave=0;prepMined=0
  for tick in range(24000):
   if s.phase=='ended':break
   if s.supply:
    opts=list(s.supply.options.values())
    priorities=(['repairNet','reactor','battery','cargoRack','diamondBit','plating'] if s.supply.kind=='relic' else ['arc','mortar','rail','machine','flame']) if mode=='balanced' else opts
    pick=next((id for id in priorities if id in opts),opts[0])
    offers.append({'wave':s.wave,'kind':s.supply.kind,'options':opts,'choice':pick,'at':round(s.elapsed,1)})
    if s.supply.kind=='weapon' and first_aux is None:first_aux={'node':node,'wave':s.wave,'totalSeconds':round(global_time+s.elapsed,1)}
    assert g.act(s,c,r,'supply',l.table_from({'token':s.supply.token,'id':pick}))
   if tick%10==0 and mode!='no_invest':
    level=lambda id:s.upgrades[id] or 0
    prefs=[]
    if mode=='balanced':
     if s.hull/s.maxHull<.55:prefs.append('repair')
     prefs += [id for id,cap in [('cargo',1),('dig',1),('damage',3),('rate',2),('barrel',1),('robots',1),('armor',2)] if level(id)<cap]
     prefs += ['damage','rate','barrel','regen','armor']
    elif mode=='combat_only':prefs=['damage','rate','barrel','armor','regen']
    elif mode=='mining_only':prefs=['cargo','dig','move','robots']
    for id in prefs:
     price=g.prices(s,c,r)[id]
     if price and s.ore>=price and g.act(s,c,r,'buy',id):buylog.append({'id':id,'at':round(s.elapsed,1),'price':price});break
   if recall and s.stage=='mining' and not s.supply and not s.run.recalling:
    if prepWave!=s.wave:prepWave=s.wave;prepMined=s.totalMined
    if s.totalMined>prepMined:assert g.act(s,c,r,'recall',l.table_from({'token':s.run.prepareToken}))
   g.step(s,c,r,.1)
   for e in s.enemies.values():seen[e.id]=e.kind
   max_alive=max(max_alive,len(s.enemies))
   if first_hit is None and s.waveStats.taken>0:first_hit={'wave':s.wave,'at':round(s.elapsed,1)}
   if s.stage=='mining' or s.phase=='ended':
    if s.wave not in collected:
     for k,v in s.waveStats.weapons.items():weapon_damage[k]=weapon_damage.get(k,0)+v
     collected.add(s.wave)
   s.events=l.table()
  assert s.result,'stalled'
  # First deposits are elapsed metrics, not inferred from visual cargo.
  dep=next((m.value for m in s.metrics.values() if m.name=='first_robot_deposit'),None)
  taken=sum(x.taken for x in s.reports.values())+(0 if s.result.won else s.waveStats.taken)
  row={'node':node,'won':bool(s.result.won),'waves':s.mission.waves,'reachedWave':s.wave,'seconds':round(s.elapsed,1),'timing':convert(s.timing),'damageTaken':round(taken,2),'endHull':round(s.hull,2),'maxHull':s.maxHull,'peakEnemies':max_alive,'spawnKinds':sorted(set(seen.values())),'spawnCount':len(seen),'firstHit':first_hit,'firstDeposit':dep,'mined':s.totalMined,'unspentGold':s.ore,'upgrades':convert(s.upgrades),'purchases':buylog,'offers':offers,'weapons':convert(s.run.weapons),'weaponDamage':weapon_damage,'researchBefore':before,'reward':{k:s.result[k] for k in ['alloy','research','cores']}}
  rows.append(row);global_time+=s.elapsed
  if not s.result.won:break
  assert g.act(s,c,r,'menu')
 return {'version':version,'recall':recall,'seed':seed,'mode':mode,'rows':rows,'wins':sum(x['won'] for x in rows),'simulatedSeconds':round(global_time,1),'firstAuxiliary':first_aux,'profileAfter':convert(s.profile)}

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--quick',action='store_true');args=p.parse_args();rows=[];start=time.monotonic()
 cases=[(v,p,False,0) for v in ['08','09'] for p in ['balanced','combat_only','no_invest']]+[('09','balanced',True,0)]
 if not args.quick:cases += [('09',policy,False,seed) for seed in [7,29] for policy in ['balanced','combat_only','no_invest']]
 for case in cases:
  row=simulate(*case);rows.append(row);print(case,'wins',row['wins'],'damage',round(sum(x['damageTaken'] for x in row['rows'])), 'minutes',round(row['simulatedSeconds']/60,1),'firstAux',row['firstAuxiliary'],'lastHull',row['rows'][-1]['endHull'],flush=True)
 (ROOT/'iteration09/results/balance.json').write_text(json.dumps({'runtimeSeconds':time.monotonic()-start,'method':'Real Lua Core, dt=.1, fresh profiles, same original review policies. Seed varies only runSerial. Recall after first deposit. Accelerated, not human play or Studio.','runs':rows},ensure_ascii=False,indent=2))
