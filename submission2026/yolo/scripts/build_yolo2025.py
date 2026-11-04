"""Fresh reproducible CPU90/CNN90/DDR100,64-lane build; routing is2025 only."""
from pathlib import Path
import argparse,subprocess,sys,re
R=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('--name',required=True,help='New lowercase alphanumeric build name; existing builds are never overwritten');a=ap.parse_args()
assert re.fullmatch('[a-z0-9]+',a.name)
syn='cnn-'+a.name+'-synth';physical='pds2025-'+a.name;image='output/sd-'+a.name
assert not any((R/p).exists() for p in [syn,physical,image,'output/reports/'+a.name]),'Use a fresh name to preserve previous evidence'
def run(script,*args):
 subprocess.run([sys.executable,script,*args],cwd=R,check=True)
run('tools/check_model_contract.py')
run('scripts/build_firmware.py','--inference')
run('scripts/build_tf_boot.py')
run('scripts/prepare_cnn.py','--build-dir',syn)
run('scripts/build_cnn.py','--build-dir',syn,'--tag',a.name+'synth','--synth-only')
run('scripts/prepare_pds2025_netlist.py','--baseline-dir',syn,'--build-dir',physical)
run('scripts/build_pds2025.py','--build-dir',physical,'--tag',a.name)
run('tools/make_sd_image.py','--firmware','output/inference-fw/demo.bin','--output-dir',image)
run('tools/verify_sd_image.py','--image',image+'/final_yolo.img','--firmware','output/inference-fw/demo.bin')
print('Build/file checks completed. Board acceptance is a separate step; no FPGA/TF/Flash programming performed.')
