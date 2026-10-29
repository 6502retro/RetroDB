# RetroDB: a new database's Design Form starts clean, whatever was in memory
import sys; sys.path.insert(0, 'test')
from common import *
for seed in ('3', '11', '29'):
    V = 'test/v9'; fresh(V)
    a = start(V, garbage=seed)
    a.key('N', oa=True); a.run()                       # no form yet: Design Form
    t = a.plain()
    row = t.split('\n')[5]
    check('seed %s: the new row is blank: %r' % (seed, row[3:24]), row[3:24].strip('_ ') == '')
    design(a, [('Title', 'Text', 20, 1), ('Year', 'Number', 0, 1)])
    hdr = a.plain().split('\n')[2]
    check('seed %s: fields made: %r' % (seed, hdr.strip()), hdr.split()[:2] == ['Title', 'Year'])
    # type a name in the new row, cancel, and open Design Form again
    menu(a, 1, 5); a.key(0x0A); a.key(0x0A); a.key('Junk'); a.key(0x1B); a.run()
    menu(a, 1, 5); row = a.plain().split('\n')[7]; a.key(0x1B); a.run()
    check('seed %s: a cancelled new row is blank next time: %r' % (seed, row[3:24]), row[3:24].strip('_ ') == '')
done()
