"""Compress the title picture for MOUSEDB.SYSTEM: mklz.py IN OUT

Tokens: t < $80: t+1 literal bytes follow.  t >= $80: copy (t & $7F) + 3
bytes from `offset` bytes back (a 2-byte offset follows, low byte first).
The output is always 8192 bytes, so there is no end marker."""
import sys
d = open(sys.argv[1], 'rb').read()
assert len(d) == 8192
out = bytearray()
lit = bytearray()
def flush():
    global lit, out
    while lit:
        n = min(len(lit), 128)
        out.append(n - 1); out.extend(lit[:n]); lit = lit[n:]
i = 0
while i < len(d):
    best, bo = 0, 0
    for j in range(max(0, i - 8191), i):
        n = 0
        while n < 130 and i + n < len(d) and d[j + n] == d[i + n]:
            n += 1
        if n > best:
            best, bo = n, i - j
    if best >= 3:
        flush()
        out.append(0x80 | (best - 3)); out.append(bo & 255); out.append(bo >> 8)
        i += best
    else:
        lit.append(d[i]); i += 1
flush()
# check by decompressing
o = bytearray(); k = 0
while len(o) < 8192:
    t = out[k]; k += 1
    if t < 0x80:
        o += out[k:k + t + 1]; k += t + 1
    else:
        n = (t & 0x7F) + 3; off = out[k] | out[k + 1] << 8; k += 2
        for _ in range(n): o.append(o[-off])
assert bytes(o) == d and k == len(out)
open(sys.argv[2], 'wb').write(out)
print('splash: 8192 ->', len(out), 'bytes')
