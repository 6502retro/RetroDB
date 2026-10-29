import sys, re, os, shutil
sys.path.insert(0, 'tools')
from sim import boot
def plain(a): return a.plain()
def rows(a, r0, r1): return '\n'.join(a.plain().split('\n')[r0:r1])
def fresh(v, files=()):
    shutil.rmtree(v, ignore_errors=True); os.makedirs(v)
    for f in files: shutil.copy(f, v + '/' + os.path.basename(f))
def start(vol='test/vol', **kw):
    # memory starts full of junk, as on a real Apple (SIM_GARBAGE=0 for zeros)
    kw.setdefault('garbage', os.environ.get('SIM_GARBAGE', '7') if os.environ.get('SIM_GARBAGE', '7') != '0' else None)
    a = boot('build/RETRODB.SYSTEM', vol, **kw); a.run(); a.key(' '); a.run(); return a
def show(a):
    print(a.plain()); print('-' * 80)
KINDS = {'Text': 1, 'Number': 2, 'Money': 3, 'Date': 4, 'Yes/No': 5, 'No.': 6, 'Part Of': 7}
def design(a, fields, ok=True):
    """fields: (name, kind, length, inlist) typed into the Design Form window,
    starting on the new (blank) row"""
    for (name, kind, ln, lst) in fields:
        a.key(name); a.key('\t')
        for _ in range(KINDS[kind] - 1): a.key(0x15)
        a.key('\t')
        if kind == 'Text':
            a.key(0x18); a.key(str(ln)); a.key('\t')
        if not lst: a.key(' ')
        a.key('\t')
        a.run()
    if ok: a.key('\r')
    a.run()
def newrec(a, values):
    """values typed in field order; Yes/No values are 'Y', 'N' or ''"""
    a.key('N', oa=True); a.run()
    for v in values:
        if v: a.key(v)
        a.key('\t')
    a.key('\r'); a.run()
fails = []
def check(what, ok):
    print(('PASS ' if ok else 'FAIL ') + what)
    if not ok: fails.append(what)
def done():
    print('\n%d failed' % len(fails) + (': ' + '; '.join(fails) if fails else ''))
    sys.exit(1 if fails else 0)
def dbfile(name, fields, records):
    """write a RETRODB1 file: fields = [(name, kind, len, list)], records = [[str]]"""
    out = ['RETRODB1', str(len(fields))]
    for (n, k, l, s) in fields: out.append('"%s",%d,%d,%d' % (n, KINDS[k], l, s))
    out.append(str(len(records)))
    for r in records: out += ['"%s"' % v for v in r]
    return ('\r'.join(out) + '\r').encode()
def lines(v, n): return open(v + '/' + n, 'rb').read().decode().split('\r')
def menu(a, m, i):
    """choose item i of menu m (0 Apple, 1 File, 2 Record, 3 Sort, 4 View) from the keyboard"""
    a.key(0x1B)
    for _ in range(m - 1 if m >= 1 else 0): a.key(0x15)
    if m == 0: a.key(0x08)
    for _ in range(i): a.key(0x0A)
    a.key('\r'); a.run()
def listrows(a, n=17):
    return [r[1:78].rstrip() for r in a.plain().split('\n')[4:4 + n]]
def pick(a, name):
    """choose name in an Open/Import list (the list starts on row 6)"""
    rs = a.plain().split('\n')
    names = []
    for y in range(6, 21):
        t = rs[y][24:41].replace('\u2196', ' ').split()
        if len(t) != 1: break
        names.append(t[0])
    assert name in names, (name, names)
    for _ in range(names.index(name)): a.key(0x0A)
    a.key('\r'); a.run()
