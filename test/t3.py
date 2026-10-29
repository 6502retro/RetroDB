# MouseDB: changing the form of a database full of records
import sys, random; sys.path.insert(0, 'test')
from common import *
V = 'test/v3'; fresh(V)
random.seed(7)
def word(n): return ''.join(random.choice('abcdefghij klmnop') for _ in range(n)).strip() or 'x'
F = [('Name', 'Text', 50, 1), ('Code', 'Text', 8, 1), ('Qty', 'Number', 0, 1), ('Cost', 'Money', 0, 1),
     ('Note', 'Text', 56, 0), ('More', 'Text', 56, 0), ('Day', 'Date', 0, 1), ('Ok', 'Yes/No', 0, 1)]
# record size 51+9+4+4+57+57+11+1 = 194: too many for aux, so the rest spill into pool B
R = []
for i in range(245):
    R.append(['Item %03d %s' % (i, word(20)), str(random.randint(0, 99999)), str(random.randint(-500, 500)),
              '%d.%02d' % (random.randint(0, 9999), random.randint(0, 99)), word(50), word(40),
              '19%02d-%02d-%02d' % (random.randint(0, 99), random.randint(1, 12), random.randint(1, 28)),
              random.choice(['Yes', 'No', ''])])
open(V + '/BIG', 'wb').write(dbfile('BIG', F, R))
open(V + '/MOUSEDB.LAST', 'wb').write(b'BIG\r')
a = start(V)
check('245 records loaded', '245 of 250 records' in rows(a, 22, 23))
L = {}
for line in open('build/mousedb.lbl'):
    _, v, n = line.split(); L[n[1:]] = int(v, 16)
bk = [a.main[L['PTRBK'] if 'PTRBK' in L else 0x0A00 + i] for i in range(200)]
bk = list(a.main[0x0A00:0x0A00 + 245]); hi = list(a.main[0x0900:0x0900 + 245])
check('records in aux and then main pool B', bk[1] == 1 and bk[-1] == 0 and hi[-1] >= 0x90)
def saved():
    a.key('S', oa=True); a.run()
    l = lines(V, 'BIG'); nf = int(l[1]); n = int(l[2 + nf])
    hdr = l[2:2 + nf]; body = l[3 + nf:3 + nf + n * nf]
    return hdr, [[v.strip('"') for v in body[k * nf:(k + 1) * nf]] for k in range(n)]
# scramble the record order first: sort by Code, delete a few
menu(a, 3, 1)
for k in (5, 17, 60):
    a.key('F', oa=True); a.run(); a.key(0x18); a.key('Item %03d\r' % k); a.run()
    a.key('D', oa=True); a.run(); a.key('\r'); a.run()
