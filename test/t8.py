# RetroDB 1.1: record numbers (No.) and Part Of, nested to any depth
import sys; sys.path.insert(0, 'test')
from common import *
V = 'test/v8'; fresh(V)
F = [('No.', 'No.', 0, 1), ('Name', 'Text', 22, 1), ('Part Of', 'Part Of', 0, 1), ('Value', 'Money', 0, 1)]
R = [['1', 'Desk', '', ''], ['2', 'Apple IIe', '1', '450'], ['3', '80-Column Card', '2', '35'],
     ['4', 'Mouse Card', '2', '45'], ['5', 'Shelf', '', ''], ['6', 'Joystick', '5', '5'],
     ['7', 'Box A', '5', ''], ['8', 'Oregon Trail', '7', '20']]
open(V + '/GEAR', 'wb').write(dbfile('GEAR', F, R))
open(V + '/RETRODB.LAST', 'wb').write(b'GEAR\r')
a = start(V)
L = listrows(a, 8)
check('Part Of shows the name of the record it is in', L[1].split()[3:4] == ['Desk'] and 'Apple IIe' in L[2][27:])
menu(a, 3, 2)                       # Sort > By Part Of
L = listrows(a, 9)
want = [(1, 0, 'Desk'), (2, 1, 'Apple IIe'), (3, 2, '80-Column Card'), (4, 2, 'Mouse Card'),
        (5, 0, 'Shelf'), (6, 1, 'Joystick'), (7, 1, 'Box A'), (8, 2, 'Oregon Trail')]
