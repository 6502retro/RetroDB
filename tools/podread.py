"""Read a file out of a ProDOS-order disk image: podread.py IMAGE NAME OUT"""
import sys
d = open(sys.argv[1], 'rb').read()
B = lambda n: d[n*512:(n+1)*512]
def entries():
    b = 2
    while b:
        blk = B(b)
        for i in range(13):
            e = blk[4+i*39:4+i*39+39]
            if e[0] >> 4 in (1, 2, 3):
                yield e
        b = blk[2] | blk[3] << 8
def read(e):
    st, key = e[0] >> 4, e[17] | e[18] << 8
    eof = e[21] | e[22] << 8 | e[23] << 16
    def sap(k):
        ix = B(k); return b''.join(B(ix[i] | ix[256+i] << 8) if ix[i] | ix[256+i] else bytes(512) for i in range(256))
    if st == 1: data = B(key)
    elif st == 2: data = sap(key)
    else:
        mx = B(key); data = b''.join(sap(mx[i] | mx[256+i] << 8) if mx[i] | mx[256+i] else bytes(512 * 256) for i in range(128))
    return data[:eof], e[16]
for e in entries():
    name = e[1:1+(e[0] & 15)].decode()
    if len(sys.argv) < 3: print(name, hex(e[16]))
    elif name == sys.argv[2]:
        data, t = read(e); open(sys.argv[3], 'wb').write(data); print(name, hex(t), len(data))
