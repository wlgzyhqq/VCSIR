"""Rerun a frozen, timing-qualified CPU image; save original UART evidence.

Only volatile JTAG configuration is used. TF and QSPI Flash are never written.
"""
from pathlib import Path
import argparse, datetime, hashlib, importlib.util, json, re, subprocess, time

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--project',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--port',default='COM12')
    ap.add_argument('--repeat',type=int,default=3)
    ap.add_argument('--cfg',default='D:/pango/PDS_2025.2-ads/bin/cdt_cfg_shell.exe')
    args=ap.parse_args()
    root=args.project.resolve(); out=args.output.resolve()
    out.mkdir(parents=True,exist_ok=True)
    assert not (out/'summary.json').exists(),'Use a fresh output folder'
    build=json.loads((root/'output/reports/cpu-only-build.json').read_text(encoding='utf-8'))
    assert build['exit_code']==0 and build['timing_qualified']
    timing=root/'report_timing/cpu_bench_top.rtr'
    assert 'All Constraints Met' in timing.read_text() and 'multi corner' in timing.read_text()
    for name,digest in build['source_sha256'].items():
        if name!='cpu_bench.pds':assert sha(root/name)==digest,name
    bit=root/'output/bitstream/cpu_only_90MHz_verified.sbit'
    assert sha(bit)=='d9737ea9df4cb56620d413a5af22e38f860020a9bd2d5a8aa055f6562261ccce'
    spec=importlib.util.spec_from_file_location('serial_transport',root/'scripts/serial_transport.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    report={'started':datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),
      'passed':False,'bitstream_sha256':sha(bit),'timing_sha256':sha(timing),
      'CPU_Hz':90000000,'timer_Hz':90000000,'CPU_includes_cache':True,
      'AI':False,'DDR':False,'SD':False,'HDMI':False,
      'minimal_UART_GPIO_and_program_RAM_present':True,
      'Flash_written':False,'TF_written':False,'JTAG_tool':args.cfg,'port':args.port,'runs':[]}
    def save(): (out/'summary.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    save()
    for run in range(args.repeat):
        name=f'run-{run+1:02d}'; raw=bytearray(); stamps=[]
        serial=module.Serial(args.port)
        try:
            serial.read()
            script='cfg_set_tcl_break -flag true\ncfg_connect -ip 127.0.0.1 -port 65420\ncfg_scan_chain\n'
            script+=f'cfg_assign_file -file {{{bit.as_posix()}}} -device_index 0\ncfg_program -device_index 0\ncfg_read_device_property -device_index 0 -mode 3\nexit\n'
            (out/f'{name}.tcl').write_text(script,encoding='utf-8')
            print(f'[{name}] Programming frozen CPU-only90 image {sha(bit)[:12]}',flush=True)
            with (out/f'{name}-jtag.log').open('wb') as log:
                proc=subprocess.run([args.cfg],input=script.encode(),stdout=log,stderr=subprocess.STDOUT,timeout=65,creationflags=subprocess.CREATE_NO_WINDOW)
            log=(out/f'{name}-jtag.log').read_text(errors='replace')
            assert proc.returncode==0 and not re.search(r'^E:',log,re.M) and re.search(r'Bit 12:\s+1\s+done',log),log[-1800:]
            end=time.monotonic()+90
            while time.monotonic()<end:
                part=serial.read()
                if part:
                    raw.extend(part);print(part.decode('ascii','replace'),end='',flush=True)
                    n=len(re.findall(rb'@CM_RAW [0-9a-f ]+\r',raw))
                    while len(stamps)<n:stamps.append(time.monotonic())
                if b'@CPU_ONLY PASS' in raw or b'@CPU_ONLY FAIL' in raw:break
                time.sleep(0.005)
        finally:
            serial.close();(out/f'{name}-uart.log').write_bytes(raw)
        text=raw.decode('ascii','replace')
        fields=[[int(v,16) for v in m.split()] for m in re.findall(r'@CM_RAW ([0-9a-f ]+)',text)]
        assert len(fields)==2 and '@CPU_ONLY PASS' in text,text[-1200:]
        pairs=[]
        for f in fields:
            assert len(f)==8 and f[0]==1 and f[2:5]==[3000,90000000,90000000] and f[7]==1,f
            cycles=f[5]+(f[6]<<32);seconds=cycles/90000000
            assert seconds>=10
            pairs.append(dict(seed=f[1],iterations=3000,cycles=cycles,seconds=seconds,CoreMark=3000/seconds,CoreMark_per_MHz=3000/seconds/90,CRC_pass=True))
        assert {p['seed'] for p in pairs}=={0,1}
        wall=stamps[1]-stamps[0];ratio=wall/pairs[1]['seconds']
        assert abs(ratio-1)<0.03,(wall,ratio)
        report['runs'].append(dict(index=run+1,passed=True,seeds=pairs,second_run_host_seconds=wall,second_run_host_vs_timer_ratio=ratio,uart_sha256=sha(out/f'{name}-uart.log')))
        save();print(f'\n[{name}] PASS, timer/host cross-check {ratio:.6f}',flush=True)
    report['passed']=True;report['finished']=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat();save()
    print('ALL RUNS PASS. No TF/Flash writes.',flush=True)

if __name__=='__main__':main()
