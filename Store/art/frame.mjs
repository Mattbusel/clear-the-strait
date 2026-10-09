// App Store screenshots: a headline over each raw simulator shot, on the game's sea and sun.
//   node Store/art/frame.mjs <dir of CI shots>
// Writes fastlane/screenshots/en-US/NN_iPhone.png at 1320x2868 (the 6.9" size).
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, readdirSync, rmSync, mkdirSync } from "fs";

const src = process.argv[2];
const out = "C:/Users/Matthew/clear-the-strait/fastlane/screenshots/en-US";
// [file stem, headline, sub, tag]. Paid items are tagged on the image (guideline 2.3.2).
const plan = [
  ["title", "A new strait<br>every day.", "The Daily Strait: one goal, a streak to build.", ""],
  [process.env.PLAY || "play-22", "Shove him.<br>Or pop his ego.", "You <b>can't do both.</b>", ""],
  [process.env.LAUNCH || "launch-c", "Then send him<br>skipping.", "Further than <b>you'd believe.</b>", ""],
  ["dailyresult", "Beat it.<br>Keep the streak.", "Back tomorrow for <b>a new one.</b>", ""],
  ["locker", "13 medals<br>to earn.", "From Cleared to <b>Moonshot.</b>", ""],
  ["trails", "Earn your<br>launch trail.", "Medals unlock them. <b>Trail Pack</b> adds three.", "TRAIL PACK: IN-APP PURCHASE"],
  ["records", "Every launch,<br>on the record.", "Best for every blowhard, and <b>your month of dailies.</b>", ""],
  ["result", "Medals for<br>everything.", "And a <b>postcard</b> to send round.", ""],
  ["pack", "Three more<br>blowhards.", "The optional <b>Blowhard Pack.</b>", "IN-APP PURCHASE"],
  ["shop", "No adverts.<br>No loot boxes.", "Optional 99-cent extras that <b>say exactly what they do.</b>", "IN-APP PURCHASES"],
];
const files = readdirSync(src);
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1320, height: 2868 } });
let n = 1;
for (const [key, head, sub, tag] of plan) {
  const f = files.find((x) => x === `${key}.png`);
  if (!f) { console.log("missing", key); continue; }
  const img = readFileSync(`${src}/${f}`).toString("base64");
  await p.setContent(`<!doctype html><html><head>
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@700;800;900&display=block" rel="stylesheet">
<style>
  body{margin:0;width:1320px;height:2868px;overflow:hidden;background:linear-gradient(180deg,#1f99d1 0%,#106ba3 46%,#0f5487 100%);font-family:Nunito,sans-serif}
  .waves{position:absolute;left:0;right:0;top:620px;height:60px;background:repeating-linear-gradient(90deg,rgba(255,255,255,.18) 0 60px,transparent 60px 120px);opacity:.5;border-radius:30px}
  .col{position:absolute;left:96px;right:96px;top:170px;display:flex;flex-direction:column}
  h1{margin:0;color:#fdc73d;font-weight:900;font-size:116px;line-height:1.0;letter-spacing:-1px;text-shadow:0 8px 0 rgba(18,31,56,.35)}
  p{margin:30px 0 0;color:rgba(240,252,255,.9);font-weight:800;font-size:50px;line-height:1.2}
  p b{color:#fff;font-weight:900}
  .tag{position:absolute;right:96px;top:96px;background:#121f38;color:#fdc73d;font-weight:900;font-size:30px;letter-spacing:3px;padding:12px 22px;border-radius:40px}
  .phone{margin:70px auto 0;width:1080px;border-radius:120px;padding:22px;background:#121f38;box-shadow:0 0 0 4px rgba(253,199,61,.6),0 60px 140px rgba(0,0,0,.45)}
  .phone img{display:block;width:100%;border-radius:100px}
</style></head><body>
${tag ? `<div class="tag">${tag}</div>` : ""}
<div class="col"><h1>${head}</h1><p>${sub}</p>
<div class="phone"><img src="data:image/png;base64,${img}"></div></div>
</body></html>`);
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(300);
  const name = `${String(n).padStart(2, "0")}_iPhone.png`;
  await p.screenshot({ path: `${out}/${name}`, clip: { x: 0, y: 0, width: 1320, height: 2868 } });
  console.log("wrote", name, key);
  n++;
}
await b.close();
