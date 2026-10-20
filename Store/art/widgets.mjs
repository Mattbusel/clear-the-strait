// A faithful drawing of the 1.2 widgets (same layout, colours and text as Widgets/StraitWidgets.swift) on a
// Lock Screen and a Home Screen, at the simulator's 1320x2868, so frame.mjs can caption it like a screen.
// A simulator cannot be made to add widgets to its own Home Screen from CI, so this is drawn.
//   node Store/art/widgets.mjs <out.png>
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";

const out = process.argv[2];
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 440, height: 956 }, deviceScaleFactor: 3 });
await p.setContent(`<!doctype html><html><head>
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@600;700;800;900&display=block" rel="stylesheet">
<style>
*{box-sizing:border-box}
body{margin:0;width:440px;height:956px;overflow:hidden;font-family:Nunito,-apple-system,sans-serif;
 background:linear-gradient(180deg,#0b3f66 0%,#106ba3 38%,#1f99d1 62%,#f0fcff 100%);color:#f0fcff}
.lock{position:absolute;top:0;left:0;right:0;height:470px;text-align:center}
.date{margin-top:70px;font-weight:800;font-size:21px;opacity:.9}
.time{font-weight:900;font-size:104px;line-height:1;letter-spacing:-2px;margin-top:2px}
.lrow{display:flex;gap:12px;justify-content:center;margin-top:14px}
.rect{width:250px;height:74px;border-radius:18px;background:rgba(255,255,255,.18);backdrop-filter:blur(8px);text-align:left;padding:9px 14px}
.rect .a{font-size:11px;font-weight:900;letter-spacing:.3px}
.rect .b{font-size:16px;font-weight:900;margin-top:1px}
.rect .c{font-size:12px;font-weight:700;margin-top:1px}
.circ{width:74px;height:74px;border-radius:50%;background:rgba(255,255,255,.18);display:flex;flex-direction:column;align-items:center;justify-content:center}
.circ .n{font-size:24px;font-weight:900;line-height:1}
.home{position:absolute;top:470px;left:0;right:0;bottom:0;background:rgba(7,18,34,.38);padding:28px 26px}
.label{font-size:12px;font-weight:800;text-align:center;margin-top:7px;opacity:.95}
.grid{display:flex;gap:22px}
.w{border-radius:26px;background:linear-gradient(180deg,#219bd1,#0f5487);box-shadow:0 10px 30px rgba(0,0,0,.3);padding:16px;position:relative}
.small{width:170px;height:170px}
.medium{width:362px;height:170px;display:flex}
.k{color:#fdc73d;font-size:11px;font-weight:900;letter-spacing:.8px}
.cond{font-size:18px;font-weight:900;margin-top:3px}
.goal{font-size:13px;font-weight:800;opacity:.92;margin-top:2px}
.pill{position:absolute;left:16px;bottom:14px;background:#fdc73d;color:#121f38;font-weight:900;font-size:13px;letter-spacing:1px;border-radius:20px;padding:5px 12px}
.side{width:110px;display:flex;flex-direction:column;align-items:center;justify-content:center;margin-left:auto}
.side .n{font-size:44px;font-weight:900;line-height:1}
.side .t{font-size:10px;font-weight:900;letter-spacing:1px;opacity:.85}
.flame{width:30px;height:34px}
.apps{display:flex;gap:26px;margin-top:30px;justify-content:space-between}
.app{width:64px;height:64px;border-radius:15px;background:rgba(255,255,255,.22)}
</style></head><body>
<div class="lock">
  <div class="date">Tuesday 20 October</div>
  <div class="time">9:41</div>
  <div class="lrow">
    <div class="rect"><div class="a">STRAIT #12 · BIG LUNCH</div><div class="b">Pop 6 bubbles</div><div class="c">${flameSvg("#f0fcff", 11)} 9-day streak</div></div>
    <div class="circ">${flameSvg("#f0fcff", 16)}<div class="n">9</div></div>
  </div>
</div>
<div class="home">
  <div class="grid">
    <div><div class="w small"><div class="k">DAILY STRAIT #12</div><div class="cond">BIG LUNCH</div><div class="goal">POP 6 BUBBLES</div><div class="pill">&#9654; PLAY</div></div><div class="label">Clear the Strait</div></div>
    <div><div class="w small" style="display:flex;flex-direction:column;align-items:center;justify-content:center">${flameSvg("#f04d4d", 34)}<div style="font-size:48px;font-weight:900;line-height:1">9</div><div class="t" style="font-size:11px;font-weight:900;letter-spacing:1px">DAY STREAK</div><div style="font-size:10px;font-weight:800;opacity:.7">BEST 9</div></div><div class="label">Clear the Strait</div></div>
  </div>
  <div style="margin-top:22px"><div class="w medium"><div style="position:relative;width:200px"><div class="k">DAILY STRAIT #12</div><div class="cond">BIG LUNCH</div><div class="goal">POP 6 BUBBLES</div><div class="pill" style="left:0;bottom:0">&#9654; PLAY</div></div>
    <div class="side">${flameSvg("#f04d4d", 26)}<div class="n">9</div><div class="t">DAY STREAK</div></div></div><div class="label">Clear the Strait</div></div>
  <div class="apps"><div class="app"></div><div class="app"></div><div class="app"></div><div class="app"></div></div>
</div>
</body></html>`);
function flameSvg(c, s) {
  return `<svg width="${s}" height="${Math.round(s * 1.15)}" viewBox="0 0 24 28"><path fill="${c}" d="M12 1c1 5 7 8 7 15a7 7 0 0 1-14 0c0-3 1.5-5 3-6.5C8 12 9 14 11 14c-1-4 0-9 1-13z"/></svg>`;
}
await p.evaluate(() => document.fonts.ready);
await p.waitForTimeout(500);
await p.screenshot({ path: out });
await b.close();
console.log("wrote", out);
