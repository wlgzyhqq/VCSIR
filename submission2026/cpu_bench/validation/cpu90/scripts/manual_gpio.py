"""Replay LED walk while recording synchronized KEY2/KEY3 input combinations."""
import argparse,time,json
from run_validation import Monitor,Serial,O
ap=argparse.ArgumentParser();ap.add_argument('--seconds',type=float,default=120);ap.add_argument('--port',default='COM12');a=ap.parse_args()
assert 1<=a.seconds<=600
p=O/'manual-gpio-v3.json';d=dict(physical_LED_confirmation='pending user observation',key_states=[],samples=[],running_image=json.loads((O/'running-image.json').read_text()))
with Serial(a.port) as s:
 m=Monitor(s);assert m.ping()=='@PONG VAL3';m.reset();m.write(0x80001008,0);m.write(0x80001010,0xffffffff)
 print("LED/KEY TEST STARTED",flush=True)
 start=time.monotonic();i=0
 last_keys=None
 try:
  while time.monotonic()-start<a.seconds:
   led=1<<(i%8);m.write(0x80001000,led<<8);inp=m.read(0x80001004);keys=(inp>>8)&3
   if keys!=last_keys:print('KEY_STATE='+str(keys),flush=True);last_keys=keys
   d['samples'].append(dict(t=time.monotonic()-start,LED=led,keys=keys,raw_gpio_input=inp));d['key_states']=sorted(set(d['key_states']+[keys]));p.write_text(json.dumps(d,indent=2)+'\n');i+=1;(O/'manual-gpio-v3.uart.bin').write_bytes(m.log);time.sleep(.3)
   if set(d['key_states'])=={0,1,2,3} and keys==0:break
 finally:
  m.write(0x80001000,0x5500);d['gpio_pending']=m.read(0x80001010);d['key_combinations_verified']=set(d['key_states'])=={0,1,2,3};p.write_text(json.dumps(d,indent=2)+'\n');(O/'manual-gpio-v3.uart.bin').write_bytes(m.log)
print('Key states',d['key_states'],'LED confirmation remains manual')
