"""CPU-driven UART binary echo plus real GPIO pad feedback, no extra wires."""
import json,struct,zlib,time
from run_validation import Monitor,Serial,O
from capture_coremark import exact
def main():
 report=dict(passed=False,running_image=json.loads((O/'running-image.json').read_text()),uart=[],gpio=[],baud=115200,format='8N1',flow_control=False)
 with Serial('COM12') as s:
  m=Monitor(s)
  try:
   assert m.ping()=='@PONG VAL3'
   for title,data in [('empty',b''),('one',b'Z'),('all-bytes',bytes(range(256))),('utf8','你好，RISC-V！\r\n多轮输入\b'.encode()),('4KiB',bytes(range(256))*16),('32KiB',bytes(range(256))*128)]:
    m.reset();m.write(0x80004018,0);start=time.monotonic();m.s.write(b'E'+struct.pack('<I',len(data))+data)
    line=m.until('@ECHO ',max(8,len(data)/8000+5));_,n,crc=line.split()
    echoed=exact(m,len(data));m.until('@ECHOEND');status=m.read(0x80000004)
    row=dict(name=title,bytes=len(data),crc32=zlib.crc32(data),elapsed_seconds=time.monotonic()-start,uart_status=status,passed=echoed==data and int(n,16)==len(data) and int(crc,16)==zlib.crc32(data) and not(status&4))
    report['uart'].append(row);assert row['passed'],row
    print('UART',title,'PASS',len(data),flush=True)
   m.reset();m.write(0x80001008,3)
   for i in range(32):
    v=i&3;led=1<<(i&7);m.write(0x80001000,(led<<8)|v)
    actual=m.read(0x80001004)&3;row=dict(output=v,pad_input=actual,LED=led,passed=actual==v);report['gpio'].append(row);assert row['passed'],row
   m.write(0x80001000,0x5500);m.write(0x80001008,0)
   report['passed']=True
   print('GPIO32 pad feedback PASS; physical LED/key observation remains separate',flush=True)
  finally:
   (O/'io-v3.json').write_text(json.dumps(report,indent=2)+'\n');(O/'io-v3.uart.bin').write_bytes(m.log)
if __name__=='__main__':main()
