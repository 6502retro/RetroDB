import sys, subprocess; sys.path.insert(0, 'test')
from common import *
V = 'test/vol'
a = start(V)
a.types['PEOPLE.MC'] = 0xF8
a.key(0x1B); a.key('\r'); a.run()   # File > New Database...
show(a)
a.key(0x1B); a.run()
a.key('I', oa=True); a.run(); a.key('\r'); a.run(); show(a)
a.key('\r'); a.run(); show(a)
a.key('\r'); a.run(); show(a)
a.key(0x1B); a.key(0x15); a.key(0x15); a.run(); show(a)   # Sort menu lists the new fields
a.key(0x1B); a.run()
a.key(0x0A); a.key('\r'); a.run(); show(a)
