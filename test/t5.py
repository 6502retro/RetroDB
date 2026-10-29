# RetroDB: limits, memory, /RAM, damaged files, the Open list
import sys; sys.path.insert(0, 'test')
from common import *
V = 'test/v5'
F = [('Name', 'Text', 20, 1), ('N', 'Number', 0, 1)]
L = {}
for line in open('build/retrodb.lbl'):
    _, v, n = line.split(); L[n[1:]] = int(v, 16)
def go(last='DB', **kw):
    open(V + '/RETRODB.LAST', 'wb').write(last.encode() + b'\r')
    return start(V, **kw)
# full
fresh(V); open(V + '/DB', 'wb').write(dbfile('DB', F, [['R%d' % i, str(i)] for i in range(250)]))
a = go()
check('250 records load', '250 of 250 records' in rows(a, 22, 23) and 'Database: DB' in rows(a, 0, 1))
a.key('N', oa=True); a.run()
check('full: New Record says so', 'The database is full.' in a.plain())
a.key('\r'); a.run()
a.key('C', oa=True); a.run()
check('full: Duplicate says so', 'The database is full.' in a.plain())
a.key('\r'); a.run()
a.key(0x15); a.key(0x15); a.run()
for _ in range(20): a.key(0x15)
a.run()
check('paging to the end shows R249', 'R249' in a.plain())
# more than fit
fresh(V); open(V + '/DB', 'wb').write(dbfile('DB', F, [['R%d' % i, str(i)] for i in range(260)]))
a = go()
check('260 records: warns, Untitled, 250 loaded', 'more records' in a.plain() and 'Untitled' in rows(a, 0, 1))
a.key('\r'); a.run()
check('250 of 250 after the warning', '250 of 250' in rows(a, 22, 23))
# short file
fresh(V); b = dbfile('DB', F, [['R%d' % i, str(i)] for i in range(10)]).split(b'\r')
b[2 + 2] = b'12'; open(V + '/DB', 'wb').write(b'\r'.join(b))
a = go()
check('short file warns and opens Untitled', "doesn't hold the number" in a.plain() and 'Untitled' in rows(a, 0, 1))
a.key('\r'); a.run()
check('the records that are there are loaded', '10 of 250' in rows(a, 22, 23))
# not a RetroDB file
fresh(V); open(V + '/DB', 'wb').write(b'RETROINV3\r0\r')
a = go()
check('RETRODB.LAST naming another kind of file: start empty', 'Untitled' in rows(a, 0, 1) and 'no form yet' in a.plain())
# no auxiliary memory: main memory only
fresh(V); open(V + '/DB', 'wb').write(dbfile('DB', [('Name', 'Text', 56, 1), ('X', 'Text', 56, 1)], [['a', 'b']]))
a = go(mem128=False)
cap = a.main[L['maxrec']]
check('64K Apple: fewer records fit (%d)' % cap, a.main[L['auxok']] == 0 and cap == ((0x4000 - L['__XBSS_RUN__'] - L['__XBSS_SIZE__']) // 114) + ((0xBB00 - L['__SPLZ_RUN__'] - (3 * 250 + 128 + 64)) // 114))
# /RAM holding files
a = go(ram=3)
check('/RAM with files: message, main memory only', '/RAM has files on it' in a.plain() and a.main[L['auxok']] == 0)
a.key('\r'); a.run()
check('/RAM with files: left connected', a.main[0xBF31] == 1 and a.main[0xBF33] == 0xBF and a.main[0xBF26:0xBF28] == bytearray([0, 0xFF]))
# empty /RAM: disconnected, put back at Quit
a = go(ram=0)
check('empty /RAM: aux memory used', a.main[L['auxok']] == 1 and a.main[L['maxrec']] == 250)
check('empty /RAM: taken out of the device list', a.main[0xBF31] == 0 and a.main[0xBF26:0xBF28] == a.main[0xBF10:0xBF12])
a.key('Q', oa=True); a.run()
check('quit: /RAM put back and formatted', a.quit and a.main[0xBF31] == 1 and a.main[0xBF33] == 0xBF and a.main[0xBF26:0xBF28] == bytearray([0, 0xFF]) and a.ramformatted)
# 16 fields
fresh(V)
F16 = [('Field %d' % i, ['Text', 'Number', 'Money', 'Date', 'Yes/No'][i % 5], 8, 1) for i in range(16)]
a = go('NONE')
a.key('N', oa=True); a.run(); design(a, F16, ok=False)
check('16 fields: no new row after the last', 'Field 15' in a.plain())
a.key('\r'); a.run()
check('16 fields made', 'Field 0' in rows(a, 2, 3))
a.key('N', oa=True); a.run()
check('record window holds 16 fields', 'Field 15' in a.plain() and 'OK' in rows(a, 22, 23))
for i in range(16):
    a.key(['abc', '12', '3.5', '2020', 'Y'][i % 5] + '\t')
a.key('\r'); a.run()
a.key('S', oa=True); a.run(); a.key('SIXTEEN\r'); a.run()
l = lines(V, 'SIXTEEN')
check('16 fields saved', l[1] == '16' and l[18] == '1' and l[19:24] == ['"abc"', '"12"', '"3.50"', '"2020"', '"Yes"'])
# disk full while saving
a.key('N', oa=True); a.run(); a.key('more\r'); a.run()
a.capacity = a.used() + 100
a.key('S', oa=True); a.run()
check('disk full: message, file not changed', 'The disk is full.' in a.plain() and 'was not changed' in a.plain())
check('disk full: SIXTEEN still has 1 record', lines(V, 'SIXTEEN')[18] == '1')
check('disk full: no RETRODB.SAVING left', not os.path.exists(V + '/RETRODB.SAVING'))
a.key('\r'); a.run(); a.capacity = None
a.key('S', oa=True); a.run()
check('saved once there is room', lines(V, 'SIXTEEN')[18] == '2')
# the Open list
fresh(V)
for i in range(16): open(V + '/DB%02d' % i, 'wb').write(dbfile('x', F, [['x', '1']]))
open(V + '/NOTES', 'wb').write(b'Just a text file\r')
a = go('DB03')
a.key('O', oa=True); a.run()
p = a.plain()
check('Open lists databases only', 'DB00' in p and 'NOTES' not in p and 'RETRODB.LAST' not in p)
check('Open: only the first 14', 'Only the first 14 are listed.' in p and 'DB13' in p and 'DB14' not in p)
pick(a, 'DB07')
check('opened DB07', 'Database: DB07' in rows(a, 0, 1) and lines(V, 'RETRODB.LAST')[0] == 'DB07')
# Save As onto another database / a text file
a.key('N', oa=True); a.run(); a.key('new\r'); a.run()
menu(a, 1, 3); a.key(0x18); a.key('DB01\r'); a.run()
check('Save As over another database asks', 'A database with that name' in a.plain())
a.key(0x1B); a.run(); a.key(0x18); a.key('NOTES\r'); a.run()
check('Save As over a text file refuses', 'is not a database' in a.plain())
a.key('\r'); a.run(); a.key(0x18); a.key('NEWDB\r'); a.run()
check('Save As NEWDB', 'Database: NEWDB' in rows(a, 0, 1) and lines(V, 'NEWDB')[0] == 'RETRODB1' and lines(V, 'DB07')[4] == '1')
done()
