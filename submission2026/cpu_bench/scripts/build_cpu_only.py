"""Build unmodified official CoreMark kernels for the isolated CPU-only SoC."""
from pathlib import Path
import hashlib,json,os,subprocess,struct
R=Path(__file__).resolve().parents[1];F=R/'firmware/cpu_only';O=R/'output/cpu-only';O.mkdir(parents=True,exist_ok=True)
gcc=Path('C:/msys64/ucrt64/bin/riscv32-unknown-elf-gcc.exe');env=dict(os.environ);env['PATH']=str(gcc.parent)+os.pathsep+env.get('PATH','')
vendor=R/'third_party/coremark'
for line in (vendor/'coremark.md5').read_text().splitlines():
 fields=line.split()
 if len(fields)!=2:continue
 name=fields[1].lstrip('*');p=vendor/name
 if p.is_file() and hashlib.md5(p.read_bytes()).hexdigest()!=fields[0]:
  assert name=='coremark.h',name
  proof=json.loads((vendor/'official-header-proof.json').read_text())
  assert proof['byte_exact_official_header'] and proof['sha256']==hashlib.sha256(p.read_bytes()).hexdigest()
flags=['-march=rv32im_zicsr_zifencei','-mabi=ilp32','-mrelax','-nostdlib','-ffreestanding','-fno-builtin','-ffp-contract=off','-fno-fast-math','-O3','-ffunction-sections','-fdata-sections','-Wl,--gc-sections','-msmall-data-limit=0','-Wl,--relax,--no-relax-gp','-T',str(F/'link.ld'),'-I'+str(F/'port'),'-I'+str(vendor),'-DCOREMARK_REQUIRE_M=1','-DFLAGS_STR="RV32IM O3 no-LTO relax no-gp software-float"']
lib=subprocess.check_output([str(gcc),'-march=rv32im','-mabi=ilp32','-print-libgcc-file-name'],env=env,text=True).strip()
assert '/rv32im/ilp32/' in lib.replace('\\','/')
sources=[F/'start.S',F/'main.c',F/'port/core_portme.c',R/'firmware/runtime.c']+[vendor/n for n in ['core_main.c','core_list_join.c','core_matrix.c','core_state.c','core_util.c']]
elf=O/'coremark.elf';binary=O/'coremark.bin'
subprocess.run([str(gcc),*flags,*map(str,sources),lib,'-Wl,-Map='+str(O/'coremark.map'),'-o',str(elf)],check=True,env=env)
subprocess.run([str(gcc.with_name('riscv32-unknown-elf-objcopy.exe')),'-O','binary',str(elf),str(binary)],check=True,env=env)
data=binary.read_bytes();assert len(data)<0xe000
# Fully initialized RAM words; BSS is cleared explicitly by startup.
padded=data+bytes(65536-len(data));words=struct.unpack('<16384I',padded)
(F/'coremark.hex').write_text(''.join(f'{w:08x}\n' for w in words))
with (O/'coremark.disasm.txt').open('w') as f:subprocess.run([str(gcc.with_name('riscv32-unknown-elf-objdump.exe')),'-d',str(elf)],stdout=f,check=True,env=env)
subprocess.run([str(gcc.with_name('riscv32-unknown-elf-size.exe')),str(elf)],check=True,env=env)
report=dict(CPU_target_hz=90000000,timer_target_hz=90000000,iterations=3000,seeds=[0,1],bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),compiler_flags=flags,board_test=False,score=None,sources={p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sources})
(O/'firmware.json').write_text(json.dumps(report,indent=2)+'\n')
print('CPU-only CoreMark built; no board performance claim',len(data),'bytes')
