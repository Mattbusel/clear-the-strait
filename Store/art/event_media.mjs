// In-App Event media: <key>-card.png 1920x1080 (three raw screens, no text: the App Store draws the event name)
// and <key>-details.png 1080x1920 (one raw screen on the sea, no text).
//   node Store/art/event_media.mjs <raw shots dir> <out dir>
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, mkdirSync } from "fs";

const [raw, out] = process.argv.slice(2);
mkdirSync(out, { recursive: true });
const b64 = (f) => `data:image/png;base64,${readFileSync(`${raw}/${f}.png`).toString("base64")}`;
const sets = { season: ["season", "play-tycoon", "seasonresult"] };
const bg = "radial-gradient(1100px 800px at 50% 40%,#2aa6db,#106ba3 55%,#0b3f66)";
const b = await chromium.launch();
for (const [key, shots] of Object.entries(sets)) {
  const card = await b.newPage({ viewport: { width: 1920, height: 1080 } });
  await card.setContent(`<!doctype html><html><head><style>
body{margin:0;width:1920px;height:1080px;overflow:hidden;background:${bg}}
.ph{position:absolute;top:120px;width:420px;border-radius:62px;padding:14px;background:#121f38;box-shadow:0 0 0 4px rgba(253,199,61,.6),0 40px 120px rgba(0,0,0,.5)}
.ph img{display:block;width:100%;border-radius:50px}
.p0{left:330px;transform:rotate(-7deg) translateY(70px)} .p1{left:750px;top:70px;z-index:2} .p2{left:1170px;transform:rotate(7deg) translateY(70px)}
</style></head><body>${shots.map((s, i) => `<div class="ph p${i}"><img src="${b64(s)}"></div>`).join("")}</body></html>`);
  await card.waitForTimeout(300);
  await card.screenshot({ path: `${out}/${key}-card.png` });
  const det = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  await det.setContent(`<!doctype html><html><head><style>
body{margin:0;width:1080px;height:1920px;overflow:hidden;background:${bg};display:flex;align-items:center;justify-content:center}
.ph{width:760px;border-radius:100px;padding:20px;background:#121f38;box-shadow:0 0 0 5px rgba(253,199,61,.6),0 50px 140px rgba(0,0,0,.5);margin-top:220px}
.ph img{display:block;width:100%;border-radius:82px}
</style></head><body><div class="ph"><img src="${b64(shots[0])}"></div></body></html>`);
  await det.waitForTimeout(300);
  await det.screenshot({ path: `${out}/${key}-details.png` });
  console.log(key);
}
await b.close();
