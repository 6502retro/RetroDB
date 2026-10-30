"""Build the RetroDB release disk: the sample databases, the COLLECTION
sample exported as ODS and CSV by RetroDB itself (in the simulator), and a
bootable ProDOS disk."""
import sys, os, shutil, subprocess
sys.path.insert(0, 'tools'); sys.path.insert(0, 'test')
from sim import boot
OUT = 'release'
subprocess.run([sys.executable, 'tools/mksamples.py', 'build/samples'], check=True)
# COLLECT.ODS and COLLECT.CSV: export COLLECTION from RetroDB
V = 'build/vexp'
shutil.rmtree(V, ignore_errors=True); os.makedirs(V)
shutil.copy('build/samples/COLLECTION', V + '/COLLECTION')
shutil.copy('build/RETRODB.OVL', V + '/RETRODB.OVL')
open(V + '/RETRODB.LAST', 'wb').write(b'COLLECTION\r')
a = boot('build/RETRODB.SYSTEM', V); a.run(); a.key(' '); a.run()
for fmt in ('ODS', 'CSV'):
    a.key('X', oa=True); a.run(); a.key(fmt[0]); a.run()
    a.key(0x18); a.key('COLLECT.' + fmt + '\r'); a.run()
    assert 'Exported 16 records' in a.plain(), a.plain()
    a.key('\r'); a.run()
for n in ('COLLECT.ODS', 'COLLECT.CSV'):
    shutil.copy(V + '/' + n, 'build/' + n)
os.makedirs(OUT, exist_ok=True)
files = ['prodos/PRODOS:PRODOS:0xFF:0x0000',
         'build/RETRODB.SYSTEM:RETRODB.SYSTEM:0xFF:0x2000',
         'build/RETRODB.OVL:RETRODB.OVL:0x06:0x0000',
         'prodos/BASIC.SYSTEM:BASIC.SYSTEM:0xFF:0x2000']
if os.path.exists('src/RETRODB.BAS'):
    files.append('src/RETRODB.BAS:RETRODB:BAS:0')
files += ['build/samples/ADDRESSES:ADDRESSES:0x04:0x0000',
          'build/samples/COLLECTION:COLLECTION:0x04:0x0000',
          'build/samples/SOFTWARE:SOFTWARE:0x04:0x0000',
          'build/COLLECT.ODS:COLLECT.ODS:0x06:0x0000',
          'build/COLLECT.CSV:COLLECT.CSV:0x04:0x0000']
open('build/RETRODB.LAST', 'wb').write(b'ADDRESSES\r')
files.append('build/RETRODB.LAST:RETRODB.LAST:0x04:0x0000')
subprocess.run([sys.executable, 'tools/mkprodos.py', '--boot=prodos/BOOTBLOCKS', OUT + '/RETRODB-1.2.po', 'RETRODB'] + files, check=True)
print('wrote', OUT + '/RETRODB-1.2.po')
