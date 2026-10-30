# RetroDB: ODS and CSV export and import
import sys, subprocess, zipfile, csv, io; sys.path.insert(0, 'test')
from common import *
V = 'test/v4'; fresh(V)
F = [('Title', 'Text', 24, 1), ('Maker', 'Text', 12, 1), ('Year', 'Number', 0, 1),
     ('Price', 'Money', 0, 1), ('Bought', 'Date', 0, 1), ('Boxed', 'Yes/No', 0, 1)]
R = [['Karateka', 'Broderbund', '1984', '25.00', '1990-05-01', 'Yes'],
     ['Lode Runner', 'Broderbund', '1983', '30.00', '1989-12-24', 'No'],
     ['Oregon Trail', 'MECC', '1985', '20.00', '1991', ''],
     ['Zork I', 'Infocom', '1980', '45.50', '', 'Yes'],
     ["Ultima IV & <Avatar>", 'Origin', '-1985', '-5.00', '1992-02-29', 'Yes']]
open(V + '/GAMES', 'wb').write(dbfile('GAMES', F, R))
open(V + '/RETRODB.LAST', 'wb').write(b'GAMES\r')
def lo(src, fmt):
    """convert with LibreOffice; returns the new file's path"""
    d = os.path.dirname(src)
    subprocess.run(['soffice', '--headless', '--infilter=CSV:44,34,76,1,,1033,false,true' if src.endswith('.csv') else '--headless',
                    '--convert-to', fmt, '--outdir', d, src], capture_output=True, timeout=180)
    return os.path.splitext(src)[0] + '.' + fmt.split(':')[0]
def body(name):
    l = lines(V, name); nf = int(l[1]); n = int(l[2 + nf])
    return l[2:2 + nf], [[v.strip('"') for v in l[3 + nf + k * nf:3 + nf + (k + 1) * nf]] for k in range(n)]
def go():
    return start(V)
T = 'test/v4lo'; fresh(T)

# ---- export ODS
a = go()
a.key('X', oa=True); a.run()
check('export asks ODS or CSV', 'ODS' in a.plain() and 'CSV' in a.plain())
a.key('\r'); a.run()
check('export suggests GAMES.ODS', 'Name: GAMES.ODS' in a.plain())
a.key('\r'); a.run()
check('exported 5 records', 'Exported 5 records to' in a.plain() and '/RETRODB/GAMES.ODS' in a.plain())
a.key('\r'); a.run()
z = zipfile.ZipFile(V + '/GAMES.ODS')
check('ODS: a good zip', z.testzip() is None and z.namelist() == ['mimetype', 'META-INF/manifest.xml', 'content.xml'])
check('ODS: mimetype first and stored', z.read('mimetype') == b'application/vnd.oasis.opendocument.spreadsheet' and z.infolist()[0].compress_type == 0)
shutil.copy(V + '/GAMES.ODS', T + '/g.ods')
got = open(lo(T + '/g.ods', 'csv')).read().splitlines()
print(got)
check('LibreOffice reads the ODS', got == ['Title,Maker,Year,Price,Bought,Boxed',
    'Karateka,Broderbund,1984,25,1990-05-01,Yes', 'Lode Runner,Broderbund,1983,30,1989-12-24,No',
    'Oregon Trail,MECC,1985,20,1991,', 'Zork I,Infocom,1980,45.5,,Yes', 'Ultima IV & <Avatar>,Origin,-1985,-5,1992-02-29,Yes'])
x = z.read('content.xml').decode()
check('ODS: types', 'office:value-type="currency" office:currency="USD" office:value="-5.00"' in x
      and 'office:date-value="1992-02-29"' in x and 'office:value-type="float" office:value="1984"' in x)

