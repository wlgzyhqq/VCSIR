"""Bind the completed r4 bit to an explicitly UNQUALIFIED functional debug bundle."""
from pathlib import Path
import json,hashlib,shutil,datetime
R=Path(__file__).resolve().parents[1];D=R/'output/reports/image-r4';D.mkdir(exist_ok=True)
b=json.loads((R/'output/reports/build.json').read_text());assert b['exit_code']==0 and b['timing_qualified'] is False
bit=R/'generate_bitstream/final_top.sbit';assert bit.stat().st_mtime>=datetime.datetime.fromisoformat(b['started_at']).timestamp()
for p,h in b['source_sha256'].items():
    if p!='final_yolo.pds':assert hashlib.sha256((R/p).read_bytes()).hexdigest()==h
for p in ['report_timing/final_top.rtr','rtl/yolo_video.v','rtl/yolo_ddr_arbiter.v','constraints/mes50hp_hdmi.fdc','final_yolo.pds']:
    shutil.copy2(R/p,D/Path(p).name)
dest=R/'output/diagnostic/image-r4.sbit';dest.parent.mkdir(exist_ok=True);shutil.copy2(bit,dest)
b.update(diagnostic_only=True,bitstream='output/diagnostic/image-r4.sbit',bitstream_sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),note='Not final timing acceptance: internal DDR hold slacks -0.004/-0.001ns. Volatile functional bring-up only.')
(D/'build.json').write_text(json.dumps(b,indent=2)+'\n');print('Diagnostic r4 SHA256',b['bitstream_sha256'])
