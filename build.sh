#!/bin/sh
# Build RETRODB.SYSTEM from source (needs cc65's ca65 and ld65)
set -e
cd "$(dirname "$0")"
mkdir -p build
[ -f build/splash.bin ] || python3 tools/mksplash.py art/6502retro-logo.png build/splash.bin build/splash.png
[ build/splash.lz -nt build/splash.bin ] || python3 tools/mklz.py build/splash.bin build/splash.lz
python3 tools/ovlcheck.py
ca65 -g -t none -I src -l build/retrodb.lst -o build/retrodb.o src/main.s
ld65 -C src/retrodb.cfg -m build/retrodb.map -Ln build/retrodb.lbl -o build/RETRODB.SYSTEM build/retrodb.o
ls -l build/RETRODB.SYSTEM
python3 - <<'PY'
import re
L = {}
for line in open("build/retrodb.lbl"):
    a, v, n = line.split()
    L[n[1:]] = int(v, 16)
sz = L['__LCODE_SIZE__']
xe = L['__XBSS_RUN__'] + L['__XBSS_SIZE__']
be = L['__BSS_RUN__'] + L['__BSS_SIZE__']
pe = L['__SPLZ_RUN__']
se = pe + L['__SPLZ_SIZE__']
tb = 3 * 250 + 128 + 64
print('LCODE %d bytes at $2000; XBSS to $%04X; program $4000-$%04X; BSS $1000-$%04X'
      % (sz, xe - 1, pe - 1, be - 1))
le = L['__LCODE_RUN__'] + sz
print('main-memory record pool: %d bytes ($%04X-$BAFF)' % (0xBB00 - pe - tb, pe + tb))
for n in (0, 1, 2):
    e = L.get('__OV%dBSS_RUN__' % n, 0) + L.get('__OV%dBSS_SIZE__' % n, 0)
    print('overlay %d: $2900-$%04X (%d bytes free)' % (n, e - 1, 0x4000 - e))
    assert e <= 0x4000, 'overlay %d too big' % n
assert le <= 0x2900, 'LCODE runs into the overlays'
assert pe + tb <= 0xB400, 'the record pool must start before ROWBUF ($B400)'
assert xe <= 0x4000 and be <= 0x2000 and se <= 0xBB00
PY
