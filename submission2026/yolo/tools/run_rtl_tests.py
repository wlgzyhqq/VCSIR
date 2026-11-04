from pathlib import Path
import subprocess,os,json,time,argparse,hashlib,datetime
R=Path(__file__).resolve().parents[1];O=R/'output/rtl-tests';O.mkdir(exist_ok=True)
env=dict(os.environ);env['PATH']='C:/msys64/ucrt64/bin'+os.pathsep+env.get('PATH','')
ap=argparse.ArgumentParser();ap.add_argument('--only',default='');a=ap.parse_args();result=json.loads((O/'results.json').read_text()) if (O/'results.json').exists() else []
for name,files in [('bus',['tools/tb_yolo_bus.v','rtl/final_bus.v','rtl/final_uart.v']),('convcdc',['tools/tb_yolo_conv.v','rtl/yolo_conv.v','rtl/yolo_mac64.v','rtl/yolo_requant.v','rtl/yolo_burst_cdc.v']),('burst',['tools/tb_yolo_burst.v','rtl/yolo_burst_cdc.v']),('cnn',['tools/tb_yolo_cnn.v','rtl/yolo_cnn.v','rtl/yolo_conv.v','rtl/yolo_mac64.v','rtl/yolo_requant.v']),('conv',['tools/tb_yolo_conv.v','rtl/yolo_conv.v','rtl/yolo_mac64.v','rtl/yolo_requant.v']),('math',['tools/tb_yolo_math.v','rtl/yolo_mac64.v','rtl/yolo_requant.v']),('video',['tools/tb_yolo_video.v','rtl/yolo_video.v','rtl/yolo_ddr_arbiter.v','rtl/yolo_burst_cdc.v','rtl/final_ascii_font.v']),('arbiter',['tools/tb_yolo_arbiter.v','rtl/yolo_ddr_arbiter.v'])]:
 if a.only and a.only!=name:continue
 image=O/(name+'.vvp');start=time.time()
 row=dict(name=name,status='running',passed=False,started=datetime.datetime.now().isoformat(),source_sha256={p:hashlib.sha256((R/p).read_bytes()).hexdigest() for p in files})
 result=[r for r in result if r['name']!=name];result.append(row)
 (O/'results.json').write_text(json.dumps(result,indent=2)+'\n')
 try:
  flags=['-DYOLO_CDC_TEST'] if name=='convcdc' else []
  subprocess.run(['C:/msys64/ucrt64/bin/iverilog.exe','-g2012',*flags,'-s','tb_yolo_'+('conv' if name=='convcdc' else name),'-o',str(image),*files],cwd=R,env=env,check=True)
  with (O/(name+'.log')).open('wb') as output:
   p=subprocess.run(['C:/msys64/ucrt64/bin/vvp.exe',str(image)],cwd=R,env=env,stdout=output,stderr=subprocess.STDOUT,timeout=2400 if name=='convcdc' else 300)
  text=(O/(name+'.log')).read_text(errors='replace');print(text,flush=True)
  row.update(exit_code=p.returncode,passed=p.returncode==0 and 'PASS ' in text,status='complete')
 except BaseException as e:row.update(error=repr(e),status='failed')
 finally:
  row['seconds']=time.time()-start
  latest=json.loads((O/'results.json').read_text());latest=[r for r in latest if r['name']!=name];latest.append(row)
  (O/'results.json').write_text(json.dumps(latest,indent=2)+'\n')
 assert row['passed'],row
