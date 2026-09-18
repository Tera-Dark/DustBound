from pathlib import Path
import json,hashlib,zipfile,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1];place='Dustbound-0.9.0-FIRST-CONTACT.rbxlx'
sources=[e.text or '' for e in ET.parse(ROOT/place).iter() if e.get('name')=='Source']
project=json.loads((ROOT/'default.project.json').read_text())
for v in project['tree']['ReplicatedStorage']['FrontierShared'].values():
 if isinstance(v,dict) and '$path' in v:assert (ROOT/v['$path']).read_text() in sources,v
for name in ['Server.server.lua','Client.client.lua','Boot.client.lua']:assert (ROOT/'src'/name).read_text() in sources
excluded={'.git','.cache','.pytest_cache','__pycache__','.venv','node_modules'}
files=[]
for p in ROOT.rglob('*'):
 if not p.is_file() or any(v in excluded for v in p.relative_to(ROOT).parts):continue
 if p.suffix=='.rbxlx' and p.name!=place:continue
 if p.name in ['PACKAGE_MANIFEST.json','PACKAGE_MANIFEST_09.json','luau-compile.txt','browser-install.txt']:continue
 if p.relative_to(ROOT).parts[0]=='docs' and p.name!='UPGRADE_0.9.md':continue
 if p.relative_to(ROOT).parts[0]=='review':continue # Original delivered audit remains separate and unchanged.
 files.append(p)
manifest={'version':'0.9.0 FIRST CONTACT','date':'2026-09-17','entryPlace':place,'scriptCount':len(sources),'status':'development playtest; not production approved','focusedTests':'109 passed','fullTests':'221 passed / 128 failed; no new failed IDs against original 0.8 audit after documented fixture migration','excluded':'git/caches, older Place files, historical docs (retained in 0.8 archive), original review directory, large compiler disassembly and install logs','files':[{'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(files)]}
mp=ROOT/'PACKAGE_MANIFEST_09.json';mp.write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
output=ROOT.parent/'DustBound-0.9.0-FIRST-CONTACT.zip'
with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in files+[mp]:z.write(p,'DustBound/'+p.relative_to(ROOT).as_posix())
with zipfile.ZipFile(output) as z:assert z.testzip() is None
print(output,output.stat().st_size,'bytes',len(files)+1,'files',len(sources),'embedded scripts')
