import zipfile,struct,sys,lzma,bz2,subprocess,os,hashlib
zp,out=sys.argv[1],sys.argv[2]; os.makedirs(out,exist_ok=True)
z=zipfile.ZipFile(zp); info=z.getinfo('payload.bin'); assert info.compress_type==0
f=open(zp,'rb'); f.seek(info.header_offset); lh=f.read(30)
base=info.header_offset+30+struct.unpack('<H',lh[26:28])[0]+struct.unpack('<H',lh[28:30])[0]
f.seek(base); h=f.read(24); assert h[:4]==b'CrAU'
ver,msize=struct.unpack('>QQ',h[4:20]); sigsize=struct.unpack('>I',h[20:24])[0]
m=f.read(msize); data_off=base+24+msize+sigsize
def varint(b,i):
    r=s=0
    while True:
        c=b[i];i+=1;r|=(c&0x7f)<<s;s+=7
        if c<0x80:return r,i
def fields(b):
    i=0
    while i<len(b):
        k,i=varint(b,i);fn,wt=k>>3,k&7
        if wt==0:v,i=varint(b,i)
        elif wt==2:l,i=varint(b,i);v=b[i:i+l];i+=l
        elif wt==1:v=b[i:i+8];i+=8
        elif wt==5:v=b[i:i+4];i+=4
        yield fn,v
bs=4096
for fn,v in fields(m):
    if fn==3: bs=v
want=set(sys.argv[3:])
for fn,v in fields(m):
    if fn!=13: continue
    name=None;ops=[];size=None
    for f2,v2 in fields(v):
        if f2==1:name=v2.decode()
        elif f2==8:ops.append(v2)
        elif f2==7:
            for f3,v3 in fields(v2):
                if f3==1:size=v3
    if want and name not in want: continue
    o=open(f'{out}/{name}.img','wb')
    for op in ops:
        t=0;doff=0;dlen=0;ext=[]
        for f3,v3 in fields(op):
            if f3==1:t=v3
            elif f3==2:doff=v3
            elif f3==3:dlen=v3
            elif f3==6:
                sb=nb=0
                for f4,v4 in fields(v3):
                    if f4==1:sb=v4
                    elif f4==2:nb=v4
                ext.append((sb,nb))
        f.seek(data_off+doff); d=f.read(dlen)
        if t==0: pass
        elif t==8: d=lzma.decompress(d)
        elif t==1: d=bz2.decompress(d)
        elif t==14: d=subprocess.run(['zstd','-dc'],input=d,capture_output=True,check=True).stdout
        elif t in (6,7): d=None
        else: raise SystemExit(f'{name}: unsupported op {t}')
        pos=0
        for sb,nb in ext:
            o.seek(sb*bs)
            if d is None: o.write(b'\0'*nb*bs)
            else: o.write(d[pos:pos+nb*bs]); pos+=nb*bs
    if size: o.truncate(size)
    o.close(); print(name, os.path.getsize(f'{out}/{name}.img'), flush=True)
