// 1024x1024 promotional images for the promoted in-app purchases. No price, no "free".
//   node Store/art/promo.mjs <raw shots dir> <out dir>
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, existsSync, mkdirSync } from "fs";

const [raw, out] = process.argv.slice(2);
mkdirSync(out, { recursive: true });
const img = (f) => (existsSync(`${raw}/${f}`) ? `data:image/png;base64,${readFileSync(`${raw}/${f}`).toString("base64")}` : "");
const crown = `<svg viewBox="0 0 100 80" width="300"><path fill="#fdc73d" stroke="#121f38" stroke-width="5" stroke-linejoin="round" d="M8 70 L4 18 L30 40 L50 6 L70 40 L96 18 L92 70 Z"/><rect x="8" y="64" width="84" height="12" rx="4" fill="#fdc73d" stroke="#121f38" stroke-width="5"/></svg>`;
const items = {
  "club-yearly": `<div class="c">${crown}<div class="t1">STRAIT CLUB</div><div class="t2">YEARLY</div></div>`,
  "club-monthly": `<div class="c">${crown}<div class="t1">STRAIT CLUB</div><div class="t2">MONTHLY</div></div>`,
  "pack": `<div class="shot" style="background-image:url(${img("pack.png")});background-position:50% 38%"></div><div class="band">THE BLOWHARD PACK</div>`,
  "trails": `<div class="shot" style="background-image:url(${img("trails.png")});background-position:50% 45%"></div><div class="band">TRAIL PACK</div>`,
};
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
for (const [name, html] of Object.entries(items)) {
  await p.setContent(`<!doctype html><html><head>
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@900&display=block" rel="stylesheet"><style>
body{margin:0;width:1024px;height:1024px;overflow:hidden;font-family:Nunito,sans-serif;background:radial-gradient(circle at 50% 35%,#2aa6db,#106ba3 55%,#0b3f66)}
.c{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center}
.t1{margin-top:40px;color:#f0fcff;font-weight:900;font-size:110px;letter-spacing:4px;text-shadow:0 8px 0 rgba(18,31,56,.35)}
.t2{margin-top:10px;background:#fdc73d;color:#121f38;font-weight:900;font-size:64px;letter-spacing:6px;padding:10px 40px;border-radius:60px}
.shot{position:absolute;inset:0 0 200px 0;background-size:150% auto;background-repeat:no-repeat}
.band{position:absolute;left:0;right:0;bottom:0;height:200px;background:#121f38;color:#fdc73d;font-weight:900;font-size:84px;letter-spacing:3px;display:flex;align-items:center;justify-content:center}
</style></head><body>${html}</body></html>`);
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(300);
  await p.screenshot({ path: `${out}/${name}.png` });
  console.log(name);
}
await b.close();
