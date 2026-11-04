"""Configure only the exact timing-approved MOD11 image. Never writes Flash."""
import argparse,datetime,hashlib,json,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 sys.stdout.reconfigure(encoding='utf-8');a=argparse.ArgumentParser(description=__doc__)
 a.add_argument('--cfg-shell',default='D:/pango/PDS_2022.2-SP1-Lite/bin/cdt_cfg_shell.exe')
 a.add_argument('--ip',default='127.0.0.1');a.add_argument('--port',type=int,default=65420)
 a.add_argument('--tck-mhz',type=int,choices=[1,2,5,6,10,15]);args=a.parse_args()
 release=json.loads((ROOT/'output/reports/delivery.json').read_text('utf-8'));bit=ROOT/release['bitstream']
 sha=hashlib.sha256(bit.read_bytes()).hexdigest().upper()
 assert sha==release['sha256'] and 'MOD11' in release['variant'] and release['timing']=='All Constraints Met'
 assert 'All Constraints Met' in (ROOT/'output/reports/final_top.rtr').read_text()
 cable=f'cfg_set_cable_property -index 0 -freq {args.tck_mhz}Mhz\n' if args.tck_mhz else ''
 script=f'cfg_set_tcl_break -flag true\ncfg_connect -ip {args.ip} -port {args.port}\n{cable}cfg_scan_chain\ncfg_assign_file -file {{{bit.as_posix()}}} -device_index 0\ncfg_program -device_index 0\ncfg_read_device_property -device_index 0 -mode 3\nexit\n'
 log=ROOT/'output/reports/model-stage11-jtag-download.log'
 started=datetime.datetime.now(datetime.timezone.utc).isoformat()
 report_path=ROOT/'output/reports/model-stage11-jtag-download.json'
 report_path.write_text(json.dumps(dict(sha256=sha,started_utc=started,phase='connecting',
  program_passed=False,download_performed_by_tool=False,Flash_written=False),indent=2)+'\n','utf-8')
 error=None;returncode=None
 # PDS may spawn its JTAG server with inherited stdout. A real log file avoids
 # waiting forever for that server to close an inherited subprocess PIPE.
 with log.open('wb') as output:
  try:
   r=subprocess.run([args.cfg_shell],input=script.encode('utf-8'),stdout=output,stderr=subprocess.STDOUT,
    timeout=90,creationflags=subprocess.CREATE_NO_WINDOW)
   returncode=r.returncode
  except (OSError,subprocess.TimeoutExpired) as e:error=repr(e)
 raw=log.read_bytes();t=raw.decode('utf-8','replace')
 passed=error is None and returncode==0 and not re.search(r'^E:',t,re.M) and 'Executing : cfg_program -device_index 0 successfully.' in t and re.search(r'Bit 12:\s+1\s+done',t) is not None
 report_path.write_text(json.dumps(dict(sha256=sha,phase='complete' if passed else 'failed',
  program_passed=passed,download_performed_by_tool=passed,Flash_written=False,
  started_utc=started,finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
  requested_TCK_MHz=args.tck_mhz,
  returncode=returncode,error=error,log_sha256=hashlib.sha256(raw).hexdigest()),indent=2)+'\n','utf-8')
 print(t[-2200:]);assert passed,'MOD11 JTAG failed; see report';print('MOD11 JTAG loaded',sha)
if __name__=='__main__':main()
