// Game Center achievement images, one per medal: 1024x1024 PNG on the game's sea and sun.
//   node Store/art/medals.mjs <out dir>
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { mkdirSync } from "fs";

const out = process.argv[2];
mkdirSync(out, { recursive: true });
// medal id, big glyph, small caption
const medals = [
  ["first", "1", "CLEARED"], ["combo15", "x15", "IN THE GROOVE"], ["combo30", "x30", "METRONOME"],
  ["tremendous", "!!!", "TREMENDOUS"], ["needle", "15", "NEEDLE"], ["quick", "50s", "QUICK SHOVE"],
  ["far", "30K", "LONG HAUL"], ["moon", "100K", "MOONSHOT"], ["ships", "25", "HARBOUR MASTER"],
  ["rounds10", "10", "REGULAR"], ["rounds50", "50", "OLD SALT"], ["daily", "D", "DAILY DRIVER"],
  ["streak7", "7", "WEEK STREAK"], ["season", "\u2605", "FULL SEASON"],
];
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
for (const [id, glyph, cap] of medals) {
  const size = glyph.length >= 4 ? 245 : glyph.length === 3 ? 330 : 470;
  await p.setContent(`<!doctype html><html><head>
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@900&display=block" rel="stylesheet">
<style>
body{margin:0;width:1024px;height:1024px;background:radial-gradient(circle at 50% 40%,#2aa6db 0%,#106ba3 55%,#0b3f66 100%);font-family:Nunito,sans-serif;display:flex;align-items:center;justify-content:center;overflow:hidden}
.m{width:760px;height:760px;border-radius:50%;background:radial-gradient(circle at 38% 30%,#ffe9a3 0%,#fdc73d 45%,#e3a51c 100%);box-shadow:0 0 0 26px #121f38,0 0 0 40px rgba(253,199,61,.55),0 40px 80px rgba(0,0,0,.45);display:flex;flex-direction:column;align-items:center;justify-content:center;position:relative}
.m:before{content:"";position:absolute;inset:44px;border-radius:50%;border:12px dashed rgba(18,31,56,.28)}
.g{font-weight:900;color:#121f38;font-size:${size}px;line-height:1;letter-spacing:-6px;margin-top:-20px}
.c{font-weight:900;color:#121f38;font-size:58px;letter-spacing:4px;margin-top:18px;opacity:.85}
</style></head><body><div class="m"><div class="g">${glyph}</div><div class="c">${cap}</div></div></body></html>`);
  await p.waitForTimeout(400);
  await p.evaluate(() => document.fonts.ready);
  await p.screenshot({ path: `${out}/${id}.png` });
  console.log(id);
}
await b.close();
