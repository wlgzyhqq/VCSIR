"""Read-only JTAG scan, no programming."""
from pathlib import Path
import subprocess,json
R=Path(__file__).resolve().parents[1]
script='cfg_set_tcl_break -flag true\ncfg_connect -ip 127.0.0.1 -port 65420\ncfg_scan_chain\nexit\n'
log=R/'output/reports/cpu-only-jtag-scan.log'
with log.open('wb') as f:
 try:
  p=subprocess.run(['D:/pango/PDS_2022.2-SP1-Lite/bin/cdt_cfg_shell.exe'],input=script.encode(),stdout=f,stderr=subprocess.STDOUT,timeout=50,creationflags=subprocess.CREATE_NO_WINDOW)
  code=p.returncode
 except subprocess.TimeoutExpired:code='timeout'
print('Read-only JTAG scan',code,flush=True);print(log.read_text(errors='replace')[-2500:],flush=True)
