# RetroDB: the mouse
import sys; sys.path.insert(0, 'test')
from common import *
V = 'test/v6'; fresh(V)
F = [('Name', 'Text', 20, 1), ('Qty', 'Number', 0, 1), ('Ok', 'Yes/No', 0, 1)]
open(V + '/DB', 'wb').write(dbfile('DB', F, [['R%02d' % i, str(i), 'Yes'] for i in range(40)]))
open(V + '/RETRODB.LAST', 'wb').write(b'DB\r')
a = start(V)
def sel_row():
    for y in range(4, 21):
        if '#' in a.inverse_spans(y)[1:60]: return y
a.click(5, 7)
check('click a record selects it', sel_row() == 7)
a.click(5, 7)
check('click it again opens it', 'Edit Record' in a.plain() and 'R03' in a.plain())
a.click(68, 9)                       # Cancel (row 6+3 = 9)
check('Cancel button closes', 'Edit Record' not in a.plain())
a.click(79, 20)
check('scroll down arrow moves the selection', sel_row() == 8)
a.click(79, 18)
check('the gray track moves a page', 'R20' in a.plain() or 'R21' in a.plain())
# menus: click the title, then the item
a.click(12, 0)
check('click Record: the menu opens', 'New Record' in a.plain() and 'Find Next' in a.plain())
a.click(15, 7)                       # Find... (row 2+5)
check('click Find', 'Looks in every field' in a.plain())
a.key('R05\r'); a.run()
check('found R05', 'R05' in a.plain())
# drag: press on View, move down to Report, release
a.mouse_to(25, 0); a.run(); a.mbtn = True; a.run()
a.mouse_to(26, 4); a.run(); a.mbtn = False; a.run()
check('drag to Report… opens the report', 'Report' in rows(a, 3, 4) and 'Records' in a.plain())
a.click(65, 22)
check('OK closes the report', 'Average' not in a.plain())
# Yes/No by clicking its arrows
a.key('\r'); a.run()
a.click(3, 7)                        # the Ok field's name
a.click(26, 7)                       # its right arrow: Yes -> No
check('click the arrow changes Yes/No', '← No' in a.plain())
a.click(62, 9)                       # OK
check('OK saves the change', 'No' in [l for l in a.plain().split('\n') if 'R05' in l][0])
# Design Form by the mouse: click a type arrow, Insert / Delete buttons
menu(a, 1, 5)
a.click(30, 6)                       # Qty's type: right side -> Money
check('click the type steps it', '← Money' in a.plain())
a.click(10, 22)                      # Insert Field
check('Insert Field adds a row', a.plain().count('_______________') >= 2)
a.click(25, 22)                      # Delete Field
check('Delete Field removes it', 'Money' in a.plain())
a.click(69, 22)                      # Cancel
check('Cancel leaves the form', 'Number' not in a.plain() and 'Qty' in rows(a, 2, 3))
done()