got = []
for r in L[:8]:
    no = int(r[:4]); nm = r[5:27]
    got.append((no, (len(nm) - len(nm.lstrip())) // 2, nm.strip()))
check('tree order with indents: %s' % got, got == want)
check('Sort menu marks By Part Of', True)
for _ in range(7): a.key(0x0A)
a.key('\r'); a.run()
t = a.plain()
check('record window shows No. 8 and Part Of Box A', 'No.              8' in t and '7   ' in t and 'Box A' in t)
a.key('\t'); a.key(0x18); a.key('1'); a.run()      # Part Of: type No. 1
check('typing a No. shows that record\'s name', 'Desk' in a.plain().split('\n')[7])
a.key(0x18); a.run()
check('CTRL-X: not part of another record', '(not part of another record)' in a.plain())
a.key(0x15); a.run()
check('RIGHT ARROW picks the first record it can be in', 'Desk' in a.plain().split('\n')[7])
a.key(0x15); a.key(0x15); a.key(0x15); a.key(0x15); a.run()   # Apple IIe, 80-col, Mouse, Shelf
check('RIGHT ARROW steps on: Shelf', 'Shelf' in a.plain().split('\n')[7])
a.key('\r'); a.run()
L = listrows(a, 9)
check('after OK the tree is redrawn: Oregon Trail under Shelf', L[7][5:].startswith('  Oregon Trail') and L[5][5:].startswith('  Joystick'))
# a record can't be put inside itself or inside a record that is inside it
for _ in range(6): a.key(0x0B)                      # up to Apple IIe (row 1)
a.key('\r'); a.run()
a.key('\t'); a.key(0x18); a.key('3'); a.key('\r'); a.run()   # into its own card
check('loop refused', "can't be part of itself" in a.plain())
a.key('\r'); a.run()
a.key(0x18); a.key('2'); a.key('\r'); a.run()
check('itself refused', "can't be part of itself" in a.plain())
a.key('\r'); a.run()
a.key(0x18); a.key('99'); a.key('\r'); a.run()
check('a No. no record has is refused', 'No record has the No.' in a.plain())
a.key('\r'); a.run(); a.key(0x1B); a.run()
# a new record gets the next No.; RIGHT ARROW skips nothing it may join
newrec(a, ['Disk II', '', '60'])
L = listrows(a, 10)
check('new record gets No. 9, not part of anything: %s' % L[8], L[8].startswith('9    Disk II'))
# duplicate: a copy gets a No. of its own
a.key('C', oa=True); a.run(); a.key('\r'); a.run()
L = listrows(a, 11)
check('duplicate gets No. 10: %s' % L[9], L[9].startswith('10   Disk II'))
# deleting a record that holds others: it says so; they are left on their own
a.key(0x0B); a.key(0x0B); a.key(0x0B); a.key(0x0B); a.key(0x0B); a.key(0x0B); a.key(0x0B); a.key(0x0B)
a.key(0x0B); a.run()          # row 0? go to Apple IIe (row 1)
a.key(0x0A); a.run()
a.key('D', oa=True); a.run()
t = a.plain()
check('delete names the records inside', 'It holds 2' in t)
a.key('\r'); a.run()
L = listrows(a, 10)
check('cards stay, at the top level: %s' % L[1:3], L[1].startswith('3    80-Column Card') and L[2].startswith('4    Mouse Card'))
a.key('S', oa=True); a.run()
l = lines(V, 'GEAR')
recs = l[7:7 + 9 * 4]
check('saved: the cards are no longer part of anything', recs[4:8] == ['"3"', '"80-Column Card"', '""', '"35.00"'])
# Select: words look in the name of the record it is in; numbers compare Nos.
a.key('L', oa=True); a.run(); a.key('\t\t'); a.key('shelf'); a.key('\r'); a.run()
st = rows(a, 22, 23)
check('Part Of "shelf" selects what is on the shelf: %s' % st.strip(), '3 selected of 9' in st)
a.key('L', oa=True); a.run(); a.key(0x18); a.key(0x0A); a.key(0x0A); a.key(0x18); a.key(0x0B); a.key(0x0B); a.key('<4'); a.key('\r'); a.run()
st = rows(a, 22, 23)
check('No. <4 selects Nos. 1 and 3: %s' % st.strip(), '2 selected of 9' in st)
a.key('A', oa=True); a.run()
# the report groups by Part Of
a.key('R', oa=True); a.run()
t = a.plain()
check('report groups by Part Of', 'Group by: \u2190 Part Of' in t and 'Shelf' in t and '(blank)' in t)
check('report names records by their Name', 'Highest:  Disk II' in t and 'Lowest:   Joystick' in t)
a.key(0x1B); a.run()
# export, then make a new database from the sheet: No. and Part Of come back
a.key('X', oa=True); a.run(); a.key('\r'); a.run(); a.key('\r'); a.run()
menu(a, 1, 0); a.run()                 # New Database (opens Design Form)
a.key(0x1B); a.run()
a.types['GEAR.MC'] = 0xF8
a.key('I', oa=True); a.run(); pick(a, 'GEAR.MC')
check('import offers to create', 'Make a new database' in a.plain())
a.key('\r'); a.run(); a.key('\r'); a.run()
L = listrows(a, 9)
check('the new database has the links: %s' % L, any(r.startswith('6    Joystick') and 'Shelf' in r for r in L) and any(r.startswith('8    Oregon Trail') and 'Shelf' in r for r in L))
menu(a, 1, 5); t = a.plain(); a.key(0x1B); a.run()
check('its fields are No. and Part Of again', '← No.' in t and 'Part Of' in t)
# importing the sheet again with Add: the copies keep their links among
# themselves, numbered past the records already there
a.key('I', oa=True); a.run(); pick(a, 'GEAR.MC'); a.key('\r'); a.run()
t = a.plain(); a.key('\r'); a.run()
L = listrows(a, 17)
check('Add: 18 records', '18 of 250' in rows(a, 22, 23))
check('added copies are numbered 11-20 and linked to each other: %s' % L[13:16],
      any(r.startswith('16   Joystick') and 'Shelf' in r for r in L) and any(r.startswith('15   Shelf') for r in L))
# Design Form rules
menu(a, 1, 5)
a.key(0x0A); a.key(0x0A); a.key('\t'); a.key(0x08); a.key('\r'); a.run()    # Part Of -> No.: two No. fields
check('only one No. field', 'only one field' in a.plain() and 'of type No.' in a.plain())
a.key('\r'); a.run(); a.key(0x1B); a.run()
menu(a, 1, 5)
a.key('\t'); a.key(0x08); a.key('\r'); a.run()     # No. -> Yes/No: Part Of without a No.
check('Part Of needs a No. field', 'holds the No. of' in a.plain())
a.key('\r'); a.run(); a.key(0x1B); a.run()
# a file with blank, repeated and too-large Nos.: each record gets its own
fresh(V)
open(V + '/ODD', 'wb').write(dbfile('ODD', F, [['', 'A', '', ''], ['3', 'B', '', ''], ['3', 'C', '3', ''], ['1000', 'D', '3', '']]))
open(V + '/RETRODB.LAST', 'wb').write(b'ODD\r')
a = start(V)
L = listrows(a, 4)
nos = [int(r[:4]) for r in L]
check('every record has its own No.: %s' % nos, len(set(nos)) == 4 and 3 in nos and all(1 <= n <= 999 for n in nos))
check('the first record keeps No. 3; links to 3 stay with it: %s' % L, L[1].startswith('3    B') and L[2][27:].strip() == 'B' and L[3][27:].strip() == 'B')
# adding a No. field to a database numbers its records in list order
fresh(V)
open(V + '/PLAIN', 'wb').write(dbfile('PLAIN', [('Name', 'Text', 20, 1)], [['x'], ['y'], ['z']]))
open(V + '/RETRODB.LAST', 'wb').write(b'PLAIN\r')
a = start(V)
menu(a, 1, 5); a.key(0x0A); design(a, [('No.', 'No.', 0, 1)])
L = listrows(a, 3)
check('new No. field numbers the records 1-3: %s' % L, [r.split()[-1] for r in L] == ['1', '2', '3'])
# a database saved by MouseDB (header MOUSEDB1) still opens, and is
# saved as RETRODB1
fresh(V)
open(V + '/OLD', 'wb').write(dbfile('OLD', [('Name', 'Text', 20, 1)], [['kept']]).replace(b'RETRODB1', b'MOUSEDB1'))
open(V + '/RETRODB.LAST', 'wb').write(b'OLD\r')
a = start(V)
check('a MouseDB file opens', listrows(a, 1)[0].startswith('kept'))
a.key('O', oa=True); a.run()
check('and is listed in Open', 'OLD' in a.plain())
a.key(0x1B); a.run()
newrec(a, ['more']); a.key('S', oa=True); a.run()
check('saved as RETRODB1', lines(V, 'OLD')[0] == 'RETRODB1')
done()
