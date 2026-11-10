import struct,sys
def newc(name,data,mode):
    n=name.encode()+b'\0'
    h='070701'+''.join('%08X'%v for v in [1,mode,0,0,1,0,len(data),0,0,0,0,len(n),0])
    b=h.encode()+n; b+=b'\0'*((-len(b))%4); b+=data; b+=b'\0'*((-len(b))%4); return b
key=open(sys.argv[1],'rb').read()
cp=newc('adb_keys',key,0o100644)+newc('TRAILER!!!',b'',0)
cp+=b'\0'*((-len(cp))%512)
# LZ4 legacy: magic + [blocksize + block]; literal-only block
L=len(cp); blk=bytes([0xF0])+b'\xff'*((L-15)//255)+bytes([(L-15)%255])+cp
open(sys.argv[2],'wb').write(struct.pack('<I',0x184C2102)+struct.pack('<I',len(blk))+blk)
