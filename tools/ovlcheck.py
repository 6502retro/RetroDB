"""Check that nothing outside an overlay uses a label the overlay defines
(the overlay isn't in memory then)."""
import re, glob, sys
defs = {}
for f in glob.glob('src/ov_*.s'):
    for line in open(f):
        m = re.match(r'(?<!@)^([A-Za-z_][A-Za-z0-9_]*)\s*:', line)
        if m: defs[m.group(1)] = f
bad = 0
for f in glob.glob('src/*.s'):
    for n, line in enumerate(open(f), 1):
        code = line.split(';')[0]
        code = re.sub(r'"[^"]*"', '', code)
        for w in re.findall(r'(?<![@\w])[A-Za-z_][A-Za-z0-9_]*\b', code):
            if w in defs and defs[w] != f and not re.match(r'\s*' + w + r'\s*:', code):
                print('%s:%d uses %s from %s' % (f, n, w, defs[w])); bad += 1
sys.exit(1 if bad else 0)
