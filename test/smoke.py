import sys; sys.path.insert(0, 'test')
from common import *
V = 'test/vol'; fresh(V)
a = start(V)
a.key('N', oa=True); a.run()   # no form yet: opens Design Form
design(a, [('Name', 'Text', 30, 1), ('Phone', 'Text', 14, 1), ('Born', 'Date', 0, 1),
           ('Owes', 'Money', 0, 1), ('Kids', 'Number', 0, 1), ('Friend', 'Yes/No', 0, 1)], ok=False)
show(a)
a.key('\r'); a.run(); show(a)
newrec(a, ['Ada Lovelace', '555-1212', '12/10/1815', '12.5', '1', 'Y'])
show(a)
newrec(a, ['Charles Babbage', '555-9999', '1791-12-26', '-3', '4', 'N'])
newrec(a, ['Grace Hopper', '', '1906', '1234567.89', '', 'Y'])
show(a)
