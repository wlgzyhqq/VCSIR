"""Volatile JTAG configuration + TF/photo/UART acceptance. Never writes Flash/TF."""
from pathlib import Path
import subprocess,json,re,hashlib,time,datetime,argparse
from serial_transport import Serial
R=Path(__file__).resolve().parents[1];O=R/'output/reports'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(port,program,diagnostic=False):
    build=json.loads((O/('image-r4/build.json' if diagnostic else 'build.json')).read_text());assert build.get('exit_code')==0
    if diagnostic:assert build.get('diagnostic_only') and not build.get('timing_qualified')
    else:assert build.get('timing_qualified')
    bit=R/(build['bitstream'] if diagnostic else 'output/bitstream/yolo_image_demo.sbit');assert sha(bit)==build['bitstream_sha256']
    tag='image-r4-diagnostic' if diagnostic else 'image'
    for path,h in build['source_sha256'].items():
        if path!='final_yolo.pds':assert sha(R/path)==h,('Input changed since build',path)
    report=dict(started=datetime.datetime.now().isoformat(),bitstream_sha256=sha(bit),
                milestone='TF loading and real HDMI pixels, not inference',port=port,
                Flash_written=False,TF_written=False,programmed=False,passed=False,timing_qualified=build['timing_qualified'],diagnostic_only=diagnostic)
    log=bytearray();pending=bytearray()
    def save():
        (O/(tag+'-board-uart.log')).write_bytes(log)
        (O/(tag+'-board.json')).write_text(json.dumps(report,indent=2)+'\n')
    with Serial(port) as serial:
        def line(timeout=5):
            end=time.monotonic()+timeout
            while time.monotonic()<end:
                if b'\n' in pending:
                    first,_,rest=pending.partition(b'\n');pending[:]=rest
                    return first.decode('ascii','replace').strip()
                chunk=serial.read();log.extend(chunk);pending.extend(chunk)
            raise TimeoutError('UART line timeout; '+repr(bytes(pending[-200:])))
        def wait(prefix,timeout=90):
            end=time.monotonic()+timeout
            while time.monotonic()<end:
                t=line(max(.1,end-time.monotonic()));print(t,flush=True)
                if t.startswith(prefix):return t
            raise TimeoutError(prefix)
        def info():
            serial.write(b'i\n');t=wait('@YOLO_INFO ',5);v=[int(x,16) for x in t.split()[1:]]
            assert len(v)==11 and v[0]==1 and v[1]==8
            return dict(zip(('version','images','index','display_mask','loaded_mask','storage_ok','video_status','frames','underflows','rejected','cnn_id'),v))
        try:
            if program:
                cmd=f'cfg_set_tcl_break -flag true\ncfg_connect -ip 127.0.0.1 -port 65420\ncfg_scan_chain\ncfg_assign_file -file {{{bit.as_posix()}}} -device_index 0\ncfg_program -device_index 0\ncfg_read_device_property -device_index 0 -mode 3\nexit\n'
                with (O/(tag+'-jtag.log')).open('wb') as out:
                    p=subprocess.run(['D:/pango/PDS_2022.2-SP1-Lite/bin/cdt_cfg_shell.exe'],input=cmd.encode(),stdout=out,stderr=subprocess.STDOUT,timeout=90,creationflags=subprocess.CREATE_NO_WINDOW)
                t=(O/(tag+'-jtag.log')).read_text(errors='replace')
                assert p.returncode==0 and not re.search(r'^E:',t,re.M) and 'Executing : cfg_program -device_index 0 successfully.' in t and re.search(r'Bit 12:\s+1\s+done',t),t[-1800:]
                report['programmed']=True;save()
                wait('@YOLO_READY',180)
            before=info();report['before']=before;save()
            assert before['storage_ok']==1 and before['loaded_mask']==0x1ffff and before['display_mask']==255, 'TF assets incomplete'
            switched=[]
            for index in range(8):
                serial.write(f's{index:x}\n'.encode());wait('@YOLO_INFO ',5)
                end=time.monotonic()+1.2
                while time.monotonic()<end:
                    chunk=serial.read();log.extend(chunk);pending.extend(chunk)
                v=info();assert v['index']==index and not(v['video_status']&0x61) and v['frames']>before['frames'],v
                switched.append(v);report['switches']=switched;save()
            after=info();report['after']=after
            assert after['underflows']==0 and after['rejected']==0 and not(after['video_status']&0x61)
            report['functional_passed']=True;report['passed']=not diagnostic;report['HDMI_visual_confirmation']='pending user observation'
            print(('FUNCTIONAL PASS ONLY (diagnostic, timing unqualified): ' if diagnostic else 'PASS ')+ 'TF asset CRCs, 8 image switches, advancing video frames, no reported underflow/error; visual confirmation still required.',flush=True)
        except BaseException as e:
            report['error']=repr(e);raise
        finally:report['finished']=datetime.datetime.now().isoformat();save()
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--port',default='COM12');ap.add_argument('--program',action='store_true');ap.add_argument('--diagnostic',action='store_true');a=ap.parse_args();run(a.port,a.program,a.diagnostic)
