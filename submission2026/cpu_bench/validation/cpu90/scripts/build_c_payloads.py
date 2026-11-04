"""RAM-linked actual M vectors and unmodified CoreMark, separate from monitor."""
from pathlib import Path
import os,subprocess,json,hashlib,shutil
R=Path(__file__).resolve().parents[1];O=R/'output/validation/tests'
G=Path('C:/msys64/ucrt64/bin/riscv32-unknown-elf-gcc.exe');env=dict(os.environ);env['PATH']=str(G.parent)+os.pathsep+env.get('PATH','')
v=R/'third_party/coremark';f=R/'firmware/validation'
fixture=f/'m_vectors.c'
if not fixture.exists():shutil.copy2(R.parents[2]/'FINAL/output/cpu-m/m-instructions.c',fixture)
lib=subprocess.check_output([str(G),'-march=rv32im','-mabi=ilp32','-print-libgcc-file-name'],env=env,text=True).strip()
assert '/rv32im/ilp32/' in lib.replace('\\','/')
flags=['-march=rv32im_zicsr_zifencei','-mabi=ilp32','-mrelax','-nostdlib','-ffreestanding','-fno-builtin','-ffp-contract=off','-fno-fast-math','-O3','-ffunction-sections','-fdata-sections','-Wl,--gc-sections','-msmall-data-limit=0','-Wl,--relax,--no-relax-gp','-T',str(f/'payload.ld'),'-I'+str(R/'firmware'),'-I'+str(R/'firmware/cpu_only/port'),'-I'+str(v),'-DCOREMARK_REQUIRE_M=1','-DFLAGS_STR="RV32IM O3 no-LTO relax no-gp software-float"']
manifest=json.loads((O/'manifest.json').read_text())
for name,sources,defines in [('test_m_vectors',[fixture],['-DVALIDATE_M']),('coremark_capture',[R/'firmware/cpu_only/port/core_portme.c',R/'firmware/runtime.c']+[v/n for n in ['core_main.c','core_list_join.c','core_matrix.c','core_state.c','core_util.c']],[])]:
 sources=[f/'payload_c_start.S',f/'payload_main.c']+sources
 elf=O/(name+'.elf');binary=O/(name+'.bin')
 subprocess.run([str(G),*flags,*defines,*map(str,sources),lib,'-o',str(elf)],check=True,env=env)
 subprocess.run([str(G.with_name('riscv32-unknown-elf-objcopy.exe')),'-O','binary',str(elf),str(binary)],check=True)
 data=binary.read_bytes();assert len(data)<0xc000
 with (O/(name+'.disasm.txt')).open('w') as out:subprocess.run([str(G.with_name('riscv32-unknown-elf-objdump.exe')),'-d',str(elf)],stdout=out,check=True)
 row=dict(name=name,path=binary.relative_to(R).as_posix(),bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),flags=flags+defines,source_sha256={p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},policy='PASS result1',executed=False)
 if name.startswith('test_'):manifest=[i for i in manifest if i['name']!=name]+[row]
 (O/(name+'.json')).write_text(json.dumps(row,indent=2)+'\n');print(name,len(data))
(O/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
