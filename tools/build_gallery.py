"""Build the optional lazy-loaded illustration atlas; original battle atlas unchanged."""
from pathlib import Path
from PIL import Image
from itertools import groupby
root=Path(__file__).resolve().parents[1]
im=Image.open(root/'assets/expedition-gallery.png').convert('RGB').resize((512,512),Image.Resampling.LANCZOS).quantize(colors=128)
im.save(root/'assets/expedition-gallery-runtime.png',optimize=True)
pal=im.getpalette();palette=''.join('%02x%02x%02xff'%tuple(pal[i:i+3]) for i in range(0,384,3))
runs=[]
for color,g in groupby(im.getdata()):
 n=sum(1 for _ in g)
 while n:r=min(n,65535);runs.append(f'{r:04x}{color:02x}');n-=r
(root/'src/GalleryData.lua').write_text('-- Generated from assets/expedition-gallery.png by tools/build_gallery.py\nreturn {size=512,palette="'+palette+'",rle="'+''.join(runs)+'"}\n')

names=['cannon','machine','arc','rail','flame','mortar','crawler','runner','tank','spitter','elite','warden','planet1','planet2','planet3','crate']
source=Image.open(root/'assets/expedition-gallery.png').convert('RGB')
folder=root/'assets/gallery';folder.mkdir(exist_ok=True)
for i,name in enumerate(names):
 x=i%4*256;y=i//4*256
 source.crop((x+3,y+3,x+253,y+253)).save(folder/(name+'.png'),optimize=True)
