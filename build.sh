#!/bin/sh
# Build MOUSEDB.SYSTEM from source (needs cc65's ca65 and ld65)
set -e
cd "$(dirname "$0")"
mkdir -p build
[ -f build/splash.bin ] || python3 tools/mksplash.py art/6502retro-logo.png build/splash.bin build/splash.png
[ -f build/mchdr.pk ] || python3 tools/mkmchdr.py tools/mcsamples/SAMPLE.BILL build/mchdr.pk build/mchdr.raw
B=$(python3 -c "d=open('build/splash.bin','rb').read(3); print(' '.join('-D SPL%d=\$%02X'%(i,b) for i,b in enumerate(d)))")
ca65 -g -t none -I src $B -l build/mousedb.lst -o build/mousedb.o src/main.s
ld65 -C src/mousedb.cfg -m build/mousedb.map -Ln build/mousedb.lbl -o build/MOUSEDB.SYSTEM build/mousedb.o
ls -l build/MOUSEDB.SYSTEM
python3 - <<'PY'
import re
L = {}
for line in open("build/mousedb.lbl"):
    a, v, n = line.split()
    L[n[1:]] = int(v, 16)
ld, sz = L['__LCODE_LOAD__'], L['__LCODE_SIZE__']
xe = L['__XBSS_RUN__'] + L['__XBSS_SIZE__']
be = L['__BSS_RUN__'] + L['__BSS_SIZE__']
print('program $4000-$%04X; LCODE %d bytes runs at $2000-$%04X; XBSS to $%04X; BSS $1000-$%04X'
      % (ld + sz - 1, sz, 0x2000 + sz - 1, xe - 1, be - 1))
print('main-memory record pools: %d + %d bytes' % (0x4000 - xe, 0xBB00 - ld))
assert xe <= 0x4000 and be <= 0x2000 and ld + sz <= 0xBB00
PY
