"""Turn out-of-range short branches reported by ca65 into long ones (jeq...)."""
import re, subprocess, sys
for it in range(20):
    r = subprocess.run(['./build.sh'], capture_output=True, text=True)
    errs = re.findall(r'(src/\w+\.s)\((\d+)\): Error: Range error', r.stdout + r.stderr)
    if not errs:
        print((r.stdout + r.stderr)[-1500:])
        break
    files = {}
    for f, ln in errs:
        files.setdefault(f, set()).add(int(ln))
    for f, lns in files.items():
        L = open(f).read().split('\n')
        for ln in lns:
            s = L[ln - 1]
            m = re.match(r'^(\S*\s+)(b(eq|ne|cc|cs|mi|pl|vc|vs))(\s+)', s)
            if not m:
                print('cannot fix', f, ln, s); sys.exit(1)
            if m.group(2) in ('bvc', 'bvs'):
                print('cannot fix', f, ln, s); sys.exit(1)
            L[ln - 1] = s[:m.start(2)] + 'j' + m.group(2)[1:] + s[m.end(2):]
        open(f, 'w').write('\n'.join(L))
    print('fixed', sum(len(v) for v in files.values()))
