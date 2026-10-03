"""Import the board's Lite DDR3 package locally; do not change PDS installation."""
from pathlib import Path
import hashlib, struct, shutil, xml.etree.ElementTree as ET
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
target=root/'ipcore/ddr3_test';target.mkdir(parents=True,exist_ok=True)
for name in ['ddr3_test.idf','ddr3_test.v','ddr3_test_ddrphy_top.v']:
 shutil.copy2(ref/name,target/name)
# Generated IDF already describes PGL50H/FBG484, 32-bit/4Gbit x16 devices.
idf=ET.parse(target/'ddr3_test.idf')
params={e.findtext('name'):e.find('value') for e in idf.findall('./param_list/param')}
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
