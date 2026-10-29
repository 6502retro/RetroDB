import sys, subprocess; sys.path.insert(0, 'test')
from common import *
V = 'test/vol'
a = start(V)
a.key('X', oa=True); a.run(); show(a)
a.key('\r'); a.run(); show(a)
print(subprocess.run(['node', 'test/mccheck.js', V + '/PEOPLE.MC'], capture_output=True, text=True).stdout)
