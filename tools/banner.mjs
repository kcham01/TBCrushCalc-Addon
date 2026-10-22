// Renders docs/banner.png (the README banner) from HTML in headless Chromium: node tools/banner.mjs <app repo>
// Uses the app's icon and fonts.
import fs from 'node:fs'; import path from 'node:path';
let chromium;
try { ({ chromium } = await import('playwright')); } catch { ({ chromium } = await import('/opt/node-tools/node_modules/playwright/index.mjs')); }
const root = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const app = path.resolve(process.argv[2] || '../bigcrazyworld');
const b64 = f => fs.readFileSync(path.join(app, f)).toString('base64');
const font = f => `url(data:font/woff2;base64,${b64('node_modules/@fontsource/' + f)})`;
const slots = n => Array.from({ length: n }, (_, i) => `<i style="border-color:${['#a335ee', '#0070dd', '#a335ee', '#a335ee', '#ff8000', '#a335ee', '#0070dd', '#a335ee'][i % 8]}"></i>`).join('');
const html = `<!doctype html><html><head><style>
@font-face { font-family: Cinzel; font-weight: 700; src: ${font('cinzel/files/cinzel-latin-700-normal.woff2')}; }
@font-face { font-family: Inter; font-weight: 400; src: ${font('inter/files/inter-latin-400-normal.woff2')}; }
@font-face { font-family: Inter; font-weight: 700; src: ${font('inter/files/inter-latin-700-normal.woff2')}; }
html,body{margin:0;width:1280px;height:640px;overflow:hidden;background:#05070d}
.b{position:relative;width:1280px;height:640px;box-sizing:border-box;padding:70px 90px;
 background: radial-gradient(ellipse at 78% 30%, rgba(120,70,200,.35), transparent 55%), radial-gradient(ellipse at 15% 85%, rgba(30,160,120,.25), transparent 50%),
 radial-gradient(circle at 60% 120%, rgba(255,120,40,.18), transparent 45%), linear-gradient(160deg,#0b1020,#05070d 70%);}
.stars{position:absolute;inset:0;background-image:radial-gradient(1px 1px at 20% 30%,#fff8,transparent),radial-gradient(1px 1px at 70% 10%,#fff6,transparent),radial-gradient(1.5px 1.5px at 85% 60%,#fff7,transparent),radial-gradient(1px 1px at 40% 80%,#fff5,transparent),radial-gradient(1px 1px at 10% 60%,#fff6,transparent),radial-gradient(1px 1px at 55% 45%,#fff4,transparent)}
.left{position:relative;width:640px}
.tag{font:700 20px Inter;letter-spacing:.18em;color:#7fe0c4;text-transform:uppercase}
h1{margin:10px 0 0;font:700 92px Cinzel;color:#ffd100;text-shadow:0 3px 0 #000,0 0 34px rgba(255,209,0,.3)}
p{margin:14px 0 28px;font:400 29px/1.35 Inter;color:#e9e2d0}
.cmd{display:inline-block;font:700 26px Consolas,monospace;color:#1eff00;background:rgba(0,0,0,.6);padding:10px 18px;border-radius:6px;box-shadow:inset 0 0 0 2px #2e5a2a}
.chips{display:flex;gap:10px;margin-top:22px}
.chip{font:700 20px Inter;padding:8px 16px;border-radius:22px;color:#ffd100;background:rgba(0,0,0,.5);box-shadow:inset 0 0 0 2px #6b4a1c}
.win{position:absolute;right:80px;top:60px;width:380px;height:520px;border-radius:10px;background:#100d0a;
 box-shadow:0 0 0 3px #8a7550,0 0 0 5px #2a2216,0 0 0 6px #000,0 25px 60px rgba(0,0,0,.8);transform:rotate(2deg)}
.win .top{display:flex;align-items:center;gap:12px;padding:16px}
.win .top img{width:46px;height:46px;border-radius:6px}
.win .nm{font:700 22px Cinzel;color:#F58CBA}.win .sub{font:400 13px Inter;color:#ccc}
.win .v{margin-left:auto;font:700 18px Inter;color:#fff;padding:6px 10px;border:2px solid #1eaa10;border-radius:6px;background:#0c3008;text-align:center}
.win .v small{display:block;font:700 10px Inter;color:#1eff00}
.doll{display:grid;grid-template-columns:44px 1fr 44px;gap:10px;padding:0 16px}
.col{display:grid;gap:6px}.col i{display:block;width:40px;height:40px;border:2px solid;border-radius:4px;background:radial-gradient(#3a2d1d,#120d08);box-shadow:0 0 8px rgba(163,53,238,.35)}
.mid{border:1px solid #4b3a22;border-radius:6px;background:radial-gradient(ellipse at 50% 40%,#2a2040,#0b0907);display:flex;flex-direction:column;align-items:center;justify-content:flex-end;padding:10px}
.fig{width:90px;height:190px;margin-bottom:auto;margin-top:30px;background:radial-gradient(circle at 50% 12%,#8a7aa0 18%,transparent 19%),linear-gradient(#8a7aa0,#8a7aa0) 50% 60%/40% 55% no-repeat;opacity:.85}
.verd{width:100%;text-align:center;border:2px solid #1eaa10;border-radius:6px;background:#0c3008;color:#1eff00;font:700 20px Cinzel;padding:8px 0}
.bar{position:absolute;left:90px;width:560px;bottom:70px;height:14px;display:flex;border-radius:3px;overflow:hidden;box-shadow:0 0 0 2px #000,0 0 0 4px #4b3a22}
</style></head><body><div class="b"><div class="stars"></div>
<div class="left"><div class="tag">In-game addon - TBC Anniversary</div><h1>TBCrushCalc</h1>
<p>The crush cap calculator and tank gear planner, inside World of Warcraft.</p>
<span class="cmd">/tbcc</span>
<div class="chips"><span class="chip" style="color:#C79C6E">Warrior</span><span class="chip" style="color:#F58CBA">Paladin</span><span class="chip" style="color:#FF7D0A">Druid</span></div></div>
<div class="win"><div class="top"><img src="data:image/png;base64,${b64('web/icon.png')}"><div><div class="nm">Tankadin</div><div class="sub">Blood Elf Paladin - 0 / 51 / 10</div></div><div class="v">102.6%<small>UNCRUSHABLE</small></div></div>
<div class="doll"><div class="col">${slots(8)}</div><div class="mid"><svg viewBox="0 0 100 120" style="width:150px;margin:auto 0"><path d="M50 4 L92 18 C92 62 76 96 50 116 C24 96 8 62 8 18 Z" fill="#3a1d0e" stroke="#ffd100" stroke-width="4"/><path d="M50 20 L78 30 C78 62 67 86 50 100 C33 86 22 62 22 30 Z" fill="#8a1410"/><path d="M50 30 V92 M32 52 H68" stroke="#ffd100" stroke-width="6"/></svg><div class="verd">Uncrushable</div></div><div class="col">${slots(8)}</div></div></div>
<div class="bar"><span style="width:10.5%;background:#8d8d8d"></span><span style="width:19.8%;background:#3aa0ff"></span><span style="width:11.3%;background:#b06bff"></span><span style="width:58.4%;background:#e8c548"></span></div>
</div></body></html>`;
const br = await chromium.launch(process.env.PW_CHROMIUM ? { executablePath: process.env.PW_CHROMIUM } : {});
const pg = await br.newPage({ viewport: { width: 1280, height: 640 } });
await pg.setContent(html);
await pg.waitForTimeout(300);
await pg.screenshot({ path: path.join(root, 'docs/banner.png') });
await br.close();
console.log('banner written');
