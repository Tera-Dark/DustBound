from pathlib import Path
import csv,sys
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
l=LuaRuntime(unpack_returned_tuples=True);catalog=l.execute((ROOT/'src/Catalog.lua').read_text());rules=l.execute((ROOT/'src/Rules.lua').read_text())
with (ROOT/'docs/campaign-balance.csv').open('w',newline='') as f:
 w=csv.writer(f);w.writerow(['id','planet','node','waves','hpMultiplier','attackMultiplier','spawnDensity','extraStartOre','firstAlloy','repeatAlloy','firstData','repeatData','firstCrystals','repeatCrystals','victoryCores'])
 for i in range(1,25):
  n=catalog.campaign[i];a=rules.campaignReward(n,True,True,0,1,l.table());b=rules.campaignReward(n,True,False,0,1,l.table())
  w.writerow([i,n.planet,n.node,n.waves,round(n.hp,3),round(n.attack,3),round(n.density,3),n.startOre,a.alloy,b.alloy,a.research,b.research,a.crystals,b.crystals,a.cores])
