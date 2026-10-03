"""Import the board's Lite DDR3 package locally; do not change PDS installation."""
from pathlib import Path
import hashlib, struct, shutil, subprocess, xml.etree.ElementTree as ET
root=Path(__file__).resolve().parent
source=next(Path('D:/BaiduNetdiskDownload').rglob('ipsxb_hmic_s_v1_4_lite.iar'))
data=source.read_bytes()
assert data[:4]==b'MPK\x01'
offset=struct.unpack_from('>Q',data,27)[0]
files,dirs=struct.unpack_from('>II',data,offset)
pos=offset+16
dest=root/'build/ddr-ip-package'
for _ in range(files+dirs):
 n=struct.unpack_from('>H',data,pos)[0];pos+=2
 name=data[pos:pos+n].decode();pos+=n
 start,size=struct.unpack_from('>QQ',data,pos);pos+=16
 n=struct.unpack_from('>H',data,pos)[0];pos+=2
 digest=data[pos:pos+n];pos+=n
 prefix='../ip/system_ip/'
 assert name.startswith(prefix)
 target=(dest/name[len(prefix):]).resolve()
 assert target.is_relative_to(dest.resolve())
 if not digest:target.mkdir(parents=True,exist_ok=True);continue
 payload=data[start:start+size]
 assert hashlib.md5(payload).digest()==digest, name
 target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(payload)
assert pos==len(data)
ref=root/'build/ddr-reference/07_ddr3_test/ipcore/ddr3_test'
if not ref.exists():
 archive=next(Path('D:/BaiduNetdiskDownload').rglob('07_ddr3_test.rar'))
 parent=root/'build/ddr-reference';parent.mkdir(parents=True,exist_ok=True)
 subprocess.run(['tar','-xf',str(archive),'-C',str(parent)],check=True)
target=root/'ipcore/ddr3_test';target.mkdir(parents=True,exist_ok=True)
for name in ['ddr3_test.idf','ddr3_test.v','ddr3_test_ddrphy_top.v']:
 shutil.copy2(ref/name,target/name)
shutil.copy2(ref/'pnr/ddr_test.fdc',target/'board-ddr3-reference.fdc')
# Generated IDF already describes PGL50H/FBG484, 32-bit/4Gbit x16 devices.
idf=ET.parse(target/'ddr3_test.idf')
params={e.findtext('name'):e.find('value') for e in idf.findall('./param_list/param')}
# Correct saved GUI metadata too: the example's hand-edited FDC is the board
# pin map, while some saved PAD_DQ fields are stale. The active PHY source is
# unchanged; constraints are still independently checked against the manual.
for signal,pin in __import__('re').findall(r'define_attribute \{p:mem_([^}]+)\} \{PAP_IO_LOC\} \{([^}]+)\}',(target/'board-ddr3-reference.fdc').read_text()):
 scalar={'rst_n':'RESET','ck':'CK','ck_n':'CKN','cke':'CKE','cs_n':'CS','ras_n':'RAS','cas_n':'CAS','we_n':'WE','odt':'ODT'}
 if signal in scalar:key='PAD_'+scalar[signal]
 else:
  match=__import__('re').fullmatch(r'(a|ba|dq|dqs|dqs_n|dm)\[(\d+)\]',signal)
  if not match:continue
  key='PAD_'+{'a':'A','ba':'BA','dq':'DQ','dqs':'DQS','dqs_n':'DQSN','dm':'DM'}[match[1]]+match[2]
 if key in params:params[key].text=pin
idf.write(target/'ddr3_test.idf',encoding='UTF-8',xml_declaration=True)
print('Board DDR geometry:', {k:v.text for k,v in params.items() if k in ['MEM_ROW_WIDTH','MEM_COLUMN_WIDTH','MEM_DQ_WIDTH','MEM_CLK_FREQ']})
# Preserve generated board-specific PHY slice and use Lite package source files.
for name in ['rtl','sim_lib']:
 if (ref/name).exists():shutil.copytree(ref/name,target/name,dirs_exist_ok=True)
package=dest/'ipsxb_hmic_s/ipsxb_hmic_eval/ipsxb_hmic_s'
for path in (package/'rtl').rglob('*'):
 if path.is_file():
  to=target/'rtl'/path.relative_to(package/'rtl');to.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,to)
# Restore board-specific generated slice (generic package is a template).
slice_path='rtl/ddrphy/ipsxb_ddrphy_slice_top_v1_4.v'
shutil.copy2(ref/slice_path,target/slice_path)
print(f'Imported {files} Lite package files; IP directory {package}')
