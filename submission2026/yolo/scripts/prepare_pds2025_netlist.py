"""Feed the verified2022 GTP netlist to2025, avoiding legacy encrypted RTL import."""
from pathlib import Path
import xml.etree.ElementTree as ET,json,hashlib,datetime,argparse
ap=argparse.ArgumentParser();ap.add_argument('--baseline-dir',default='cnn32-build');ap.add_argument('--build-dir',default='pds2025-cnn32-netlist');a=ap.parse_args()
R=Path(__file__).resolve().parents[1];D=R/a.build_dir;assert D.resolve().is_relative_to(R);D.mkdir(exist_ok=True)
assert not (D/'active.json').exists()
net=R/a.baseline_dir/'synthesize/final_top_syn.vm';assert net.is_file()
baseline=R/a.baseline_dir/'source/constraints'
tree=ET.parse(R/'pds2025-cnn32/final_yolo_cnn.pds');root=tree.getroot()
design=root.find(".//action[@name='design']/inputs");assert design is not None;design.clear()
item=ET.SubElement(design,'item',{'type':'FILE','file':net.as_posix(),'format':'verilog','library':'work','timespec':datetime.datetime.fromtimestamp(net.stat().st_mtime).isoformat(timespec='seconds')})
opts=ET.SubElement(item,'options');ET.SubElement(opts,'option',{'name':'format','type':'string','value':'verilog'});ET.SubElement(opts,'option',{'name':'library','type':'string','value':'work'})
for action in root.findall('.//action'):
    state=action.find('state')
    if state is not None:state.set('value','INIT')
    outputs=action.find('outputs')
    if outputs is not None:outputs.clear()
for inner in root.findall('.//inner'):
    if inner.get('name') in ('start_time','run_time'):inner.set('value','')
sources={str(net):hashlib.sha256(net.read_bytes()).hexdigest()}
migrations=[]
for action in root.findall(".//action[@act_type='widget']"):
    if action.get('name')=='design':continue
    for f in action.findall('./inputs/item'):
        if f.get('type')=='FILE' and f.get('format')=='fdc':
            p=baseline/Path(f.get('file')).name
            if p.name=='cnn.fdc' and (baseline/'cnn90.fdc').is_file():p=baseline/'cnn90.fdc'
            elif p.name=='cnn.fdc' and (baseline.parent/'rtl/yolo_burst_cdc.v').is_file():p=R/'constraints/cnn90.fdc'
            assert p.is_file(),p;dest=D/'constraints'/p.name;dest.parent.mkdir(exist_ok=True)
            content=p.read_text()
            if p.name=='mes50hp_ddr3.fdc':
                old='i:u_ddr.u_ddrphy_top.ddrphy_reset_ctrl.ddrphy_ioclk_gate}'
                new='i:u_ddr.u_ddrphy_top.ddrphy_reset_ctrl.ddrphy_ioclk_gate_vname}'
                assert content.count(old)==1;content=content.replace(old,new)
                migrations.append(dict(file=p.name,old_object=old,new_object=new,reason='Actual primitive instance name in exported GTP netlist',PAP_LOC_unchanged='CLMA_150_192:FF3',timing_requirements_changed=False))
            dest.write_text(content);f.set('file',dest.as_posix());sources[str(dest)]=hashlib.sha256(dest.read_bytes()).hexdigest()
for action in root.findall(".//action[@act_type='widget']"):
    inputs=action.find('inputs')
    if inputs is not None:
        for entry in list(inputs):
            if Path(entry.get('file','')).name=='cnn90.fdc':inputs.remove(entry);inputs.append(entry)
ET.indent(tree,space='    ');project=D/'final_top_netlist.pds';tree.write(project,encoding='UTF-8',xml_declaration=True)
meta=dict(project=str(project),sources=sources,RTL_baseline=a.baseline_dir+'/source',logic_synthesis='2022.2-SP1-Lite',physical_tools='2025.2-ads',netlist=str(net),netlist_sha256=sources[str(net)],constraint_migrations=migrations,board_verified=False)
(D/'inputs.json').write_text(json.dumps(meta,indent=2)+'\n');print('Prepared2025 structural netlist flow:',len(sources),'inputs; no DDR RTL changes')
