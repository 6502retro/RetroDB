# RetroDB: ODS/CSV import at scale, with a full aux pool, on a 64K Apple,
# and CSV dialects
import sys, subprocess, random, csv; sys.path.insert(0, 'test')
from common import *
import sim, time
_run = sim.Apple.run
def run(self, maxsteps=400_000_000, until_idle=60):
    t = time.time(); c = self.cycles
    r = _run(self, maxsteps, until_idle)
    if self.cycles - c > 2_000_000: print('  [%.1fM instructions, %.0fs]' % ((self.cycles - c) / 1e6, time.time() - t))
    return r
sim.Apple.run = run
V = 'test/v10'; T = 'test/v10lo'; fresh(V); fresh(T)
def lo(src, fmt):
    subprocess.run(['soffice', '--headless', '--infilter=CSV:44,34,76,1,,1033,false,true',
                    '--convert-to', fmt, '--outdir', os.path.dirname(src), src], capture_output=True, timeout=300)
    return os.path.splitext(src)[0] + '.' + fmt
def body(name):
    l = lines(V, name); nf = int(l[1]); n = int(l[2 + nf])
    return l[2:2 + nf], [[v.strip('"') for v in l[3 + nf + k * nf:3 + nf + (k + 1) * nf]] for k in range(n)]
rnd = random.Random(5)
W = 'apple disk drive card monitor joystick manual box mouse keyboard serial clock printer modem'.split()
def phrase(n): return ' '.join(rnd.choice(W) for _ in range(n)).capitalize()[:56].strip()
def row(i):
    return [phrase(rnd.randint(2, 8)), phrase(rnd.randint(0, 9)), str(rnd.randint(-5000, 99999)),
            '%d.%02d' % (rnd.randint(0, 9999), rnd.randint(0, 99)),
            '19%02d-%02d-%02d' % (rnd.randint(70, 99), rnd.randint(1, 12), rnd.randint(1, 28)),
            rnd.choice(['Yes', 'No', ''])]
H = ['Name', 'Notes', 'Count', 'Price', 'Bought', 'Boxed']
F = [('Name', 'Text', 60, 1), ('Notes', 'Text', 60, 1), ('Count', 'Number', 0, 1),
     ('Price', 'Money', 0, 1), ('Bought', 'Date', 0, 1), ('Boxed', 'Yes/No', 0, 1)]
def csvfile(path, rows):
    with open(path, 'w', newline='') as f:
        w = csv.writer(f); w.writerow(H)
        for r in rows: w.writerow(r[:3] + ['$' + r[3]] + r[4:])

# 1. a big LibreOffice ODS (deflated with dynamic codes, long matches) -> new database
BIG = [row(i) for i in range(240)]
csvfile(T + '/big.csv', BIG)
shutil.copy(lo(T + '/big.csv', 'ods'), V + '/BIG.ODS')
print('BIG.ODS', os.path.getsize(V + '/BIG.ODS'), 'bytes')
a = start(V)
a.key('I', oa=True); a.run(); pick(a, 'BIG.ODS')
check('big ODS: offers a new database', 'Its 6 columns become' in a.plain())
a.key('\r'); a.run()
check('big ODS: 240 records', 'Imported 240 records.' in a.plain())
a.key('\r'); a.run(); a.key('S', oa=True); a.run(); a.key('BIG\r'); a.run()
hdr, got = body('BIG')
print(hdr)
check('big ODS: kinds', [h.split(',')[1] for h in hdr] == ['1', '1', '2', '3', '4', '5'])
bad = [(i, g, b) for i, (g, b) in enumerate(zip(got, BIG)) if g != b]
print(bad[:3])
check('big ODS: every record matches', len(got) == 240 and not bad)

# 2. Add from ODS with the aux pool well used (records above $3F00 are held in RETRODB.SWP)
DB = [row(i) for i in range(190)]
open(V + '/STOCK', 'wb').write(dbfile('STOCK', F, DB))
open(V + '/RETRODB.LAST', 'wb').write(b'STOCK\r')
ADD = [row(i) for i in range(40)]
csvfile(T + '/add.csv', ADD)
shutil.copy(lo(T + '/add.csv', 'ods'), V + '/ADD.ODS')
a = start(V)
a.key('I', oa=True); a.run(); pick(a, 'ADD.ODS'); a.key('A'); a.run()
show(a)
check('add ODS to a full aux pool: 40 records', 'Imported 40 records.' in a.plain())
a.key('\r'); a.run(); a.key('S', oa=True); a.run()
hdr, got = body('STOCK')
bad = [(i, g, b) for i, (g, b) in enumerate(zip(got, DB)) if g != b]
print(len(got), len(bad), bad[:2])
check('records already there survive the ODS reader', got[:190] == DB)
print(got[190:192], ADD[:2])
check('added records match', got[190:] == ADD)
check('RETRODB.SWP and RETRODB.TMP are removed', not os.path.exists(V + '/RETRODB.SWP') and not os.path.exists(V + '/RETRODB.TMP'))
# too many: the rest don't fit
a.key('I', oa=True); a.run(); pick(a, 'ADD.ODS'); a.key('A'); a.run()
check('over 250: says some rows did not fit', 'Imported 20 records.' in a.plain() and 'did not fit' in a.plain())
a.key('\r'); a.run()

# 3. a 64K Apple: ODS refused politely, CSV still works
shutil.copy(T + '/add.csv', V + '/ADD.CSV')
open(V + '/SMALL', 'wb').write(dbfile('SMALL', F, DB[:3]))
open(V + '/RETRODB.LAST', 'wb').write(b'SMALL\r')
a = start(V, mem128=False)
a.key('I', oa=True); a.run(); pick(a, 'ADD.ODS')
check('64K: ODS needs more memory', "There isn't memory to read an ODS" in a.plain())
a.key('\r'); a.run()
a.key('I', oa=True); a.run(); pick(a, 'ADD.CSV'); a.key('A'); a.run()
show(a)
check('64K: CSV import works, as far as memory goes', 'Imported' in a.plain())
a.key('\r'); a.run()

# 4. CSV dialects: semicolons + BOM + LF; tabs + CR; quoted separators
open(V + '/GAMES', 'wb').write(dbfile('GAMES', F, []))
open(V + '/RETRODB.LAST', 'wb').write(b'GAMES\r')
open(V + '/SEMI.CSV', 'wb').write('﻿Name;Price;Notes\n"A; b";"$1.234,5";"say ""hi"""\nCafé;3;x\n'.encode())
open(V + '/TABS.CSV', 'wb').write(b'Name\tCount\tBoxed\rOne\t12\ttrue\rTwo\t-3\tN\r')
a = start(V)
a.key('I', oa=True); a.run(); pick(a, 'SEMI.CSV'); a.key('\r'); a.run()
check('semicolons: 2 records', 'Imported 2 records.' in a.plain())
a.key('\r'); a.run()
a.key('I', oa=True); a.run(); pick(a, 'TABS.CSV'); a.key('A'); a.run()
check('tabs: 2 records', 'Imported 2 records.' in a.plain())
a.key('\r'); a.run(); a.key('S', oa=True); a.run()
hdr, got = body('GAMES')
print(got)
check('semicolon rows', got[0][0] == 'A; b' and got[0][1] == "say 'hi'" and got[1][0] == 'Caf?')
check('semicolon file: 1.234,5 is 1234.50', got[0][3] == '1234.50')
check('tab rows', got[2][0] == 'One' and got[2][2] == '12' and got[2][5] == 'Yes' and got[3][2] == '-3' and got[3][5] == 'No')
done()
