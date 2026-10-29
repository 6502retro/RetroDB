"""Build the RetroDB release disk: the sample databases, a Mouse Calc sheet
exported by RetroDB itself (in the simulator), and a bootable ProDOS disk."""
import sys, os, shutil, subprocess
sys.path.insert(0, 'tools'); sys.path.insert(0, 'test')
from sim import boot
OUT = 'release'
subprocess.run([sys.executable, 'tools/mksamples.py', 'build/samples'], check=True)
# COLLECT.MC: export COLLECTION from RetroDB
V = 'build/vexp'
shutil.rmtree(V, ignore_errors=True); os.makedirs(V)
shutil.copy('build/samples/COLLECTION', V + '/COLLECTION')
open(V + '/RETRODB.LAST', 'wb').write(b'COLLECTION\r')
a = boot('build/RETRODB.SYSTEM', V); a.run(); a.key(' '); a.run()
a.key('X', oa=True); a.run(); a.key(0x18); a.key('COLLECT.MC\r'); a.run()
assert 'Exported 16 records' in a.plain(), a.plain()
shutil.copy(V + '/COLLECT.MC', 'build/COLLECT.MC')
os.makedirs(OUT, exist_ok=True)
files = ['prodos/PRODOS:PRODOS:0xFF:0x0000',
         'build/RETRODB.SYSTEM:RETRODB.SYSTEM:0xFF:0x2000',
         'prodos/BASIC.SYSTEM:BASIC.SYSTEM:0xFF:0x2000']
if os.path.exists('src/RETRODB.BAS'):
    files.append('src/RETRODB.BAS:RETRODB:BAS:0')
files += ['build/samples/ADDRESSES:ADDRESSES:0x04:0x0000',
          'build/samples/COLLECTION:COLLECTION:0x04:0x0000',
          'build/samples/SOFTWARE:SOFTWARE:0x04:0x0000',
          'build/COLLECT.MC:COLLECT.MC:0xF8:0x0000']
open('build/RETRODB.LAST', 'wb').write(b'ADDRESSES\r')
files.append('build/RETRODB.LAST:RETRODB.LAST:0x04:0x0000')
subprocess.run([sys.executable, 'tools/mkprodos.py', '--boot=prodos/BOOTBLOCKS', OUT + '/RETRODB-1.1.po', 'RETRODB'] + files, check=True)
print('wrote', OUT + '/RETRODB-1.1.po')
