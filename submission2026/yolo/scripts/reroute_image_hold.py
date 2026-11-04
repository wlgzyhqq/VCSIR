"""Only increase physical hold-repair targets; never relax clock constraints."""
from pathlib import Path
import re,json,argparse
ap=argparse.ArgumentParser();ap.add_argument('--seed',type=int);ap.add_argument('--hold-target',type=int,default=300);ap.add_argument('--cross',type=int,default=600);a=ap.parse_args()
R=Path(__file__).resolve().parents[1];P=R/'final_yolo.pds'
b=json.loads((R/'output/reports/build.json').read_text());assert 'finished_at' in b
s=P.read_text()
def edit_command(text,name,hold=False):
    begin=text.index('(_command '+name);depth=0;quoted=False
    for end in range(begin,len(text)):
        c=text[end]
        if c=='"':quoted=not quoted
        elif not quoted:
            if c=='(':depth+=1
            elif c==')':
                depth-=1
                if depth==0:break
    block=text[begin:end+1]
    block,count=re.subn(r'\(_gci_state \(_integer \d+\)\)','(_gci_state (_integer 0))',block);assert count==1
    if hold:
        for key,value in [('fix_hold_violation_threshold',a.hold_target),('fix_hold_violation_threshold_for_clock_path_cross_srb',a.cross),('fix_hold_violation_threshold_for_clk_tree',200)]:
            block,count=re.subn(r'\(_option '+key+r' \(_integer \d+\)\)',f'(_option {key} (_integer {value}))',block);assert count==1
        if a.seed is not None:block=re.sub(r'\(_option gplace_seed \(_integer \d+\)\)',f'(_option gplace_seed (_integer {a.seed}))',block)
    return text[:begin]+block+text[end+1:]
for name in ['cmd_pnr','cmd_report_post_pnr_timing','cmd_report_power','cmd_gen_netlist','cmd_gen_bitstream']:
    s=edit_command(s,name,name=='cmd_pnr')
P.write_text(s);print('Image project physical targets',a.hold_target,a.cross,200,'seed',a.seed,'same clocks, RTL and physical card')
