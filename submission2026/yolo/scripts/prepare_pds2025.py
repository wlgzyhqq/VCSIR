"""Keep identical frozen32 RTL; only the CAD version and work directory change."""
from pathlib import Path
import json,hashlib,re,shutil
R=Path(__file__).resolve().parents[1];old=R/'cnn32-build';D=R/'pds2025-cnn32';D.mkdir(exist_ok=True)
assert not (old/'active.json').exists() and not (D/'active.json').exists()
meta=json.loads((old/'inputs.json').read_text());sources={}
for path,digest in meta['sources'].items():
    p=Path(path);assert hashlib.sha256(p.read_bytes()).hexdigest()==digest,('Old snapshot changed',p)
    if p.is_relative_to(old/'rtl'):
        new=D/p.relative_to(old);new.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,new);sources[str(new)]=digest
    else:sources[path]=digest
project=(old/'final_yolo_cnn.pds').read_text()
# The2022 GUI also saves source paths relative to its project directory.
project=project.replace('(_file "source/','(_file "'+(old/'source').as_posix()+'/')
# Saved PDS projects expand generated DB/netlist paths to absolute paths.
# Keep source/ references byte-identical; redirect every other old output path.
project=re.sub(re.escape(old.as_posix()+'/')+r'(?!source/)',lambda _:D.as_posix()+'/',project)
# Fresh physical outputs; force all project commands to be recalculated.
project=re.sub(r'\(_gci_state \(_integer \d+\)\)','(_gci_state (_integer 0))',project)
(D/'final_yolo_cnn.pds').write_text(project)
meta.update(project=str(D/'final_yolo_cnn.pds'),sources=sources,baseline_project=str(old/'final_yolo_cnn.pds'),baseline_report='output/reports/cnn32/build.json',identical_RTL_to_2022=True)
(D/'inputs.json').write_text(json.dumps(meta,indent=2)+'\n')
print('PDS2025 project prepared:',len(sources),'checksummed inputs; frozen RTL unchanged')
