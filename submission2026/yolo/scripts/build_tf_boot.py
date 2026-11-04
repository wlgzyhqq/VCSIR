"""Compile small stage0 and embed only its bytes. Main demo.bin stays external."""
from pathlib import Path
import hashlib,json,os,re,subprocess
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'output/boot-tf';OUT.mkdir(exist_ok=True)
gcc=Path('C:/msys64/ucrt64/bin/riscv32-unknown-elf-gcc.exe')
env=dict(os.environ);env['PATH']=str(gcc.parent)+os.pathsep+env.get('PATH','')
flags=['-march=rv32i_zicsr_zifencei','-mabi=ilp32','-mno-relax','-nostdlib','-ffreestanding','-fno-builtin',
 '-fno-fast-math','-ffp-contract=off','-Os','-flto','-msmall-data-limit=0','-Wall','-Wextra','-Werror',
 '-Wl,--no-relax','-T',str(ROOT/'firmware/stage0/link.ld'),'-Wl,-Map='+str(OUT/'stage0.map')]
library=subprocess.check_output([str(gcc),'-march=rv32i','-mabi=ilp32','-print-libgcc-file-name'],env=env,text=True).strip()
assert '/rv32i/ilp32/' in library.replace('\\','/')
elf=OUT/'stage0.elf';binary=OUT/'stage0.bin'
subprocess.run([str(gcc),*flags,str(ROOT/'firmware/stage0/start.S'),str(ROOT/'firmware/stage0/main.c'),library,'-o',str(elf)],env=env,check=True)
subprocess.run([str(gcc.with_name('riscv32-unknown-elf-objcopy.exe')),'-O','binary',str(elf),str(binary)],check=True)
data=binary.read_bytes();assert 0<len(data)<=8192
padded=data+b'\0'*(-len(data)%32);banks=(len(padded)+2047)//2048;rom=padded.ljust(banks*2048,b'\0')
lines=['// TF boot: only the standalone stage0 is embedded; main firmware is on TF.']
for bank in range(banks):
 lines += [f'module final_boot_bank_{bank}(input clk,input [8:0] addr,output reg [31:0] data) /* synthesis syn_romstyle = "block_rom" */;', ' always @(posedge clk) case(addr)']
 for i in range(512):lines.append(f" 9'd{i}:data<=32'h{int.from_bytes(rom[bank*2048+i*4:bank*2048+i*4+4],'little'):08x};")
 lines += [' default:data<=0;',' endcase','endmodule']
lines += ['module final_boot_prefix(input clk,input [8:0] addr,input [4:0] bank,output reg [31:0] data);']
for i in range(banks):lines += [f' wire [31:0] data_{i};',f' final_boot_bank_{i} u_bank_{i}(.clk(clk),.addr(addr),.data(data_{i}));']
lines += [' always @* case(bank)']+[f" 5'd{i}:data=data_{i};" for i in range(banks)]+[' default:data=0;',' endcase','endmodule']
source='\n'.join(lines)+'\n';assert b''.join(int(x,16).to_bytes(4,'little') for x in re.findall("data<=32'h([0-9a-f]{8});",source))==rom
(ROOT/'rtl/final_boot_prefix.v').write_text(source,'utf8')
(ROOT/'rtl/tf_boot_config.vh').write_text(f'// Stage0 byte count, checked against actual ELF/bin.\nlocalparam TF_STAGE0_LINES={len(padded)//32};\n','utf8')
dump=subprocess.check_output([str(gcc.with_name('riscv32-unknown-elf-objdump.exe')),'-d',str(elf)],text=True)
names=re.findall(r'^\s*[0-9a-f]+:\s+[0-9a-f]+\s+([a-z][a-z0-9._]+)',dump,re.M)
bad=[n for n in names if n in ['mul','mulh','mulhu','mulhsu','div','divu','rem','remu'] or n.startswith('f') and n not in ['fence','fence.i']];assert not bad,bad
assert '54464' in dump.lower(),'Missing controlled handoff magic'
undefined=subprocess.check_output([str(gcc.with_name('riscv32-unknown-elf-nm.exe')),'-u',str(elf)],text=True);assert not undefined.strip()
main=(ROOT/'output/firmware/demo.bin').read_bytes()
report=dict(CPU_clock_Hz=90000000,passed=True,board_test=False,RTL_simulation=False,stage0_bytes=len(data),padded_bytes=len(padded),ROM_banks=banks,
 stage0_sha256=hashlib.sha256(data).hexdigest().upper(),main_firmware_sha256=hashlib.sha256(main).hexdigest().upper(),
 M_F_instructions=bad,stage0_address='03c00000',staging_address='03d00000',main_address='00000000',
 reset_handoff='bus quiescent -> CPU/cache reset -> hardware copy/readback -> reset vector 0',
 source_sha256={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'firmware/stage0').rglob('*') if p.is_file()})
(ROOT/'output/reports/boot-tf-build.json').write_text(json.dumps(report,indent=2)+'\n','utf8')
print('TF stage0 compiled:',len(data),'bytes,',banks,'ROM banks; no M/F; main firmware is NOT embedded')
