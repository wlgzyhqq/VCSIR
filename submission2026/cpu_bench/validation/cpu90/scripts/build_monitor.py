from pathlib import Path
import os,subprocess,struct,json,hashlib
R=Path(__file__).resolve().parents[1];G=Path('C:/msys64/ucrt64/bin/riscv32-unknown-elf-gcc.exe');env=dict(os.environ);env['PATH']=str(G.parent)+os.pathsep+env.get('PATH','');O=R/'output/validation';O.mkdir(exist_ok=True)
flags=['-march=rv32im_zicsr_zifencei','-mabi=ilp32','-mno-relax','-nostdlib','-ffreestanding','-fno-builtin','-msmall-data-limit=0','-Os','-Wl,--no-relax','-T',str(R/'firmware/validation/monitor.ld')]
src=[R/'firmware/validation/monitor.S',R/'firmware/validation/monitor.c']
subprocess.run([str(G),*flags,*map(str,src),'-o',str(O/'monitor.elf')],env=env,check=True)
subprocess.run([str(G.with_name('riscv32-unknown-elf-objcopy.exe')),'-O','binary',str(O/'monitor.elf'),str(O/'monitor.bin')],check=True)
data=(O/'monitor.bin').read_bytes();assert len(data)<0x2000
(R/'firmware/cpu_only/coremark.hex').write_text(''.join(f'{w:08x}\n' for w in struct.unpack('<16384I',data+bytes(65536-len(data)))))
(O/'monitor.json').write_text(json.dumps(dict(bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),flags=flags,source_sha256={p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in src}),indent=2)+'\n');print('Monitor built',len(data),'bytes')
