"""Original, deterministic synthesized SFX. No sampled third-party audio.
Upload WAVs to the experience owner and map IDs in Config.SoundIds for full sound design.
"""
from pathlib import Path
import wave,math,random,struct
ROOT=Path(__file__).resolve().parents[1];folder=ROOT/'assets/audio';folder.mkdir(exist_ok=True)
rate=22050
spec={'cannon':(.28,75),'machine':(.09,185),'arc':(.32,760),'impact':(.24,95),'warning':(.46,330),'upgrade':(.48,620),'deposit':(.28,890),'supply':(.46,480),'victory':(.9,523),'defeat':(.75,220),'click':(.055,1200),'drill':(.65,90),'music':(8,110)}
for name,(duration,freq) in spec.items():
 rng=random.Random(500);samples=[];low=0
 for i in range(int(rate*duration)):
  t=i/rate;q=t/duration;noise=rng.uniform(-1,1);low=.83*low+.17*noise
  env=min(1,t/.008)*max(0,1-q)**2
  if name in ['cannon','impact']:value=(.65*low+.35*math.sin(2*math.pi*freq*t*(1-.6*q)))*env*math.exp(-q*2)
  elif name=='machine':value=(.7*noise+.3*math.sin(2*math.pi*freq*t))*env
  elif name=='arc':value=(math.sin(2*math.pi*freq*t+5*math.sin(2*math.pi*90*t))*.5+noise*.2)*env
  elif name=='drill':value=(math.sin(2*math.pi*freq*t)*.4+low*.4)*(1+.3*math.sin(2*math.pi*26*t))*env
  elif name=='music':value=.13*(math.sin(2*math.pi*110*t)+.4*math.sin(2*math.pi*165*t)+.3*math.sin(2*math.pi*220*t))*min(1,t/.25,(duration-t)/.25)
  else:
   steps=[1,1.25,1.5,2] if name in ['upgrade','victory','deposit'] else [1,.9,.75,.65] if name=='defeat' else [1,1.125]
   f=freq*steps[min(len(steps)-1,int(q*len(steps)))];value=(math.sin(2*math.pi*f*t)+.2*math.sin(2*math.pi*f*2*t))*env*.6
  samples.append(struct.pack('<h',int(max(-.9,min(.9,value))*32767)))
 with wave.open(str(folder/(name+'.wav')),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(b''.join(samples))
print('Generated 13 original mono WAV files, including optional ambient loop.')
