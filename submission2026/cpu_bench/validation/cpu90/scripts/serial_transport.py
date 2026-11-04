"""Windows serial sender and UART3 board acceptance tool, standard library only.

Opening disables flow control, makes no explicit DTR/RTS pulse, and never
programs FPGA/Flash. UART3 must already be loaded. The verify command deliberately overloads RX during @PAUSE and
sends a short BREAK to verify framing-error reporting.
"""
import argparse,ctypes as C,json,os,time,zlib,hashlib
from ctypes import wintypes as W
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

class DCB(C.Structure):
    _fields_=[('DCBlength',W.DWORD),('BaudRate',W.DWORD),('flags',W.DWORD),
              ('wReserved',W.WORD),('XonLim',W.WORD),('XoffLim',W.WORD),
              ('ByteSize',W.BYTE),('Parity',W.BYTE),('StopBits',W.BYTE),
              ('XonChar',C.c_char),('XoffChar',C.c_char),('ErrorChar',C.c_char),
              ('EofChar',C.c_char),('EvtChar',C.c_char),('wReserved1',W.WORD)]
class Timeouts(C.Structure):
    _fields_=[(k,W.DWORD) for k in ['ReadIntervalTimeout','ReadTotalTimeoutMultiplier',
                                    'ReadTotalTimeoutConstant','WriteTotalTimeoutMultiplier','WriteTotalTimeoutConstant']]

class Serial:
    def __init__(self,port):
        if os.name!='nt': raise RuntimeError('This transport uses Windows serial APIs')
        self.k=C.WinDLL('kernel32',use_last_error=True)
        signatures={
          'CreateFileW':([W.LPCWSTR,W.DWORD,W.DWORD,W.LPVOID,W.DWORD,W.DWORD,W.HANDLE],W.HANDLE),
          'CloseHandle':([W.HANDLE],W.BOOL),'GetCommState':([W.HANDLE,C.POINTER(DCB)],W.BOOL),
          'SetCommState':([W.HANDLE,C.POINTER(DCB)],W.BOOL),'SetupComm':([W.HANDLE,W.DWORD,W.DWORD],W.BOOL),
          'SetCommTimeouts':([W.HANDLE,C.POINTER(Timeouts)],W.BOOL),
          'ReadFile':([W.HANDLE,W.LPVOID,W.DWORD,C.POINTER(W.DWORD),W.LPVOID],W.BOOL),
          'WriteFile':([W.HANDLE,W.LPCVOID,W.DWORD,C.POINTER(W.DWORD),W.LPVOID],W.BOOL),
          'SetCommBreak':([W.HANDLE],W.BOOL),'ClearCommBreak':([W.HANDLE],W.BOOL)}
        for name,(args,ret) in signatures.items():
            f=getattr(self.k,name);f.argtypes=args;f.restype=ret
        self.h=self.k.CreateFileW('\\\\.\\'+port,0xc0000000,0,None,3,0,None)
        if self.h==C.c_void_p(-1).value: raise C.WinError(C.get_last_error())
        try:
            d=DCB();d.DCBlength=C.sizeof(DCB);self.ok(self.k.GetCommState(self.h,C.byref(d)))
            d.BaudRate=115200;d.flags=1;d.ByteSize=8;d.Parity=0;d.StopBits=0
            self.ok(self.k.SetCommState(self.h,C.byref(d)))
            self.ok(self.k.SetupComm(self.h,65536,65536))
            t=Timeouts(0xffffffff,0,30,1,10000);self.ok(self.k.SetCommTimeouts(self.h,C.byref(t)))
        except BaseException: self.close();raise
    def ok(self,r):
        if not r: raise C.WinError(C.get_last_error())
    def write(self,data):
        b=C.create_string_buffer(data);n=W.DWORD()
        self.ok(self.k.WriteFile(self.h,b,len(data),C.byref(n),None))
        if n.value!=len(data): raise IOError(f'Short serial write {n.value}/{len(data)}')
    def read(self):
        b=C.create_string_buffer(4096);n=W.DWORD()
        self.ok(self.k.ReadFile(self.h,b,len(b),C.byref(n),None));return b.raw[:n.value]
    def break_signal(self):
        self.ok(self.k.SetCommBreak(self.h))
        try: time.sleep(.02)
        finally: self.ok(self.k.ClearCommBreak(self.h))
    def close(self):
        if getattr(self,'h',None) not in (None,C.c_void_p(-1).value): self.k.CloseHandle(self.h);self.h=None
    def __enter__(self): return self
    def __exit__(self,*a): self.close()

