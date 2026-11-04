"""Logged UART reader that can hold stage0 while JTAG programming is returning."""
from serial_transport import Serial
import threading,queue,time
class BoardUART:
    def __init__(self,port,hold_boot=False):
        self.serial=Serial(port);self.hold_boot=hold_boot;self.held_requested=False
        self.lines=queue.Queue();self.raw=bytearray();self.sent=[];self.stop=threading.Event();self.error=None
        self.worker=threading.Thread(target=self.reader,daemon=True);self.worker.start()
    def send(self,data):
        self.serial.write(data);self.sent.append((time.time(),len(data)))
    def reader(self):
        pending=bytearray()
        try:
            while not self.stop.is_set():
                data=self.serial.read();self.raw.extend(data);pending.extend(data)
                while b'\n' in pending:
                    b,_,rest=pending.partition(b'\n');pending[:]=rest;t=b.decode('ascii','replace').strip()
                    if self.hold_boot and not self.held_requested and t.startswith('@BOOT0_READY'):
                        self.send(b'h');self.held_requested=True
                    self.lines.put((time.time(),t))
        except BaseException as e:self.error=repr(e)
    def line(self,timeout=5):
        if self.error:raise RuntimeError(self.error)
        try:return self.lines.get(timeout=timeout)[1]
        except queue.Empty:raise TimeoutError('UART timeout; '+str(self.error))
    def wait(self,prefix,timeout=120):
        end=time.monotonic()+timeout
        while time.monotonic()<end:
            t=self.line(max(.01,end-time.monotonic()));print(t,flush=True)
            if t.startswith(prefix):return t
            if t.startswith(('@BOOT0_ERROR','@BOOT0_UART_ERROR','@YOLO_INFER_ERROR','@YOLO_PREPARE_ERROR','@YOLO_FATAL')):raise RuntimeError(t)
        raise TimeoutError(prefix)
    def close(self):
        self.stop.set();self.worker.join(2);assert not self.worker.is_alive();self.serial.close()
    def __enter__(self):return self
    def __exit__(self,*args):self.close()
