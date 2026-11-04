"""Isolated synthesis resource precheck, NOT a board bitstream or final STA."""
from pathlib import Path
import hashlib,json,subprocess,shutil,re,datetime
R=Path(__file__).resolve().parents[1];O=R/'output/cnn-unit';O.mkdir(exist_ok=True);S=O/'source';S.mkdir(exist_ok=True)
files=['yolo_cnn.v','yolo_conv.v','yolo_mac64.v','yolo_requant.v'];report={'kind':'isolated synthesis only; not SoC timing/board evidence','source_sha256':{}}
for n in files:
    shutil.copy2(R/'rtl'/n,S/n);report['source_sha256'][n]=hashlib.sha256((S/n).read_bytes()).hexdigest()
def replace_expr(text,needle,replacement):
    begin=text.index(needle);depth=0;quoted=False
    for end in range(begin,len(text)):
        char=text[end]
        if char=='"':quoted=not quoted
        elif not quoted:
            if char=='(':depth+=1
            elif char==')':
                depth-=1
                if depth==0:return text[:begin]+replacement+text[end+1:]
    raise ValueError(needle)
project=(R/'final_yolo.pds').read_text()
source='(_widget wgt_my_design_src (_input\n'+''.join('(_file "'+(S/n).as_posix()+'"'+(' + "yolo_cnn"' if n=='yolo_cnn.v' else '')+' (_format verilog) (_timespec "2026-11-01T19:00:00"))\n' for n in files)+'))'
project=replace_expr(project,'(_widget wgt_my_design_src',source)
fdc=O/'unit.fdc';fdc.write_text('create_clock -name cpu -period 20 [get_ports {clk}]\ncreate_clock -name ui -period 10 [get_ports {ui_clk}]\n')
project=replace_expr(project,'(_widget wgt_import_logic_con_file','(_widget wgt_import_logic_con_file (_input (_file "'+fdc.as_posix()+'" (_format fdc) (_timespec "2026-11-01T19:00:00"))))')
project=project.replace('final_top','yolo_cnn');(O/'cnn.pds').write_text(project)
report['started']=datetime.datetime.now().isoformat();(O/'result.json').write_text(json.dumps(report,indent=2)+'\n')
with (O/'pds.log').open('wb') as out:
    p=subprocess.Popen(['D:/pango/PDS_2022.2-SP1-Lite/bin/pds_shell.exe','-project','cnn.pds','-run','synthesize'],cwd=O,stdout=out,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    print('CNN_UNIT_SYNTH_PID='+str(p.pid),flush=True);report['exit_code']=p.wait()
text=(O/'pds.log').read_text(errors='replace');report['tool_errors']=re.findall(r'^E:.*$',text,re.M)
report['finished']=datetime.datetime.now().isoformat();report['passed']=report['exit_code']==0 and not report['tool_errors'] and 'successfully synthesized' in text
(O/'result.json').write_text(json.dumps(report,indent=2)+'\n');print('Isolated CNN synthesis passed',report['passed'],flush=True)
