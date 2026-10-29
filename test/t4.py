# MouseDB: Mouse Calc export and import
import sys, subprocess, json; sys.path.insert(0, 'test')
from common import *
V = 'test/v4'; fresh(V)
F = [('Title', 'Text', 24, 1), ('Maker', 'Text', 12, 1), ('Year', 'Number', 0, 1),
     ('Price', 'Money', 0, 1), ('Bought', 'Date', 0, 1), ('Boxed', 'Yes/No', 0, 1)]
R = [['Karateka', 'Broderbund', '1984', '25.00', '1990-05-01', 'Yes'],
     ['Lode Runner', 'Broderbund', '1983', '30.00', '1989-12-24', 'No'],
     ['Oregon Trail', 'MECC', '1985', '20.00', '1991', ''],
     ['Zork I', 'Infocom', '1980', '45.50', '', 'Yes'],
     ['Ultima IV', 'Origin', '-1985', '-5.00', '1992-02-29', 'Yes']]
open(V + '/GAMES', 'wb').write(dbfile('GAMES', F, R))
open(V + '/MOUSEDB.LAST', 'wb').write(b'GAMES\r')
def mc(name):
    r = subprocess.run(['node', 'test/mccheck.js', V + '/' + name], capture_output=True, text=True)
    return r.stdout + r.stderr
def go():
    a = start(V)
    for n in os.listdir(V):
        if n.endswith('.MC') or n.startswith('S.'): a.types[n] = 0xF8
    return a
def body(name):
    l = lines(V, name); nf = int(l[1]); n = int(l[2 + nf])
    return l[2:2 + nf], [[v.strip('"') for v in l[3 + nf + k * nf:3 + nf + (k + 1) * nf]] for k in range(n)]
a = go()
a.key('X', oa=True); a.run()
check('export suggests GAMES.MC', 'Name: GAMES.MC' in a.plain())
a.key('\r'); a.run()
check('exported 5 records', 'Exported 5 records to' in a.plain() and '/MOUSEDB/GAMES.MC' in a.plain())
a.key('\r'); a.run()
out = mc('GAMES.MC'); print(out)
check('sheet: 8 rows, 6 columns', 'maxRow 8 maxCol 6' in out)
check('sheet: headings', '1 "Title" | "Maker" | "Year" | "Price" | "Bought" | "Boxed"' in out)
check('sheet: a row', '2 "Karateka" | "Broderbund" | 1984 | 25/f8 | "1990-05-01" | "Yes"' in out)
check('sheet: negatives', '6 "Ultima IV" | "Origin" | -1985 | -5/f8 | "1992-02-29" | "Yes"' in out)
check('sheet: blanks left empty', '4 "Oregon Trail" | "MECC" | 1985 | 20/f8 | "1991" | ' in out)
check('sheet: totals (Money only, not Year)', '8 "Total" |  |  | +SUM(D2...D6)=115.5 |  | ' in out)
check('sheet: formulas evaluate to their cached totals', 'eval D8 115.5 cached 115.5' in out and 'C8' not in out)
check('sheet: widths', 'widths 25,13,11,13,11,6' in out)
check('sheet: same bytes as the Mouse Calc Converter writes', 'rebuilt identical: true' in out)
# exporting again asks before replacing; refuses other files
a.key('X', oa=True); a.run(); a.key('\r'); a.run()
check('existing sheet: asks to replace', 'already exists. Replace it?' in a.plain())
a.key(0x1B); a.run()
a.key('X', oa=True); a.run(); a.key(0x18); a.key('GAMES\r'); a.run()
check('refuses to write over the database', 'is not a Mouse Calc sheet' in a.plain())
a.key('\r'); a.run(); a.key(0x18); a.key('MOUSEDB.LAST\r'); a.run()
check("refuses MouseDB's own names", 'is not a Mouse Calc sheet' in a.plain())
a.key('\r'); a.run(); a.key(0x1B); a.run()
# export only the selected records
a.key('L', oa=True); a.run(); a.key('\tbrod\r'); a.run()
a.key('X', oa=True); a.run(); a.key(0x18); a.key('SEL.MC\r'); a.run()
check('exported 2 records', 'Exported 2 records' in a.plain())
a.key('\r'); a.run(); a.key('A', oa=True); a.run()
out = mc('SEL.MC')
check('selection sheet: 2 rows and a total', 'maxRow 5' in out and '+SUM(D2...D3)=55' in out)
# import: replace with its own export -> the same database
a = go()
a.key('I', oa=True); a.run()
check('import lists the sheets', 'GAMES.MC' in a.plain() and 'SEL.MC' in a.plain())
a.key('\r'); a.run()
check('import asks Add / Replace', 'Add' in a.plain() and 'Replace' in a.plain())
a.key('R'); a.run()
check('imported 5', 'Imported 5 records.' in a.plain())
a.key('\r'); a.run(); a.key('S', oa=True); a.run()
hdr, got = body('GAMES')
check('replace with its own export gives back the same records', got == R)
# add
a.key('I', oa=True); a.run(); pick(a, 'SEL.MC'); a.key('\r'); a.run()
check('Add: 2 more', 'Imported 2 records.' in a.plain())
a.key('\r'); a.run()
check('now 7 records', '7 of 250 records' in rows(a, 22, 23))
# a hand-made sheet: headings in another order, any case, extra column, total row skipped
subprocess.run(['node', 'test/mcmake.js', V + '/S.HAND', json.dumps([
    [1, 1, 'PRICE'], [1, 2, ' title '], [1, 3, 'Notes'], [1, 4, 'boxed'], [1, 5, 'BOUGHT'],
    [2, 1, 9.99, 8], [2, 2, 'Choplifter'], [2, 3, 'extra'], [2, 4, 'y'], [2, 5, '3/4/1982'],
    [3, 1, '$1,200.50'], [3, 2, 'Lisa 2'], [3, 4, 'FALSE'], [3, 5, 'bad date'],
    [4, 1, 7], [5, 2, 'Last'],
    [7, 1, '=SUM(A2:A5)', 8], [7, 2, 'Total']])], check=True)
