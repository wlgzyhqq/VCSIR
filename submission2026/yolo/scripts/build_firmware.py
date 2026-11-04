"""Build the YOLO application firmware (not the preserved LLM or score build)."""
from pathlib import Path
import subprocess,os,json,hashlib,argparse
from firmware_layout import check_layout
ap=argparse.ArgumentParser();ap.add_argument('--inference',action='store_true');a=ap.parse_args()
R=Path(__file__).resolve().parents[1];O=R/('output/inference-fw' if a.inference else 'output/firmware');O.mkdir(exist_ok=True)
G=Path('C:/msys64/ucrt64/bin/riscv32-unknown-elf-gcc.exe');env=dict(os.environ);env['PATH']=str(G.parent)+os.pathsep+env.get('PATH','')
flags=['-march=rv32im_zicsr_zifencei','-mabi=ilp32','-mno-relax','-nostdlib','-ffreestanding','-fno-builtin','-msmall-data-limit=0','-Os','-flto','-Wall','-Wextra','-Werror','-Wl,--no-relax','-T',str(R/'firmware/link.ld')]
lib=subprocess.check_output([str(G),'-march=rv32im','-mabi=ilp32','-print-libgcc-file-name'],text=True,env=env).strip()
sources=[R/'firmware'/n for n in ['start.S','main.c','storage.c','runtime.c']]
if a.inference:flags+=['-DYOLO_INFERENCE'];sources+=[R/'firmware/yolo_network.c',R/'firmware/yolo_preprocess.c']
subprocess.run([str(G),*flags,*map(str,sources),lib,'-Wl,-Map='+str(O/'demo.map'),'-o',str(O/'demo.elf')],check=True,env=env)
subprocess.run([str(G.with_name('riscv32-unknown-elf-objcopy.exe')),'-O','binary',str(O/'demo.elf'),str(O/'demo.bin')],check=True)
data=(O/'demo.bin').read_bytes();data+=bytes((-len(data))%4);(O/'demo.bin').write_bytes(data);assert len(data)<0x1e000
layout=check_layout(O/'demo.elf');dependencies=sources+list((R/'firmware').glob('*.h'))
(O/'firmware.json').write_text(json.dumps(dict(CPU_clock_Hz=90000000,bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),flags=flags,layout=layout,sources={p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in dependencies},milestone='inference development - board unverified' if a.inference else 'real image/TF path; inference not connected'),indent=2)+'\n')
print('YOLO inference' if a.inference else 'YOLO image','firmware built',len(data),'bytes')