# ---- export CSV
a.key('X', oa=True); a.run(); a.key('C'); a.run()
check('export suggests GAMES.CSV', 'Name: GAMES.CSV' in a.plain())
a.key('\r'); a.run()
check('exported 5 records (CSV)', 'Exported 5 records to' in a.plain() and '/RETRODB/GAMES.CSV' in a.plain())
a.key('\r'); a.run()
raw = open(V + '/GAMES.CSV', 'rb').read()
print(raw)
rows_ = list(csv.reader(io.StringIO(raw.decode())))
check('CSV: headings and rows', rows_[0] == ['Title', 'Maker', 'Year', 'Price', 'Bought', 'Boxed'] and len(rows_) == 6)
check('CSV: values', rows_[1] == R[0] and rows_[5] == R[4] and rows_[3] == R[2])
# exporting again asks before replacing; refuses other files
a.key('X', oa=True); a.run(); a.key('\r'); a.run(); a.key('\r'); a.run()
check('existing file: asks to replace', 'already' in a.plain() and 'exists. Replace it?' in a.plain())
a.key(0x1B); a.run()
a.key('X', oa=True); a.run(); a.key('\r'); a.run(); a.key(0x18); a.key('GAMES\r'); a.run()
check('refuses to write over the database', 'belongs to a database' in a.plain())
a.key('\r'); a.run(); a.key(0x18); a.key('RETRODB.OVL\r'); a.run()
check("refuses RetroDB's own names", 'belongs to a database' in a.plain())
a.key('\r'); a.run(); a.key(0x1B); a.run()
show(a)
# export only the selected records
a.key('L', oa=True); a.run(); a.key('\tbrod\r'); a.run()
a.key('X', oa=True); a.run(); a.key('\r'); a.run(); a.key(0x18); a.key('SEL.ODS\r'); a.run()
check('exported 2 records', 'Exported 2 records' in a.plain())
a.key('\r'); a.run(); a.key('A', oa=True); a.run()
shutil.copy(V + '/SEL.ODS', T + '/sel.ods')
check('selection: 2 rows', len(open(lo(T + '/sel.ods', 'csv')).read().splitlines()) == 3)

# ---- import: replace with its own CSV export -> the same database
a = go()
a.key('I', oa=True); a.run()
check('import lists CSV and ODS files', all(n in a.plain() for n in ('GAMES.CSV', 'GAMES.ODS', 'SEL.ODS')))
pick(a, 'GAMES.CSV')
check('import asks Add / Replace', 'Add' in a.plain() and 'Replace' in a.plain())
a.key('R'); a.run()
check('imported 5 (CSV)', 'Imported 5 records.' in a.plain())
a.key('\r'); a.run(); a.key('S', oa=True); a.run()
hdr, got = body('GAMES')
check('replace with its own CSV gives back the same records', got == R)
# ODS: replace, then add
a.key('I', oa=True); a.run(); pick(a, 'GAMES.ODS'); a.key('R'); a.run()
show(a)
check('imported 5 (ODS)', 'Imported 5 records.' in a.plain())
a.key('\r'); a.run(); a.key('S', oa=True); a.run()
hdr, got = body('GAMES')
print(got)
check('replace with its own ODS gives back the same records', got == R)
a.key('I', oa=True); a.run(); pick(a, 'SEL.ODS'); a.key('A'); a.run()
check('Add: 2 more', 'Imported 2 records.' in a.plain())
a.key('\r'); a.run()
check('now 7 records', '7 of 250 records' in rows(a, 22, 23))
# a file LibreOffice made: compressed, headings in another order, extra column
open(T + '/hand.csv', 'w').write('PRICE, title ,Notes,boxed,BOUGHT\n$9.99,Choplifter,extra,y,1982-03-04\n'
                                 '"$1,200.50",Lisa 2,,FALSE,bad date\n7,,,,\n,,,,\n,Last,,,\n')
