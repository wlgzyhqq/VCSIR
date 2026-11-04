"""Exact graph/storage counts and arithmetic upper bounds, never measured FPS."""
from pathlib import Path
import json,math
R=Path(__file__).resolve().parents[1];m=json.loads((R/'model/quantized/model.json').read_text())
rows=[]
for n in m['nodes']:
    if n['op']!='conv':continue
    c,h,w=n['shape'];k=n['cin']*n['kernel']**2;spatial=h*math.ceil(w/8);groups=[min(8,c-start) for start in range(0,c,8)];phases=sum(math.ceil(count/8) for count in groups)
    rows.append(dict(id=n['id'],useful_MACs=c*h*w*k,issued_lane_MACs=spatial*phases*64*k,tiles=spatial*len(groups),
                     dot_control_cycles=spatial*phases*k*3,quantization_control_cycles=spatial*c*8*8))
useful=sum(x['useful_MACs'] for x in rows);issued=sum(x['issued_lane_MACs'] for x in rows)
report=dict(useful_MACs=useful,issued_MACs_including_padding=issued,lane_utilization=useful/issued,
            array_multipliers=64,compute_design_clock_Hz=90000000,DDR_design_clock_Hz=100000000,array_physical_peak_MACs_per_second=5760000000,
            current_dot_FSM_cycles_per_product_step=3,current_dot_FSM_max_MACs_per_second=5760000000/3,
            mandatory_dot_and_quant_control_cycles=sum(x['dot_control_cycles']+x['quantization_control_cycles'] for x in rows),
            tensor_bytes=sum(n['bytes'] for n in m['nodes']),tensor_region_end=max(n['address']+n['bytes'] for n in m['nodes']),
            weights_bytes=m['weights_bytes'],layers=rows,
            note='Counts and lower bound only: excludes DDR requests/stalls, weight loading, tile setup/output writes, CPU ops, decoding and UI. Not measured speed; no FPS prediction.')
(R/'output/reports/work-counts.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='layers'},indent=2))
