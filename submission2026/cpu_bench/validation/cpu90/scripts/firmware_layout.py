"""Validate actual ELF32 BSS bounds against startup's word-clear loop."""
import struct
def check_layout(path):
    data=path.read_bytes()
    assert data[:6]==b'\x7fELF\x01\x01', 'Expected little-endian ELF32'
    shoff=struct.unpack_from('<I',data,32)[0]
    entry_size,count,names_index=struct.unpack_from('<HHH',data,46)
    sections=[struct.unpack_from('<10I',data,shoff+i*entry_size) for i in range(count)]
    def payload(s): return data[s[4]:s[4]+s[5]]
    def name(strings,index): return strings[index:strings.index(b'\0',index)].decode('ascii')
    strings=payload(sections[names_index]);by_name={name(strings,s[0]):s for s in sections}
    symbols={}
    for s in sections:
        if s[1]!=2: continue
        names=payload(sections[s[6]])
        for offset in range(s[4],s[4]+s[5],s[9]):
            index,value,_,_,_,_=struct.unpack_from('<IIIBBH',data,offset)
            symbols[name(names,index)]=value
    bss=by_name['.bss'];start,end=symbols['__bss_start'],symbols['__bss_end']
    assert start==bss[3] and end==bss[3]+bss[5], 'Startup does not clear the entire actual .bss section'
    assert start%4==0 and end%4==0 and start<=end<symbols['__bss_limit'], 'BSS alignment/capacity invalid'
    assert symbols['__stack']==0x1ff00
    return dict(bss_start=start,bss_end=end,bss_bytes=end-start,stack_top=symbols['__stack'])
