from pathlib import Path
import json,argparse,subprocess,shutil
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--rojo',default=shutil.which('rojo'));p.add_argument('--output',default='Dustbound-0.7.0.rbxlx');args=p.parse_args()
shared={'$className':'Folder'}
for name in ['Runtime','Config','RunSystems','ResearchWeb','Economy','BattleView','Rules','Core','Art','ArtData','Tech','Catalog','Animation','WeaponRig','UI','Guide','Audio']: shared[name]={'$path':'src/'+name+'.lua'}
network={'$className':'Folder'}
for name in ['Action','State','FX']:network[name]={'$className':'RemoteEvent'}
for name,value in [('BootStatus','WAITING_FOR_SERVER'),('BootError','')]:network[name]={'$className':'StringValue','$properties':{'Value':value}}
project={'name':'Dustbound-0.7.0','tree':{
 '$className':'DataModel',
 'Workspace':{'$className':'Workspace','$properties':{'StreamingEnabled':False}},
 'Players':{'$className':'Players','$properties':{'CharacterAutoLoads':False}},
 'ReplicatedFirst':{'$className':'ReplicatedFirst','FrontierBoot':{'$path':'src/Boot.client.lua'}},
 'ReplicatedStorage':{'$className':'ReplicatedStorage','FrontierShared':shared,'FrontierNetwork':network},
 'ServerScriptService':{'$className':'ServerScriptService','FrontierServer':{'$path':'src/Server.server.lua','ProfileStore':{'$path':'src/ProfileStore.lua'},'Telemetry':{'$path':'src/Telemetry.lua'}}},
 'StarterPlayer':{'$className':'StarterPlayer','StarterPlayerScripts':{'$className':'StarterPlayerScripts','FrontierClient':{'$path':'src/Client.client.lua'}}}
}}
(ROOT/'default.project.json').write_text(json.dumps(project,indent=2)+'\n')
if not args.rojo: raise SystemExit('Project mapping written. Install Rojo and run: rojo build -o Dustbound-0.7.0.rbxlx')
subprocess.run([args.rojo,'build','default.project.json','-o',args.output],cwd=ROOT,check=True)