shutil.copy(lo(T + '/hand.csv', 'ods'), V + '/HAND.ODS')
shutil.copy(T + '/hand.csv', V + '/HAND.CSV')
for n in ('HAND.ODS', 'HAND.CSV'):
    a = go()
    a.key('I', oa=True); a.run(); pick(a, n); a.key('R'); a.run()
    check(n + ': 4 records (blank row left out)', 'Imported 4 records.' in a.plain())
    a.key('\r'); a.run(); a.key('S', oa=True); a.run()
    hdr, got = body('GAMES')
    print(got)
    check(n + ' mapped by name', got == [['Choplifter', '', '', '9.99', '1982-03-04', 'Yes'],
                                         ['Lisa 2', '', '', '1200.50', '', 'No'],
                                         ['', '', '', '7.00', '', ''],
                                         ['Last', '', '', '', '', '']])
# a LibreOffice sheet with a totals row: the row with SUM in it is left out
open(T + '/tot.csv', 'w').write('Title,Price,Year\nA,1.50,1990\nB,2.25,1991\n,,\nTotal,=SUM(B2:B3),=B2*2\n')
shutil.copy(lo(T + '/tot.csv', 'ods'), V + '/TOT.ODS')
check('LibreOffice made a SUM formula', 'of:=SUM(' in zipfile.ZipFile(V + '/TOT.ODS').read('content.xml').decode())
a = go()
a.key('I', oa=True); a.run(); pick(a, 'TOT.ODS'); a.key('R'); a.run()
check('totals row left out: 2 records', 'Imported 2 records.' in a.plain())
a.key('\r'); a.run(); a.key('S', oa=True); a.run()
hdr, got = body('GAMES')
check('totals sheet rows', got == [['A', '', '1990', '1.50', '', ''], ['B', '', '1991', '2.25', '', '']])
# no matching headings
open(V + '/NONE.CSV', 'w').write('Foo\nx\n')
a = go(); a.key('I', oa=True); a.run(); pick(a, 'NONE.CSV')
check('no matching headings: message', 'None of the headings in row 1' in a.plain())
a.key('\r'); a.run()
# a new database from RetroInv's sample inventory, through LibreOffice
# RetroInv's sample inventory (exported from Mouse Calc), saved as CSV
shutil.copy('test/retroinv.csv', T + '/inv.csv')
print(open(T + '/inv.csv').read()[:300])
shutil.copy(lo(T + '/inv.csv', 'ods'), V + '/INV.ODS')
shutil.copy(T + '/inv.csv', V + '/INV.CSV')
for n in ('INV.ODS', 'INV.CSV'):
    a = go()
    menu(a, 1, 0)                         # New Database (no changes to save)
    a.key(0x1B); a.run()                  # leave Design Form empty
    a.key('I', oa=True); a.run()
    pick(a, n)
    show(a)
    check(n + ': offers to make a database from the file', 'Make a new database from this' in a.plain() and 'Its 12 columns become' in a.plain())
    a.key('\r'); a.run()
    check('made from RetroInv: 13 records', 'Imported 13 records.' in a.plain())
    a.key('\r'); a.run()
    db = 'C' + n[4]
    a.key('S', oa=True); a.run(); a.key(db + '\r'); a.run()
    hdr, got = body(db)
    print(hdr); print(got[:3])
    check('fields from the headings', [h.split(',')[0] for h in hdr] == ['"Name"', '"Maker"', '"Serial #"', '"Year"', '"Type"', '"Condition"', '"Location"', '"Value"', '"Notes"', '"Slot"', '"Part Of"', '"Item No."'])
    check('kinds guessed: Year Number, Value Money, Item No. Number', hdr[3].split(',')[1] == '2' and hdr[7].split(',')[1] == '3' and hdr[11].split(',')[1] == '2')
    check('Text lengths: longest entry + 10', hdr[0] == '"Name",1,33,1')
    check('a record', got[0][:8] == ['Apple IIe Enhanced', 'Apple', 'A2S2-655123', '1985', 'Computer', 'Excellent', 'Desk', '450.00'])
done()
