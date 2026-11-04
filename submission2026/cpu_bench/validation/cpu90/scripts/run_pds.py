"""Run PDS with native file handles for its combined log; no simulation/programming."""
import argparse,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--pds',required=True);p.add_argument('--action',choices=['pnr','gen_bit_stream'],required=True)
a=p.parse_args();(root/'build').mkdir(exist_ok=True)
with (root/'build'/'pds-build.log').open('wb') as log:
    process=subprocess.Popen([a.pds,'-project','final2.pds','-run',a.action],cwd=root,stdout=log,stderr=subprocess.STDOUT,
                          creationflags=subprocess.CREATE_NO_WINDOW)
    print(f'PDS_PARENT_PID={process.pid}',flush=True)
    result=process.wait()
raise SystemExit(result)
