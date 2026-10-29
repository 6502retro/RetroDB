#!/bin/sh
# Build MOUSEDB.SYSTEM from source (needs cc65's ca65 and ld65)
set -e
cd "$(dirname "$0")"
mkdir -p build
[ -f build/splash.bin ] || python3 tools/mksplash.py art/6502retro-logo.png build/splash.bin build/splash.png
[ -f build/mchdr.pk ] || python3 tools/mkmchdr.py tools/mcsamples/SAMPLE.BILL build/mchdr.pk build/mchdr.raw
[ build/splash.lz -nt build/splash.bin ] || python3 tools/mklz.py build/splash.bin build/splash.lz
ca65 -g -t none -I src -l build/mousedb.lst -o build/mousedb.o src/main.s
ld65 -C src/mousedb.cfg -m build/mousedb.map -Ln build/mousedb.lbl -o build/MOUSEDB.SYSTEM build/mousedb.o
ls -l build/MOUSEDB.SYSTEM
python3 - <<'PY'
import re
L = {}
for line in open("build/mousedb.lbl"):
    a, v, n = line.split()
    L[n[1:]] = int(v, 16)
sz = L['__LCODE_SIZE__']
xe = L['__XBSS_RUN__'] + L['__XBSS_SIZE__']
be = L['__BSS_RUN__'] + L['__BSS_SIZE__']
pe = L['__DATA_RUN__'] + L['__DATA_SIZE__']
tb = 3 * 250 + 128 + 64
print('LCODE %d bytes at $2000; XBSS to $%04X; program $4000-$%04X; BSS $1000-$%04X'
      % (sz, xe - 1, pe - 1, be - 1))
print('main-memory record pools: %d + %d bytes' % (0x4000 - xe, 0xBB00 - pe - tb))
assert xe <= 0x4000 and be <= 0x2000 and pe + tb <= 0xBB00
PY
