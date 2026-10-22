// Opens the share codes the addon made (build/addon_codes.json, written by tests/run.lua) with the app's
// own importCode, so a code copied from the game works in the phone app.  node tools/check_codes.mjs <app repo>
import fs from 'node:fs';
import { buildApp } from './export_data.mjs';
const { St } = await buildApp();
const codes = JSON.parse(fs.readFileSync('build/addon_codes.json', 'utf8'));
const oracle = JSON.parse(fs.readFileSync('tests/fixtures/oracle.json', 'utf8'));
let bad = 0;
codes.forEach((c, i) => {
  const p = St.importCode(c);
  const want = oracle.cases[i].p;
  const strip = x => { const y = JSON.parse(JSON.stringify(x)); delete y.id; delete y.updated; return y; };
  const norm = x => JSON.stringify(x, Object.keys(x).sort());
  const deep = x => JSON.stringify(x, (k, v) => (v && typeof v === 'object' && !Array.isArray(v) ? Object.fromEntries(Object.keys(v).sort().map(kk => [kk, v[kk]])) : v));
  if (!p || deep(strip(p)) !== deep(strip(want))) { bad++; if (bad < 4) console.log('code', i, 'differs'); }
  void norm;
});
console.log(`${codes.length} addon codes opened in the app, errors ${bad}`);
if (bad) process.exitCode = 1;
