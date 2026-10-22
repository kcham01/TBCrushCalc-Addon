// Makes tests/fixtures/oracle.json: random characters (gear, gems, enchants, talents, buffs, consumables,
// cooldowns, boss) run through the app's own engine. tests/run.lua runs the same characters through the
// addon's Lua engine and checks every number matches.  node tools/oracle.mjs <app repo> [count]
import fs from 'node:fs';
import path from 'node:path';
import { buildApp } from './export_data.mjs';

const root = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const count = +(process.argv[3] || 400);
const { D, E, Sim, TR, St } = await buildApp();

// a seeded random generator, so the fixture is the same every time
let seed = 20261022;
const rand = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
const pick = a => a[Math.floor(rand() * a.length)];
const chance = p => rand() < p;

function randomTalents(cls) {
  const m = {};
  const trees = D.TALENTS[cls];
  const focus = Math.floor(rand() * 3);
  for (let guard = 0; guard < 400 && TR.spent(m) < 61; guard++) {
    const ti = chance(0.75) ? focus : Math.floor(rand() * 3);
    const t = pick(trees[ti].talents);
    if (TR.canAdd(cls, m, ti, t)) m[TR.key(ti, t)] = (m[TR.key(ti, t)] || 0) + 1;
  }
  if (chance(0.2)) for (const k of Object.keys(m)) if (chance(0.3)) delete m[k];   // some broken builds too
  return m;
}

function randomProfile(i) {
  const cls = pick(['warrior', 'paladin', 'druid']);
  const race = pick(Object.keys(D.BASES[cls]));
  const p = { v: 2, id: 'r' + i, name: 'Random ' + i, cls, race, gear: {}, talents: randomTalents(cls), buffs: {}, cons: {}, abil: {}, opts: { uses: {}, swing: 2, adds: 0 }, updated: 0 };
  const endgame = chance(0.7);
  for (const s of D.SLOTS) {
    if (chance(0.08)) continue;
    let pool = D.ITEMS.filter(it => D.slotAccepts(s.id, it) && D.canUse(cls, it, s.id) && (!endgame || (it.rl || 0) >= 65));
    if (s.id === 'offhand' && cls !== 'druid' && chance(0.8)) pool = pool.filter(it => it.wt === 'shield');
    if (!pool.length) continue;
    const it = pick(pool);
    const g = { id: it.id };
    if (it.so && chance(0.85)) {
      g.gems = it.so.map(c => {
        if (chance(0.1)) return 0;
        const pool2 = D.GEMS.filter(x => (c === 'meta') === (x.c === 'meta'));
        return pick(pool2).id;
      });
    }
    if (chance(0.7)) {
      const ok = D.ENCHANTS.filter(e => !D.enchantProblem(e, it, cls));
      if (ok.length) g.ench = pick(ok).k;
    }
    p.gear[s.id] = g;
  }
  // buffs inserted in the addon's list order, so "doesn't stack" ties resolve the same way in both
  for (const b of [...D.RAID_BUFFS, ...D.DEBUFFS, ...D.WORLD_BUFFS]) if (chance(0.3)) p.buffs[b.id] = b.imp && chance(0.5) ? 2 : 1;
  const cat = c => D.CONSUMABLES.filter(x => x.c === c);
  if (chance(0.5)) p.cons.flask = pick(cat('flask')).id;
  if (chance(0.5)) p.cons.battle = pick(cat('battle')).id;
  if (chance(0.5)) p.cons.guardian = pick(cat('guardian')).id;
  if (chance(0.6)) p.cons.food = pick(cat('food')).id;
  if (chance(0.4)) p.cons.potion = pick(cat('potion')).id;
  if (chance(0.4)) { const gs = [...new Set(cat('scroll').map(x => x.g))]; p.cons.scrolls = gs.filter(() => chance(0.4)).map(g => pick(cat('scroll').filter(x => x.g === g)).id); }
  for (const a of D.ABILITIES[cls]) if (chance(0.6)) p.abil[a.id] = true;
  for (const s of ['trinket1', 'trinket2']) { const g = p.gear[s]; if (g && chance(0.6)) p.opts.uses[String(g.id)] = true; }
  if (chance(0.7)) p.opts.boss = pick(D.BOSSES).id;
  p.opts.swing = pick([1.2, 1.5, 2, 2.4, 3]);
  p.opts.adds = chance(0.7) ? 0 : Math.floor(rand() * 4);
  return p;
}

const pickSheet = s => {
  const out = {};
  for (const k in s) {
    const v = s[k];
    if (typeof v === 'number' || typeof v === 'boolean') out[k] = v;
  }
  out.resist = s.resist;
  out.rangedDmg = s.rangedDmg;
  out.parts = s.parts;
  out.setBonuses = s.gear.setBonuses;
  out.metaActive = s.gear.meta ? s.gear.meta.active : null;
  out.socketsMatched = s.gear.socketsMatched;
  out.uniqueClash = s.gear.uniqueClash;
  out.usesOn = s.usesOn;
  return out;
};
const finite = v => (Number.isFinite(v) ? v : 1e300);

const cases = [];
for (let i = 0; i < count; i++) {
  const p = randomProfile(i);
  const bc = E.bossCtx(p);
  const res = { bc, modes: {} };
  for (const m of ['passive', 'cooldown', 'procs']) {
    const s = E.computeSheet(p, m);
    const t = E.bossTable(s, bc);
    const dm = E.intake(s, bc, t);
    dm.hitsToKill = finite(dm.hitsToKill);
    res.modes[m] = { sheet: pickSheet(s), table: t, cap: E.capFor(s, bc), capValues: E.capValues(s, bc), critCap: E.critCap(s, bc), shear: E.shear(s, bc), intake: dm, verdict: E.verdict(p, m) };
  }
  res.coverage = Sim.coverage(p);
  res.treePoints = E.treePoints(p);
  res.valid = TR.valid(p.cls, p.talents);
  res.code = St.exportCode(p);
  cases.push({ p, res });
}
// auto-gear for every class and phase, and the example characters' builds
const autoGear = {};
for (const cls of ['warrior', 'paladin', 'druid']) for (const ph of [1, 2, 3, 4, 5]) {
  autoGear[`${cls}.${ph}`] = St.autoGear({ cls, race: Object.keys(D.BASES[cls])[0], gear: {}, talents: {}, buffs: {}, cons: {}, abil: {}, opts: { uses: {} } }, ph);
}
fs.mkdirSync(path.join(root, 'tests', 'fixtures'), { recursive: true });
fs.writeFileSync(path.join(root, 'tests', 'fixtures', 'oracle.json'), JSON.stringify({ cases, autoGear }));
fs.copyFileSync(path.join(path.resolve(process.argv[2] || '../bigcrazyworld'), 'tests', 'fixtures', 'wowsims.json'), path.join(root, 'tests', 'fixtures', 'wowsims.json'));
console.log(`${cases.length} characters, ${(fs.statSync(path.join(root, 'tests', 'fixtures', 'oracle.json')).size / 1e6).toFixed(1)} MB`);
