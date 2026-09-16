from pathlib import Path
import urllib.request,json,hashlib
ROOT=Path(__file__).resolve().parents[1]
url='https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json'
raw=urllib.request.urlopen(url,timeout=30).read();api=json.loads(raw)
path=ROOT/'tests/roblox_api_contract.json';old=json.loads(path.read_text())
classes={c['Name']:c for c in api['Classes']}
def props(name):
 c=classes[name];p=props(c['Superclass']) if c['Superclass'] in classes else {}
 for m in c['Members']:
  if m['MemberType']=='Property':p[m['Name']]=m['ValueType']
 return p
names=list(old['properties'])+['ImageLabel','ScrollingFrame','AssetService','Sound','SoundService','AnalyticsService','GuiService']
obj={'source':url,'sourceSHA256':hashlib.sha256(raw).hexdigest(),'note':'Reflection contract only. Not a Studio validation. Retrieved 2026-09-16.','properties':{n:props(n) for n in names},'enums':{e['Name']:{i['Name']:True for i in e['Items']} for e in api['Enums']}}
path.write_text(json.dumps(obj,ensure_ascii=False,separators=(',',':')))
