#!/bin/sh
# Build RETRODB.SYSTEM from source (needs cc65's ca65 and ld65)
set -e
cd "$(dirname "$0")"
mkdir -p build
[ -f build/splash.bin ] || python3 tools/mksplash.py art/6502retro-logo.png build/splash.bin build/splash.png
[ -f build/mchdr.pk ] || python3 tools/mkmchdr.py tools/mcsamples/SAMPLE.BILL build/mchdr.pk build/mchdr.raw
[ build/splash.lz -nt build/splash.bin ] || python3 tools/mklz.py build/splash.bin build/splash.lz
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
print('main-memory record pools: %d + %d bytes' % (0x4000 - xe, 0xBB00 - pe - tb))
assert xe <= 0x4000 and be <= 0x2000 and pe + tb <= 0xBB00 and se <= 0xBB00
PY
