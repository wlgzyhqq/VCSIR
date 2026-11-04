"""Actual board trace RAM export. No simulation and no fabricated samples."""
from pathlib import Path
import sys,json,struct,time,hashlib,subprocess,csv,argparse,re
from run_validation import R,O,Serial,Monitor
DBG=0x80004000
CPU_FLAGS=['fetch_valid','issue','E1_valid','E2_valid','WB_valid','global_stall','lsu_stall','div_pending','csr_pending','decode_wait','unit_interlock','redirect','csr_redirect','retired','E1_load','E1_mul','E2_load','E2_mul','decoded_lsu','decoded_branch','decoded_mul','decoded_div','decoded_csr','WB_exception']
AXI_FLAGS=['I_ARVALID','I_ARREADY','I_RVALID','I_RREADY','I_RLAST','D_ARVALID','D_ARREADY','D_RVALID','D_RREADY','D_RLAST','D_AWVALID','D_AWREADY','D_WVALID','D_WREADY','D_WLAST','D_BVALID','D_BREADY']
def exact(m,n):
 end=time.monotonic()+15
 while len(m.buf)<n:
  if time.monotonic()>end:raise TimeoutError(('binary trace',n,len(m.buf)))
  b=m.s.read();m.log.extend(b);m.buf.extend(b)
 result=bytes(m.buf[:n]);del m.buf[:n];return result
def export(m,folder):
 m.s.write(b'T');head=m.until('@TRACE');_,n,status=head.split();n=int(n,16);status=int(status,16)
 assert n==256 and status&4,(n,status)
 data=exact(m,n*48);m.until('@TRACEEND')
 (folder/'physical.bin').write_bytes(data)
 raw=[list(struct.unpack_from('<12I',data,i*48)) for i in range(n)]
 start=(status>>24)&255;ordered=raw[start:]+raw[:start]
 rows=[]
 for w in ordered:
  row=dict(cycle=w[0],decode_pc=w[1],opcode=w[2],E1_pc=w[3],E2_pc=w[4],WB_pc=w[5],WB_result=w[6],cpu_flags=w[7],I_ARADDR=w[8],D_ADDR=w[9],axi_flags=w[10],lengths=w[11])
  row.update({name:(w[7]>>i)&1 for i,name in enumerate(CPU_FLAGS)})
  row.update({name:(w[10]>>i)&1 for i,name in enumerate(AXI_FLAGS)})
  rows.append(row)
 assert all(((rows[i]['cycle']-rows[i-1]['cycle'])&0xffffffff)==1 for i in range(1,n))
 with (folder/'samples.csv').open('w',newline='') as f:
  out=csv.DictWriter(f,fieldnames=rows[0].keys());out.writeheader();out.writerows(rows)
 sig=[('clk',1)]+[(k,32 if k in ['decode_pc','opcode','E1_pc','E2_pc','WB_pc','WB_result','I_ARADDR','D_ADDR','lengths'] else 1) for k in ['decode_pc','opcode','E1_pc','E2_pc','WB_pc','WB_result',*CPU_FLAGS,*AXI_FLAGS,'I_ARADDR','D_ADDR','lengths']]
 ids={k:'v'+str(i) for i,(k,_) in enumerate(sig)}
 with (folder/'capture.vcd').open('w') as f:
  f.write('$date actual FPGA export $end\n$timescale 1ps $end\n$scope module board_90MHz $end\n')
  for k,w in sig:f.write(f'$var wire {w} {ids[k]} {k} $end\n')
  f.write('$upscope $end\n$enddefinitions $end\n')
  for i,row in enumerate(rows):
   # Rounded per sample, no accumulating 11.111 ns period rounding error.
   t=round(i*1e12/90000000);f.write(f'#{t}\n0{ids["clk"]}\n')
   for k,w in sig[1:]:f.write(f'b{row[k]:0{w}b} {ids[k]}\n')
   f.write(f'#{round((i+.5)*1e12/90000000)}\n1{ids["clk"]}\n')
 counts={k:sum(row[k] for row in rows) for k in CPU_FLAGS}
 return dict(header=head,samples=n,start_physical_index=start,counts=counts,window_CPI=n/counts['retired'] if counts['retired'] else None,raw_sha256=hashlib.sha256(data).hexdigest())
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--region',choices=['entry','inner'],default='entry');a=ap.parse_args()
 nm=subprocess.check_output(['C:/msys64/ucrt64/bin/riscv32-unknown-elf-nm.exe',str(O/'tests/coremark_capture.elf')],text=True)
 symbols={line.split()[-1]:int(line.split()[0],16) for line in nm.splitlines() if len(line.split())==3}
 image=json.loads((O/'running-image.json').read_text())
 out=O/('coremark-captures' if a.region=='entry' else 'coremark-inner-captures');out.mkdir(exist_ok=True)
 settings=[('list','core_bench_list',0,0),('matrix','matrix_test',0,0),('state','core_state_transition',0,0)] if a.region=='entry' else [('list','core_bench_list',0x7c,0x0047a703),('matrix','matrix_test',0x270,0x00069783),('state','core_state_transition',0xac,0x0017c683)]
 payload=json.loads((O/'tests/coremark_capture.json').read_text())
 with Serial('COM12') as s:
  m=Monitor(s);assert m.ping()=='@PONG VAL3'
  for title,name,offset,opcode in settings:
   folder=out/title;folder.mkdir(exist_ok=True);pc=symbols[name]+offset
   if opcode:assert struct.unpack_from('<I',(O/'tests/coremark_capture.bin').read_bytes(),pc-0x2000)[0]==opcode,'Re-select inner PC after code layout change'
   report=dict(actual_board_capture=True,simulation=False,analyzer='cpu_validation_diag passive on-chip circular trace RAM',cpu_hz=90000000,region=a.region,trigger_symbol=name+(f'+0x{offset:x}' if offset else ''),trigger_pc=pc,running_image=image,payload=payload)
   try:
    log_start=len(m.log)
    report['reset']=m.reset();m.write(DBG+0x18,0);m.write(DBG+0x1c,3600000000);m.load(O/'tests/coremark_capture.bin')
    m.write(DBG+8,pc);m.write(DBG+12,0xffffffff);m.write(DBG,1)
    report['result']=m.run(50);assert report['result'].startswith('@RESULT 00000001'),report
    report['metrics']=m.metrics();assert report['metrics'][12]==0
    report['benchmark_runs']=[]
    for raw in re.findall(rb'@CM_RAW ([0-9a-f ]+)',bytes(m.log[log_start:])):
     v=[int(x,16) for x in raw.split()];seconds=(v[5]+(v[6]<<32))/v[4];assert v[2]==3000 and v[7]==1 and seconds>=10
     report['benchmark_runs'].append(dict(raw_fields=v,seconds=seconds,CoreMark=v[2]/seconds))
    assert len(report['benchmark_runs'])==2
    report['trace']=export(m,folder)
    report['passed']=True
    print(title,report['result'],'samples',report['trace']['samples'],'CPI',report['trace']['window_CPI'],flush=True)
   finally:
    (folder/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    (out/'all.uart.bin').write_bytes(m.log)
if __name__=='__main__':main()
