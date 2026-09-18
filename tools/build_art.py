from PIL import Image
from pathlib import Path
import itertools,json
ROOT=Path(__file__).resolve().parents[1]
source=Image.open(ROOT/'assets/source-sprites.png').convert('RGBA')
background=Image.open(ROOT/'assets/source-landscape-v08.png').convert('RGBA')
crops={'base':(25,83,740,550),'turret':(782,60,1070,241),'crawler':(1113,66,1345,242),'tank':(798,271,1065,508),'capsule':(1136,278,1332,494),'crystal':(1120,538,1345,747)}
images={'background':background}
for key,bounds in crops.items():
 im=source.crop(bounds)
 pixels=[]
 for r,g,b,a in im.getdata():
  # Flat magenta key; low-alpha edge fringe is removed, not retained as purple glow.
  if r>155 and b>145 and g<115 and min(r,b)-g>90: a=0
  pixels.append((r,g,b,a))
 im.putdata(pixels); box=im.getbbox(); im=im.crop(box)
 im.save(ROOT/'assets'/f'{key}.png');images[key]=im
motion=Image.open(ROOT/'assets/source-motion.png').convert('RGBA')
mw,mh=motion.size
for key,b in {'crawlerBody':(83,83,323,291),'tankBody':(730,29,1040,332),'robot':(350,406,664,752),'drillBit':(782,429,1276,721)}.items():
 im=motion.crop(b)
 pixels=[]
 for r,g,b,a in im.getdata():
  if r>155 and b>145 and g<115 and min(r,b)-g>90:a=0
  pixels.append((r,g,b,a))
 im.putdata(pixels);im=im.crop(im.getbbox());im.save(ROOT/'assets'/f'{key}.png');images[key]=im
images['runnerBody']=Image.open(ROOT/'assets/runnerBody.png').convert('RGBA')
images['flyerBody']=Image.open(ROOT/'assets/flyerBody.png').convert('RGBA')
images['flyerWing']=Image.open(ROOT/'assets/flyerWing.png').convert('RGBA')
atlas=Image.new('RGBA',(1024,1024),(0,0,0,0))
slots={'background':(0,0,1024,480),'base':(2,484,456,300),'turret':(465,484,205,130),'crawler':(676,484,142,110),'tank':(826,484,170,157),'capsule':(469,622,80,140),'crystal':(555,625,99,140),'crawlerBody':(672,654,143,114),'tankBody':(827,654,180,128),'robot':(4,800,190,165),'drillBit':(207,807,169,130),'flyerBody':(390,800,160,140),'flyerWing':(568,800,150,104),'runnerBody':(740,810,200,100)}
rects={}
for key,(x,y,w,h) in slots.items():
 im=images[key].copy(); im.thumbnail((w,h),Image.Resampling.LANCZOS)
 atlas.paste(im,(x,y),im);rects[key]={'x':x,'y':y,'w':im.width,'h':im.height}
atlas.save(ROOT/'assets/dustbound-atlas.png')
# Palette + hexadecimal RLE, decoded into one shared EditableImage, no uploaded asset required in supported environments.
quant=atlas.quantize(colors=128,method=Image.Quantize.FASTOCTREE)
palette=quant.getpalette('RGBA');values=list(quant.getdata())
colors=['%02x%02x%02x%02x'%tuple(palette[i*4:i*4+4]) for i in range(len(palette)//4)]
runs=[]
for index,group in itertools.groupby(values):
 n=sum(1 for _ in group)
 while n: take=min(65535,n);runs.append(f'{take:04x}{index:02x}');n-=take
fallback={}
for key,im in images.items():
 w={'background':128,'base':80,'turret':36,'crawler':22,'tank':26,'capsule':24,'crystal':24,'crawlerBody':26,'tankBody':30,'robot':30,'drillBit':20,'flyerBody':34,'flyerWing':30,'runnerBody':30}[key]
 tiny=im.copy();tiny.thumbnail((w,round(w*im.height/im.width)),Image.Resampling.LANCZOS)
 # Discard nearly transparent pixels before quantization.
 pixels=[(r,g,b,255 if a>160 else 0) for r,g,b,a in tiny.getdata()];tiny.putdata(pixels)
 q=tiny.quantize(colors=10 if key=='background' else 14,method=Image.Quantize.FASTOCTREE)
 pal=q.getpalette('RGBA');px=q.load();rectangles=[];active={}
 for y in range(q.height):
  row=[];x=0
  while x<q.width:
   c=px[x,y];right=x+1
   while right<q.width and px[right,y]==c:right+=1
   if pal[c*4+3]>160:row.append((x,right-x,c))
   x=right
  nextActive={}
  for x,width,c in row:
   key2=(x,width,c)
   if key2 in active: idx=active[key2];rectangles[idx][3]+=1
   else: idx=len(rectangles);rectangles.append([x,y,width,1,c])
   nextActive[key2]=idx
  active=nextActive
 fallback[key]={'w':q.width,'h':q.height,'colors':[pal[i:i+3] for i in range(0,len(pal),4)],'rects':rectangles}
 print(key,'fallback rectangles',len(rectangles))
def lua(value):
 if isinstance(value,dict):return '{'+','.join('['+json.dumps(k)+']='+lua(v) for k,v in value.items())+'}'
 if isinstance(value,list):return '{'+','.join(map(lua,value))+'}'
 if isinstance(value,str):return json.dumps(value,ensure_ascii=False)
 return str(value)
payload={'size':1024,'palette':''.join(colors),'rle':''.join(runs),'sprites':rects,'fallback':fallback}
(ROOT/'src/ArtData.lua').write_text('-- Generated art data. Do not hand-edit.\nreturn '+lua(payload)+'\n')
(ROOT/'assets/atlas-layout.json').write_text(json.dumps(rects,indent=2))
print('Atlas RLE runs:',len(runs),'ArtData bytes:',(ROOT/'src/ArtData.lua').stat().st_size)
