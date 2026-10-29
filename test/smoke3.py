import sys; sys.path.insert(0, 'test')
from common import *
V = 'test/vol'
a = start(V)          # RETRODB.LAST -> PEOPLE
print(rows(a, 0, 8))
# Sort menu: ESC, right x2 (Sort), down to "By Owes" (index 3), RETURN
a.key(0x1B); a.key(0x15); a.key(0x15); a.run(); show(a)
a.key(0x0A); a.key(0x0A); a.key(0x0A); a.key('\r'); a.run(); print(rows(a, 4, 8))
a.key(0x1B); a.key(0x15); a.key(0x15); a.key(0x0A); a.key(0x0A); a.key(0x0A); a.key('\r'); a.run(); print(rows(a, 4, 8))
a.key(0x1B); a.key(0x15); a.key(0x15); a.run(); print(rows(a, 0, 10))
a.key(0x1B); a.run()
# Select: Owes >10
a.key('L', oa=True); a.run(); show(a)
a.key('\t\t\t>10\r'); a.run(); show(a)
a.key('A', oa=True); a.run(); print(rows(a, 4, 8)); print(rows(a,22,23))
a.key('F', oa=True); a.run(); a.key('hop\r'); a.run(); print(rows(a, 4, 8))
