from pathlib import Path
import re
R=Path(__file__).resolve().parents[1]
t=(R/'report_timing/final_top.rtr').read_text(errors='replace')
seen=set()
for b in t.split('Startpoint  : ')[1:]:
    a=b.splitlines()[0];end=re.search(r'Endpoint\s+: (.+)',b);slack=re.search(r'Slack\s*\([^)]*\)\s+(-?[0-9]+\.[0-9]+)',b)
    if not slack or float(slack[1])>=0:continue
    key=(a.split('/opit')[0],end[1].split('/opit')[0])
    if key in seen:continue
    seen.add(key);print(slack[1],a,'->',end[1])
