from pathlib import Path
root=Path(__file__).resolve().parents[1]
needle='`include "'+(root/'rtl/core/riscv_defs.v').as_posix()+'"'
for p in (root/'rtl/core').glob('*.v'):
    s=p.read_text()
    if '`ifdef __ICARUS__' not in s:
        p.write_text(s.replace(needle,'`ifdef __ICARUS__\n`include "riscv_defs.v"\n`else\n'+needle+'\n`endif'))
