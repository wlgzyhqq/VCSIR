from pathlib import Path
import json, subprocess, struct, os
root=Path(__file__).resolve().parent
gcc=Path('C:/msys64/ucrt64/bin/riscv32-unknown-elf-gcc.exe')
objcopy=gcc.with_name('riscv32-unknown-elf-objcopy.exe')
os.environ['PATH']=str(gcc.parent)+os.pathsep+os.environ['PATH']
manifest=json.loads((root.parent/'reference-projects/sources.json').read_text(encoding='utf-8-sig'))
tests=Path(next(x['path'] for x in manifest if x['name']=='riscv-tests'))
out=root/'build/firmware';out.mkdir(parents=True,exist_ok=True)
flags=['-march=rv32i_zicsr_zifencei','-mabi=ilp32','-mno-relax','-nostdlib','-ffreestanding','-fno-builtin','-Os','-msmall-data-limit=0','-Wl,--no-relax','-T',str(root/'firmware/link.ld')]
def build(name,sources,extra=[]):
    elf=out/(name+'.elf');binary=out/(name+'.bin')
    run=subprocess.run([str(gcc),*flags,*extra,*map(str,sources),'-o',str(elf)],capture_output=True,text=True)
    if run.returncode:
        print(run.stdout,run.stderr);run.check_returncode()
    subprocess.run([str(objcopy),'-O','binary',str(elf),str(binary)],check=True)
    data=binary.read_bytes();assert len(data)<=65536
    data=data+b'\0'*(65536-len(data))
    h=out/(name+'.hex');h.write_text('\n'.join(f'{x[0]:08x}' for x in struct.iter_unpack('<I',data))+'\n')
    return h
demo=build('demo',[root/'firmware/start.S',root/'firmware/demo.c'])
(root/'firmware/demo.hex').write_bytes(demo.read_bytes())
names=['demo']
for f in sorted((tests/'isa/rv32ui').glob('*.S')):
    name='rv32ui-'+f.stem
    build(name,[f],['-I',str(root/'sim'),'-I',str(tests/'isa/macros/scalar')]);names.append(name)
for f in sorted((root/'firmware').glob('test_*.S')):
    build(f.stem,[f]);names.append(f.stem)
(root/'build/firmware/tests.json').write_text(json.dumps(names,indent=2))
print(f'Built {len(names)} firmware images using RV32I + Zicsr/Zifencei (no M/C).')
