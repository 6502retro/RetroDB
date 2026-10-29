"""Screenshots for the manual, taken in the simulator with the sample databases."""
import sys, os, shutil
sys.path.insert(0, 'test'); sys.path.insert(0, 'tools')
from common import *
from sim import boot
from PIL import Image, ImageDraw
V = 'test/vs'; OUT = sys.argv[1] if len(sys.argv) > 1 else 'manual'
def bezel(src, dst):
    im = Image.open(src).convert('RGBA'); w, h = im.size
    c = Image.new('RGBA', (w + 44, h + 44), (0, 0, 0, 0))
    ImageDraw.Draw(c).rounded_rectangle([10, 10, w + 33, h + 33], radius=16, fill=(42, 42, 42, 255))
    c.paste(im, (22, 22)); c.save(dst)
def shot(a, name):
    a.png(OUT + '/' + name + '.png'); bezel(OUT + '/' + name + '.png', OUT + '/fig-' + name + '.png')
os.makedirs(OUT, exist_ok=True)
fresh(V)
for n in os.listdir('build/samples'): shutil.copy('build/samples/' + n, V + '/' + n)
if os.path.exists('build/COLLECT.MC'): shutil.copy('build/COLLECT.MC', V + '/COLLECT.MC')
open(V + '/RETRODB.LAST', 'wb').write(b'COLLECTION\r')
a = boot('build/RETRODB.SYSTEM', V, prefix='/RETRODB/', startpath='/RETRODB/RETRODB.SYSTEM')
a.types['COLLECT.MC'] = 0xF8
a.run(); a.key(' '); a.run()
for _ in range(5): a.key(0x0A)
a.run(); a.mouse_to(74, 21); a.run(); shot(a, 'main')
a.key(0x1B); a.key(0x15); a.key(0x0A); a.key(0x0A); a.key(0x0A); a.run(); shot(a, 'menu')
a.key(0x1B); a.run()
a.key('\r'); a.run(); a.key(0x0A); a.run(); shot(a, 'edit'); a.key(0x1B); a.run()
menu(a, 1, 5); a.key(0x0A); a.key(0x0A); a.key('\t'); a.run(); shot(a, 'design'); a.key(0x1B); a.run()
a.key('L', oa=True); a.run(); a.key('\t\t\t\t>=1984\t\t\t>100'); a.run(); shot(a, 'select')
a.key('\r'); a.run(); shot(a, 'selected')
a.key('A', oa=True); a.run()
a.key('R', oa=True); a.run(); shot(a, 'report'); a.key('\r'); a.run()
a.key('X', oa=True); a.run(); shot(a, 'export'); a.key(0x1B); a.run()
a.key('I', oa=True); a.run(); shot(a, 'import'); a.key(0x1B); a.run()
a.key('O', oa=True); a.run(); shot(a, 'open'); a.key(0x1B); a.run()
menu(a, 3, 0); a.key('Q', oa=True); a.run(); shot(a, 'savech')
shutil.copy('build/splash.png', OUT + '/splash.png'); bezel(OUT + '/splash.png', OUT + '/fig-splash.png')
print('ok')
