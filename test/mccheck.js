// Read a Mouse Calc sheet: print its cells, check that the converter's own
// writer rebuilds it byte for byte, and evaluate its formulas.
const M = require('./mclib.js'), fs = require('fs');
const f = fs.readFileSync(process.argv[2]);
M.setTemplateHeader(fs.readFileSync(__dirname + '/../tools/mcsamples/SAMPLE.BILL'));
const s = M.parseFile(f);
console.log('maxRow', s.maxRow, 'maxCol', s.maxCol, 'cells', s.cells.length);
console.log('widths', s.widths.slice(1, s.maxCol + 1).join(','));
console.log('positions', Array.from(s.header.slice(0xA8, 0xA8 + s.maxCol)).join(','));
const grid = {};
for (const c of s.cells) {
  const v = c.kind === 'text' ? JSON.stringify(c.text) : c.kind === 'formula' ? `${c.mc}=${c.value}` : c.value + (c.fmt ? '/f' + c.fmt : '');
  grid[c.r + ',' + c.c] = v;
  if (c.parseError) console.log('PARSE ERROR', c.r, c.c, c.parseError);
}
for (let r = 1; r <= s.maxRow; r++) {
  const row = []; for (let c = 1; c <= s.maxCol; c++) row.push(grid[r + ',' + c] ?? '');
  console.log(r, row.join(' | '));
}
const rebuilt = M.buildFile({ widths: s.widths, cells: s.cells, maxRow: s.maxRow, maxCol: s.maxCol });
console.log('rebuilt identical:', Buffer.compare(Buffer.from(rebuilt), f) === 0, rebuilt.length, f.length);
const get = (r, c) => { const x = s.cells.find(k => k.r === r && k.c === c); return x ? (x.kind === 'text' ? x.text : x.value) : undefined; };
for (const c of s.cells.filter(k => k.kind === 'formula')) console.log('eval', M.cellName(c.r, c.c), M.evaluate(c.ast, get), 'cached', c.value);
