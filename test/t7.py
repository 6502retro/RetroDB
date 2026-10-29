# MouseDB: the Open list in a folder whose directory spans several blocks
import sys; sys.path.insert(0, 'test')
from common import *
F = [('Name', 'Text', 20, 1)]
def opened(a):
    a.key('O', oa=True); a.run(); t = a.plain(); a.key(0x1B); a.run(); return t
# 1. 8 databases among 12 plain text files: all 8 listed, once each
V = 'test/v7'; fresh(V)
for i in range(8): open(V + '/DB%02d' % i, 'wb').write(dbfile('DB%02d' % i, F, [['x']]))
for i in range(12): open(V + '/NOTE%02d' % i, 'wb').write(b'hello\r')
open(V + '/MOUSEDB.LAST', 'wb').write(b'DB00\r')
a = start(V); t = opened(a)
names = re.findall(r'\b(DB\d\d)\b', t.split('Databases in this folder')[1])
check('all 8 databases listed once: %s' % names, names == ['DB%02d' % i for i in range(8)])
# 2. 20 databases: the first 14, no repeats, and the note
fresh(V)
for i in range(20): open(V + '/DB%02d' % i, 'wb').write(dbfile('DB%02d' % i, F, [['x']]))
open(V + '/MOUSEDB.LAST', 'wb').write(b'DB00\r')
a = start(V); t = opened(a)
names = re.findall(r'\b(DB\d\d)\b', t.split('Databases in this folder')[1])
check('14 different databases listed: %s' % names, len(names) == 14 and len(set(names)) == 14)
check('says only the first 14', 'Only the first 14' in t)
done()