R2 = sorted([r for i, r in enumerate(R) if i not in (5, 17, 60)], key=lambda r: r[1].upper())
hdr, got = saved()
check('242 records after deleting 3', len(got) == 242)
check('sorted by Code (as text)', [g[1] for g in got] == [r[1] for r in R2])
check('values survive a save', got == R2)
R2 = got
# 1. grow: insert a field at the top, make Code longer -> bigger records
#    (198 bytes: 237 fit in aux, the other 5 in main memory)
menu(a, 1, 5)            # Design Form
a.key('I', oa=True); a.key('Serial\t\t'); a.key(0x18); a.key('2\t\t')    # new first field
a.key(0x0A); a.key('\t\t'); a.key(0x18); a.key('9'); a.run()             # Code: 8 -> 9
a.key('\r'); a.run()
check('growing asks nothing when nothing is lost', 'This changes all' not in a.plain())
hdr, got = saved()
check('new header', hdr[0] == '"Serial",1,2,1' and hdr[2] == '"Code",1,9,1' and len(hdr) == 9)
check('values kept after growing', [g[1:] for g in got] == R2 and all(g[0] == '' for g in got))
bk = list(a.main[0x0A00:0x0A00 + 242])
check('records still use aux and main memory', 1 in bk and 0 in bk)
# 2. shrink: delete Note and More, Name 50 -> 10 (cuts), Qty -> Text, Code -> Number
menu(a, 1, 5)
for _ in range(5): a.key(0x0A)
a.key('D', oa=True); a.key('D', oa=True)                    # Note, More
a.key(0x0B); a.key(0x0B); a.key(0x0B); a.key(0x0B)          # Name (row 1)
a.key('\t\t'); a.key(0x18); a.key('10')
a.key('\t\t\t'); a.key(0x15)                                 # Code: Text -> Number
a.key('\t\t\t'); a.key(0x08)                                 # Qty: Number -> Text
a.key('\t\t'); a.key(0x18); a.key('20')                      #      20 characters
a.run()
a.key('\r'); a.run()
check('shrinking asks first', 'This changes all 242 records' in a.plain())
a.key('\r'); a.run()
hdr, got = saved()
check('header after shrinking: %s' % hdr, hdr == ['"Serial",1,2,1', '"Name",1,10,1', '"Code",2,10,1', '"Qty",1,20,1', '"Cost",3,12,1', '"Day",4,10,1', '"Ok",5,3,1'])
exp = [['', r[0][:10].rstrip(), str(int(r[1])), r[2], r[3], r[6], r[7]] for r in R2]
bad = [(g, e) for g, e in zip(got, exp) if g != e]
check('values converted (cut, number <-> text): %d differ %s' % (len(bad), bad[:2]), not bad)
# 3. type change that can't convert: Name (text) -> Money: values become blank
menu(a, 1, 5); a.key(0x0A); a.key('\t'); a.key(0x15); a.key(0x15); a.key('\r'); a.run()
a.key('\r'); a.run()
hdr, got = saved()
check('text that is not money becomes blank', hdr[1] == '"Name",3,12,1' and all(g[1] == '' for g in got))
# 4. too big to fit: make records long enough that 197 don't fit
menu(a, 1, 5)
a.key(0x0B)                                                 # the new row
for nm in ('A1', 'A2', 'A3'):
    a.key(nm + '\t\t'); a.key(0x18); a.key('56\t\t')
a.key('\r'); a.run()
check('refused when the records would not fit', 'With this form only' in a.plain() and 'there are 242' in a.plain())
a.key('\r'); a.run(); a.key(0x1B); a.run()
check('form unchanged after refusing', saved()[0][1] == '"Name",3,12,1')
# 5. a record longer than 255 bytes
menu(a, 1, 5); a.key(0x0B)
for nm in ('B1', 'B2', 'B3', 'B4', 'B5'):
    a.key(nm + '\t\t'); a.key(0x18); a.key('56\t\t')
a.run()
check('size line warns over 255', '>255' in a.plain())
a.key('\r'); a.run()
check('refused: longer than 255 bytes', 'longer than 255' in a.plain())
a.key('\r'); a.run(); a.key(0x1B); a.run()
# 6. names: empty and duplicate
menu(a, 1, 5); a.key(0x0A); a.key(0x18); a.key('\r'); a.run()
check('empty name refused', 'Please give every field a name' in a.plain())
a.key('\r'); a.run(); a.key('code\r'); a.run()
check('duplicate name refused (any case)', 'Two fields have the same name' in a.plain())
a.key('\r'); a.run(); a.key(0x1B); a.run()
# editing the record in main memory, then drawing records in aux memory
# (a smaller form, so that pool A holds the first record)
F2 = F[:5] + [('More', 'Text', 12, 0)] + F[6:]
fresh(V); open(V + '/BIG', 'wb').write(dbfile('BIG', F2, R[:20])); open(V + '/MOUSEDB.LAST', 'wb').write(b'BIG\r')
a = start(V)
check('record 0 is in main memory, record 1 in aux', a.main[0x0A00] == 0 and a.main[0x0A01] == 1)
a.key('\r'); a.run(); a.key('\t\t'); a.key(0x18); a.key('8\r'); a.run()
L = listrows(a, 3)
check('after editing it the other rows are right: %s' % L[1][:12], L[0].startswith('Item 000') and L[1].startswith('Item 001') and L[2].startswith('Item 002'))
done()
