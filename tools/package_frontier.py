"""Build the complete 0.8 review delivery archive with a SHA-256 manifest."""
from pathlib import Path
import json,hashlib,zipfile,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT.parent/'DustBound-0.8.0-FRONTIER.zip'
EXCLUDED={'.git','.cache','.pytest_cache','__pycache__','.venv','node_modules'}
files=sorted(p for p in ROOT.rglob('*') if p.is_file() and not any(x in EXCLUDED for x in p.relative_to(ROOT).parts) and p.name!='PACKAGE_MANIFEST.json')
scripts=[e for e in ET.parse(ROOT/'Dustbound-0.8.0-FRONTIER.rbxlx').iter() if e.get('name')=='Source']
manifest={'package':'DustBound-0.8.0-FRONTIER','date':'2026-09-17','basedOnCommit':'c9d1199ef922146db429a70907492a6b1fdc40f9','status':'runnable visual/logic upgrade; not production accepted','entryPlace':'Dustbound-0.8.0-FRONTIER.rbxlx','readme':'README.md','upgradeReport':'docs/UPGRADE_0.8.md','embeddedScriptCount':len(scripts),'focusedTests':'84 passed','historicalSuite':'195 passed / 129 failed; unchanged failed-test ID set versus baseline','excluded':sorted(EXCLUDED),'files':[{'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]}
manifest['archiveFileCount']=len(files)+1
mp=ROOT/'PACKAGE_MANIFEST.json';mp.write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')
with zipfile.ZipFile(OUTPUT,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in files+[mp]:z.write(p,'DustBound/'+p.relative_to(ROOT).as_posix())
with zipfile.ZipFile(OUTPUT) as z:assert z.testzip() is None
print(OUTPUT,OUTPUT.stat().st_size,'bytes;',len(files)+1,'files;',len(scripts),'embedded scripts')
