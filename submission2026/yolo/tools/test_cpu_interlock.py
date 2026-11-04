"""Reuse immutable instruction fixtures; simulate the production CPU and bus.
The three external GPIO/UART-injection tests require a different harness.
"""
from pathlib import Path
import json,hashlib,subprocess,os,time,re
R=Path(__file__).resolve().parents[1];S=R.parent/'final2/validation/cpu90';O=R/'output/cpu-interlock';O.mkdir(exist_ok=True)
env=dict(os.environ);env['PATH']='C:/msys64/ucrt64/bin'+os.pathsep+env.get('PATH','')
files=['tools/tb_yolo_cpu.v','rtl/final_bus.v','rtl/final_uart.v','rtl/final_btb.v']+[p.relative_to(R).as_posix() for d in ['rtl/core','rtl/cache'] for p in sorted((R/d).glob('*.v'))]
report=dict(passed=False,simulation=True,load_bypass=False,source_sha256={p:hashlib.sha256((R/p).read_bytes()).hexdigest() for p in files},tests=[],excluded=['test_gpio_irq','test_uart_irq','test_uart_overrun','test_cache_contract'],exclusion_reason='GPIO/UART need external injection; old cache_contract uses CPU-bench-only counter MMIO and its0x40000000 physical alias, absent in this DDR SoC.')
def save():(O/'report.json').write_text(json.dumps(report,indent=2)+'\n')
save()
# Icarus requires declarations referenced inside a generate block before that
# block. Relocate wire declarations in a simulation copy; no expression,
# register, assignment or production build input is changed.
original=R/'rtl/core/riscv_core.v';text=original.read_text();moved=[]
for name in ['squash_decode_w','fetch_accept_w','fetch_valid_w']:
 match=re.search(r'wire\s+'+name+r'\s*;',text);assert match,name
 moved.append(match[0]);text=text[:match.start()]+text[match.end():]
text=text.replace('generate\n','\n'.join(moved)+'\ngenerate\n',1)
copy=O/'riscv_core.v';copy.write_text(text);report['simulation_only_declaration_relocation']=moved;save()
compile_files=[str(copy) if p=='rtl/core/riscv_core.v' else p for p in files]
subprocess.run(['C:/msys64/ucrt64/bin/iverilog.exe','-g2012','-Irtl/core','-s','tb_yolo_cpu','-o',str(O/'cpu.vvp'),*compile_files],cwd=R,env=env,check=True)
for row in json.loads((S/'output/validation/tests/manifest.json').read_text()):
 if row['name'] in report['excluded']:continue
 payload=(S/row['path']).read_bytes();assert hashlib.sha256(payload).hexdigest()==row['sha256']
 payload+=bytes((-len(payload))%4);hexfile=O/(row['name']+'.hex');hexfile.write_text('\n'.join(f'{int.from_bytes(payload[i:i+4],"little"):08x}' for i in range(0,len(payload),4))+'\n')
 for stalls in [0,1]:
  started=time.time();log=O/(row['name']+f'-{stalls}.log')
  with log.open('wb') as out:p=subprocess.run(['C:/msys64/ucrt64/bin/vvp.exe',str(O/'cpu.vvp'),'+image='+str(hexfile),'+stalls='+str(stalls),'+misaligned='+str(int(row['name']=='rv32ui-ma_data'))],cwd=R,env=env,stdout=out,stderr=subprocess.STDOUT,timeout=180)
  text=log.read_text(errors='replace');passed=p.returncode==0 and 'PASS CPU' in text
  report['tests'].append(dict(name=row['name'],fixture_sha256=row['sha256'],stalls=stalls,passed=passed,seconds=time.time()-started,log=str(log.relative_to(R))));save()
  print(row['name'],stalls,'PASS' if passed else text[-1400:],flush=True)
  if not passed:raise SystemExit(1)
report['passed']=True;save();print('PASS CPU interlock fixtures, immediate and stalled DDR responses',flush=True)
