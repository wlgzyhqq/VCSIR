"""Static project checks only. Does not simulate CPU/DDR behavior."""
from pathlib import Path
import re, struct
root=Path(__file__).resolve().parent
sources=re.findall(r'_file "([^\"]+)"',(root/'FINAL.pds').read_text())
assert len(sources)==len(set(sources)), 'Duplicate project source'
assert all((root/name).exists() for name in sources), 'Missing project file'
assert any('ipcore/ddr3_test/ddr3_test.v'==name for name in sources)
assert all('backups/' not in name for name in sources)
pins={}
for name in ['mes50hp.fdc','mes50hp_ddr3.fdc']:
 for signal,pin in re.findall(r'define_attribute \{p:([^}]+)\} \{PAP_IO_LOC\} \{([^}]+)\}',(root/'constraints'/name).read_text()):
  assert pin not in pins, (pin,signal,pins.get(pin));pins[pin]=signal
assert len(pins)==88, len(pins)
body=(root/'rtl/final_bus.v').read_text()
assert not re.search(r'\bram\s*\[|\$readmemh',body), 'BRAM main-memory backend remains'
top=(root/'rtl/final_top.v').read_text()
assert 'GTP_CLKBUFG u_cpu_clock' in top
assert '.MEM_CACHE_ADDR_MAX(32\'h3fffffff)' in top
assert '.rst_i(cpu_rst)' in top
image=(root/'build/firmware/demo.bin').read_bytes()
image+=b'\0'*((-len(image))%32)
constants=(root/'firmware/boot_image.vh').read_text()
parsed={int(index):int(value,16).to_bytes(32,'little') for index,value in
 re.findall(r"16'd(\d+):boot_line=256'h([0-9a-f]+)",constants)}
assert b''.join(parsed[i] for i in range(len(parsed)))==image
print(f'STATIC CHECK PASS: {len(sources)} project entries; 88 unique IO pins; DDR3 backend; {len(image)} executable bytes in boot constants.')
print('This does not establish DDR calibration, functional correctness or timing closure.')
