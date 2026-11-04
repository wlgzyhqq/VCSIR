"""Board-only diagnostics: volatile JTAG, CRC-checked uploads, actual results."""
from pathlib import Path
import argparse,hashlib,json,re,struct,subprocess,time,zlib
from serial_transport import Serial
R=Path(__file__).resolve().parents[1]
O=R/'output/validation';O.mkdir(exist_ok=True)
class Monitor:
 def __init__(self,serial):self.s=serial;self.buf=bytearray();self.log=bytearray()
 def line(self,timeout=5):
  end=time.monotonic()+timeout
  while time.monotonic()<end:
   if b'\n' in self.buf:
    a,_,rest=self.buf.partition(b'\n');self.buf=bytearray(rest);return a.strip(b'\r').decode('ascii','replace')
   data=self.s.read();self.buf.extend(data);self.log.extend(data)
  raise TimeoutError(bytes(self.buf[-200:]))
 def until(self,prefix,timeout=5):
  end=time.monotonic()+timeout
  while time.monotonic()<end:
   line=self.line(max(.1,end-time.monotonic()))
   if line.startswith(prefix):return line
  raise TimeoutError(prefix)
 def ping(self):self.s.write(b'P');return self.until('@PONG')
 def reset(self):self.s.write(b'Z');line=self.until('@MONBOOT');self.ping();return line
 def write(self,addr,value):
  self.s.write(b'W'+struct.pack('<II',addr,value));return self.until('@WRITE')
 def read(self,addr):
  self.s.write(b'Q'+struct.pack('<I',addr));line=self.until('@READ');words=line.split();assert int(words[1],16)==addr;return int(words[2],16)
 def load(self,path):
  data=path.read_bytes();crc=zlib.crc32(data);self.s.write(b'L'+struct.pack('<II',len(data),crc)+data)
  line=self.until('@LOAD',max(8,len(data)/8000+3));v=[int(x,16) for x in line.split()[1:]]
  assert v[:3]==[len(data),crc,crc],line
  assert not(v[3]&4),'UART overrun during upload: '+line
  return line
 def run(self,timeout=6):
  self.s.write(b'R');self.until('@RUN',5)
  end=time.monotonic()+timeout
  while time.monotonic()<end:
   line=self.line(max(.1,end-time.monotonic()))
   if line.startswith(('@RESULT','@TRAP','@MONBOOT')):return line
  raise TimeoutError('no test result')
 def metrics(self):return [self.read(0x80004100+4*i) for i in range(21)]
def program():
 b=json.loads((R/'output/reports/cpu-only-build.json').read_text());assert b['exit_code']==0 and b['timing_qualified']
 for n,h in b['source_sha256'].items():
  if n!='cpu_bench.pds':assert hashlib.sha256((R/n).read_bytes()).hexdigest()==h,n
 bit=R/'generate_bitstream/cpu_bench_top.sbit'
 script=f'cfg_set_tcl_break -flag true\ncfg_connect -ip 127.0.0.1 -port 65420\ncfg_scan_chain\ncfg_assign_file -file {{{bit.as_posix()}}} -device_index 0\ncfg_program -device_index 0\ncfg_read_device_property -device_index 0 -mode 3\nexit\n'
 p=subprocess.run(['D:/pango/PDS_2022.2-SP1-Lite/bin/cdt_cfg_shell.exe'],input=script.encode(),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=65,creationflags=subprocess.CREATE_NO_WINDOW)
 (O/'jtag.log').write_bytes(p.stdout);s=p.stdout.decode(errors='replace')
 assert p.returncode==0 and not re.search(r'^E:',s,re.M) and 'Executing : cfg_program -device_index 0 successfully.' in s and re.search(r'Bit 12:\s+1\s+done',s),s[-1800:]
 sha=hashlib.sha256(bit.read_bytes()).hexdigest()
 (O/'running-image.json').write_text(json.dumps(dict(bitstream_sha256=sha,source_sha256=b['source_sha256']),indent=2)+'\n')
 return sha
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--program',action='store_true');ap.add_argument('--port',default='COM12');ap.add_argument('--filter',default='');ap.add_argument('--delay',type=int,default=0);ap.add_argument('--output',default='board-tests-v1.json');a=ap.parse_args()
 report=dict(board_test=True,passed=False,delay=a.delay,tests=[],TF_written=False,Flash_written=False)
 target=O/a.output
 with Serial(a.port) as serial:
  m=Monitor(serial)
  try:
   if a.program:report['bitstream_sha256']=program()
   if not a.program and (O/'running-image.json').exists():report['running_image']=json.loads((O/'running-image.json').read_text())
   report['handshake']=m.ping();assert m.read(0x8000403c) in (0x56414c31,0x56414c33)
   items=json.loads((O/'tests/manifest.json').read_text())
   for item in items:
    if a.filter and a.filter not in item['name']:continue
    row=dict(name=item['name'],sha256=item['sha256'],passed=False);report['tests'].append(row)
    try:
     row['reset']=m.reset();m.write(0x80004018,a.delay);row['load']=m.load(R/item['path'])
     if item['name'] in ('test_uart_irq','test_uart_overrun'):
      m.s.write(b'R');m.until('@RUN');m.s.write(b'Z' if item['name']=='test_uart_irq' else bytes(range(256)));row['result']=m.until('@RESULT',6)
     else:row['result']=m.run()
     if row['result'].startswith('@RESULT'):row['passed']=int(row['result'].split()[1],16)==1
     elif item['name']=='rv32ui-ma_data' and row['result'].startswith('@TRAP'):
      vals=[int(x,16) for x in row['result'].split()[1:]];row['passed']=vals[0]==4 and bool(vals[2]&1);row['policy']='Expected EEI misaligned-load trap; not native unaligned support'
     row['metrics']=m.metrics();row['protocol_errors']=row['metrics'][12]
     row['passed']=row['passed'] and row['protocol_errors']==0
     if item['name']=='test_privileged':row['trap_log']=[[m.read(0xd000+32*i+4*j) for j in range(8)] for i in range(23)]
     if item['name']=='test_nested_irq':row['nested_log']=[[m.read(0xda00+32*i+4*j) for j in range(3)] for i in range(2)]
     if item['name']=='test_cache_contract':row['cache_residency']=[m.read(0xd800+4*i) for i in range(4)]
     if item['name']=='test_counters':row['counter_deltas']=[m.read(0xd000+4*i) for i in range(5)]
     if item['name']=='test_predictor':row['trained_redirects']=m.read(0xd900)
     if item['name']=='test_uart_overrun':row['overrun_status_and_last_byte']=[m.read(0xdb00),m.read(0xdb04)]
    except Exception as e:row['error']=str(e)
    print(row['name'], 'PASS' if row['passed'] else 'FAIL',row.get('result',row.get('error')),flush=True)
    target.write_text(json.dumps(report,indent=2)+'\n')
   report['passed']=bool(report['tests']) and all(t['passed'] for t in report['tests'])
  finally:
   (O/(target.stem+'.uart.bin')).write_bytes(m.log);target.write_text(json.dumps(report,indent=2)+'\n')
 print('Board diagnostic completion',report['passed'],len(report['tests']),flush=True)
if __name__=='__main__':main()
