// Build Mouse Calc sheets for the import tests (cells as JSON on the command line)
// usage: node mcmake.js out.sheet '[[r,c,"text"],[r,c,number,fmt],[r,c,"=SUM(B2:B4)",fmt]]'
const M = require('./mclib.js'), fs = require('fs');
M.setTemplateHeader(fs.readFileSync(__dirname + '/../tools/mcsamples/SAMPLE.BILL'));
const spec = JSON.parse(process.argv[3]);
const cells = spec.map(([r, c, v, fmt = 0]) => {
  if (typeof v === 'number') return { r, c, kind: 'number', value: v, fmt };
  if (v.startsWith('=')) {
    const ast = M.parseExcel(v);
    const tok = M.formulaTokens(ast);
    return { r, c, kind: 'formula', tokens: tok, value: 0, fmt };
  }
  return { r, c, kind: 'text', text: v, fmt };
});
fs.writeFileSync(process.argv[2], M.buildFile({ cells }));
