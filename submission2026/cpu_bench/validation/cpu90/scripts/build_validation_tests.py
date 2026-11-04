from pathlib import Path
import os,subprocess,json,hashlib
R=Path(__file__).resolve().parents[1];O=R/'output/validation/tests';O.mkdir(parents=True,exist_ok=True)
G=Path('C:/msys64/ucrt64/bin/riscv32-unknown-elf-gcc.exe');env=dict(os.environ);env['PATH']=str(G.parent)+os.pathsep+env.get('PATH','')
flags=['-march=rv32i_zicsr_zifencei','-mabi=ilp32','-mno-relax','-nostdlib','-Wl,--no-relax,--no-warn-rwx-segments','-T',str(R/'firmware/validation/payload.ld'),'-I'+str(R/'firmware/tests/include')]
rows=[]
items=[('rv32ui-'+p.stem,p) for p in sorted((R/'firmware/tests/rv32ui').glob('*.S'))]+[(p.stem,p) for p in sorted((R/'firmware/validation').glob('test_*.S'))]
for name,src in items:
 elf=O/(name+'.elf');binary=O/(name+'.bin')
 subprocess.run([str(G),*flags,str(src),'-o',str(elf)],env=env,check=True,stdout=subprocess.DEVNULL)
 subprocess.run([str(G.with_name('riscv32-unknown-elf-objcopy.exe')),'-O','binary',str(elf),str(binary)],check=True)
 data=binary.read_bytes();assert len(data)<=0xc000
 rows.append(dict(name=name,path=binary.relative_to(R).as_posix(),bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),policy='misaligned-access EEI: expect trap, not native unaligned execution' if name=='rv32ui-ma_data' else 'PASS result1',executed=False))
(O/'manifest.json').write_text(json.dumps(rows,indent=2)+'\n');print('Built',len(rows),'payloads; no execution claimed')
