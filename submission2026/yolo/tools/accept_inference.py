"""Configure qualified CNN, temporarily load firmware (not answers), check board
inference against PC references. TF/Flash are read-only throughout this tool.
"""
from pathlib import Path
import argparse,json,hashlib,re,subprocess,time,struct,zlib,datetime
from board_uart import BoardUART
R=Path(__file__).resolve().parents[1];O=R/'output/reports/inference';O.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def values(line):return [int(x,16) for x in line.split()[1:]]
def signed(x):return x-(1<<32) if x&(1<<31) else x
def main(port,images,build_tag,tf_boot=False,output_dir=None,cfg_tool='D:/pango/PDS_2025.2-ads/bin/cdt_cfg_shell.exe'):
    global O
    O=Path(output_dir).resolve() if output_dir else R/'output/reports'/('inference-'+build_tag+('-tfboot' if tf_boot else ''));O.mkdir(parents=True,exist_ok=True)
    if output_dir:assert not (O/'board.json').exists(),'Use a fresh evidence directory'
    build=json.loads((R/'output/reports'/build_tag/'build.json').read_text());assert build.get('timing_qualified') and build.get('exit_code')==0
    bit=R/build['bitstream'];assert sha(bit)==build['bitstream_sha256']
    for p,h in build['source_sha256'].items():assert sha(p)==h,('CNN build input changed',p)
    fw=R/'output/inference-fw/demo.bin';firmware=json.loads((fw.parent/'firmware.json').read_text());assert sha(fw)==firmware['sha256']
    for p,h in firmware['sources'].items():assert sha(R/p)==h,('Firmware source changed',p)
    payload=fw.read_bytes();assert 0<len(payload)<=0x1e000 and len(payload)%4==0
    refs=json.loads((R/'model/golden-rgb565/manifest.json').read_text());model=json.loads((R/'model/quantized/model.json').read_text())
    report=dict(started=datetime.datetime.now().isoformat(),bitstream_sha256=sha(bit),firmware_sha256=sha(fw),
                TF_written=False,Flash_written=False,firmware_via_volatile_UART=not tf_boot,FPGA_configuration_source='JTAG volatile',passed=False,images=[])
    def save(uart):
        (O/'board-uart.log').write_bytes(uart.raw);(O/'board.json').write_text(json.dumps(report,indent=2)+'\n')
    with BoardUART(port,hold_boot=not tf_boot) as uart:
        try:
            cmd=f'cfg_set_tcl_break -flag true\ncfg_connect -ip 127.0.0.1 -port 65420\ncfg_scan_chain\ncfg_assign_file -file {{{bit.as_posix()}}} -device_index 0\ncfg_program -device_index 0\ncfg_read_device_property -device_index 0 -mode 3\nexit\n'
            with (O/'jtag.log').open('wb') as out:
                p=subprocess.run([cfg_tool],input=cmd.encode(),stdout=out,stderr=subprocess.STDOUT,timeout=90,creationflags=subprocess.CREATE_NO_WINDOW)
            text=(O/'jtag.log').read_text(errors='replace')
            assert p.returncode==0 and not re.search(r'^E:',text,re.M) and 'Executing : cfg_program -device_index 0 successfully.' in text and re.search(r'Bit 12:\s+1\s+done',text),text[-1800:]
            report['JTAG_programmed']=True;save(uart)
            if tf_boot:
                assert values(uart.wait('@BOOT0_FW_BYTES ',30))==[len(payload)]
                assert values(uart.wait('@BOOT0_CRC ',5))==[zlib.crc32(payload)]
                uart.wait('@BOOT0_VERIFIED',10)
                report['TF_firmware_header_and_DDR_CRC_verified']=True
            else:
                uart.wait('@BOOT0_HELD',10)
                uart.send(b'u'+struct.pack('<II',len(payload),zlib.crc32(payload)));uart.wait('@BOOT0_UART_READY',5)
                for offset in range(0,len(payload),1024):uart.send(payload[offset:offset+1024])
                uart.wait('@BOOT0_UART_VERIFIED',30)
            hardware=values(uart.wait('@YOLO_HW ',30));assert hardware==[90000000,90000000,64],hardware
            report['hardware_CPU_CNN_Hz_and_PEs']=hardware
            uart.wait('@YOLO_READY',180)
            # the board autoplays video after boot; stop it so the deterministic
            # still-image checks below run against a known state
            deadline=time.monotonic()+30
            stopped=False
            while time.monotonic()<deadline and not stopped:
                uart.send(b'x')
                try:
                    uart.wait('@YOLO_VIDEO_STOP',3)
                    stopped=True
                except TimeoutError:
                    continue
            time.sleep(0.2)
            def info():
                uart.send(b'i\n');v=values(uart.wait('@YOLO_INFO ',10));assert len(v)==11
                assert v[3]==255 and v[4]>=0x1ffff and (v[4]&(v[4]+1))==0 and v[5]==1 and v[8]==0 and v[9]==0 and v[10]==0x59434e31,v
                assert not(v[6]&0x60),v
                return v
            def inference(index,mode):
                end=time.monotonic()+600;prep=None;result=None;boxes=[];layers=[]
                while time.monotonic()<end:
                    try:line=uart.line(min(10,max(.1,end-time.monotonic())))
                    except TimeoutError:
                        save(uart);print('Waiting for board inference; no result claimed',flush=True);continue
                    print(line,flush=True)
                    if line.startswith('@YOLO_PREPARE '):prep=values(line)
                    elif line.startswith('@YOLO_RESULT '):result=values(line)
                    elif line.startswith('@YOLO_BOX '):
                        v=[int(x,16) for x in line.split()[1:8]];boxes.append(dict(index=v[0],label=v[1],score=v[2],xyxy_q4=[signed(x) for x in v[3:7]]))
                    elif line.startswith('@YOLO_LAYER '):layers.append(values(line))
                    elif line.startswith(('@YOLO_INFER_ERROR','@YOLO_PREPARE_ERROR','@YOLO_FATAL')):raise RuntimeError(line)
                    elif line=='@YOLO_RESULT_READY':break
                else:raise TimeoutError('Inference result')
                assert prep is not None and result is not None and len(prep)==5 and len(result)==7
                assert prep[0]==index and prep[1]==mode and result[0]==index and result[5]==mode
                expected=next(i for i in refs['images'] if i['index']==index);remaining=list(expected['detections'])
                row=dict(index=index,mode=mode,prepare_ticks=prep[2],input_crc32=f'{prep[3]:08x}',
                         network_ticks=result[1]+(result[2]<<32),decode_ticks=result[3],CPU_clock_Hz=90000000,boxes=boxes,layers=layers,passed=False)
                report['images'].append(row);save(uart)
                assert result[4]==len(boxes)==len(remaining),(boxes,remaining)
                for b in boxes:
                    choices=[(max(abs(float(x)-y/16) for x,y in zip(e[:4],b['xyxy_q4'])),i,e) for i,e in enumerate(remaining) if int(e[5])==b['label']]
                    assert choices,b;err,i,e=min(choices,key=lambda a:a[0]);assert err<1 and abs(e[4]-b['score']/32768)<.0011,(b,e,err);remaining.pop(i)
                if mode==2:
                    byid={t['id']:t for t in expected['tensors']};assert prep[3]==int(byid[0]['crc32'],16)
                    assert len(layers)==85
                    for pos,(ident,ticks,crc) in enumerate(layers):
                        assert ident==pos+1 and crc==int(byid[ident]['crc32'],16),('First differing layer',ident,model['nodes'][ident-1]['op'],f'{crc:08x}',byid[ident]['crc32'])
                row['prepare_seconds']=row['prepare_ticks']/9e7;row['network_seconds']=row['network_ticks']/9e7;row['decode_seconds']=row['decode_ticks']/9e7;row['passed']=True;save(uart)
                return row
            # Firmware auto-generates first result directly from real RGB565.
            uart.send(b'g\n');inference(0,0);report['initial_video']=info();save(uart)
            uart.send(b'w\n');inference(0,2);report['verified_video']=info();save(uart)
            for index in range(1,images):
                uart.send(f's{index:x}\n'.encode());inference(index,0);report['last_video']=info();save(uart)
            report['passed']=True;report['HDMI_visual_confirmation']='pending user confirmation';save(uart)
            print('PASS board CPU preprocessing, all85 layer CRCs, integer decoding, and real image detections; '+('main firmware loaded from TF, FPGA configured via JTAG.' if tf_boot else 'not a standalone TF firmware boot yet.'),flush=True)
        except BaseException as e:report['error']=repr(e);raise
        finally:report['finished']=datetime.datetime.now().isoformat();save(uart)
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--build-tag',default='cnn6490r3');ap.add_argument('--tf-boot',action='store_true');ap.add_argument('--port',default='COM12');ap.add_argument('--output-dir');ap.add_argument('--cfg-tool',default='D:/pango/PDS_2025.2-ads/bin/cdt_cfg_shell.exe');ap.add_argument('--images',type=int,default=8,choices=range(1,9));a=ap.parse_args();main(a.port,a.images,a.build_tag,a.tf_boot,a.output_dir,a.cfg_tool)