a = go()
a.key('I', oa=True); a.run()
pick(a, 'S.HAND'); a.key('R'); a.run()
check('hand-made sheet: 4 records (blank and total rows left out): ' + rows(a, 10, 12), 'Imported 4 records.' in a.plain())
a.key('\r'); a.run(); a.key('S', oa=True); a.run()
hdr, got = body('GAMES')
check('hand-made sheet mapped by name: %s' % got, got == [['Choplifter', '', '', '9.99', '1982-03-04', 'Yes'],
                                                       ['Lisa 2', '', '', '1200.50', '', 'No'],
                                                       ['', '', '', '7.00', '', ''],
                                                       ['Last', '', '', '', '', '']])
# no matching headings
subprocess.run(['node', 'test/mcmake.js', V + '/S.NONE', json.dumps([[1, 1, 'Foo'], [2, 1, 'x']])], check=True)
a = go(); a.key('I', oa=True); a.run(); pick(a, 'S.NONE')
check('no matching headings: message', 'None of the headings in row 1' in a.plain())
a.key('\r'); a.run()
# a new database from RetroInv's exported sample inventory
shutil.copy('test/RETROINV.SAMPLE.INV', V + '/S.RETROINV')
a = go()
menu(a, 1, 0)                         # New Database (no changes to save)
a.key(0x1B); a.run()                  # leave Design Form empty
a.key('I', oa=True); a.run()
pick(a, 'S.RETROINV')
check('offers to make a database from the sheet', 'Make a new database from this' in a.plain() and 'Its 12 columns become' in a.plain())
a.key('\r'); a.run()
check('made from RetroInv: 13 records', 'Imported 13 records.' in a.plain())
a.key('\r'); a.run()
a.key('S', oa=True); a.run(); a.key('COLLECTION\r'); a.run()
hdr, got = body('COLLECTION')
print(hdr); print(got[:3])
check('fields from the headings', [h.split(',')[0] for h in hdr] == ['"Name"', '"Maker"', '"Serial #"', '"Year"', '"Type"', '"Condition"', '"Location"', '"Value"', '"Notes"', '"Slot"', '"Part Of"', '"Item No."'])
check('kinds guessed: Year Number, Value Money, Item No. Number', hdr[3].split(',')[1] == '2' and hdr[7].split(',')[1] == '3' and hdr[11].split(',')[1] == '2')
check('Text lengths: longest entry + 10', hdr[0] == '"Name",1,33,1')
check('the Total row is left out', len(got) == 13 and all(g[0] != 'Total' for g in got))
check('a record', got[0][:8] == ['Apple IIe Enhanced', 'Apple', 'A2S2-655123', '1985', 'Computer', 'Excellent', 'Desk', '450.00'])
done()
