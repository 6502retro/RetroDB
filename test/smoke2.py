import sys; sys.path.insert(0, 'test')
from common import *
V = 'test/vol'; fresh(V)
a = start(V)
a.key('N', oa=True); a.run()
design(a, [('Name', 'Text', 30, 1), ('Phone', 'Text', 14, 1), ('Born', 'Date', 0, 1),
           ('Owes', 'Money', 0, 1), ('Kids', 'Number', 0, 1), ('Friend', 'Yes/No', 0, 1)])
newrec(a, ['Ada Lovelace', '555-1212', '12/10/1815', '12.5', '1', 'Y'])
newrec(a, ['Charles Babbage', '555-9999', '1791-12-26', '-3', '4', 'N'])
newrec(a, ['Grace Hopper', '', '1906', '1234567.89', '', 'Y'])
a.key(0x0B); a.key('\r'); a.run(); show(a)      # edit Charles
a.key(0x1B); a.run()
a.key('R', oa=True); a.run(); show(a)
a.key(0x1B); a.run()
a.key('S', oa=True); a.run(); show(a)       # Save -> Save As
a.key('PEOPLE\r'); a.run(); show(a)
print(open(V + '/PEOPLE','rb').read().decode().replace('\r','\n'))
