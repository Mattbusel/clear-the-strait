// App Store screenshots: a headline over each raw simulator shot, on the game's sea and sun.
//   node Store/art/frame.mjs <dir of CI shots> [locale: en-US | ja | ko | zh-Hans]
// Writes fastlane/screenshots/en-US/NN_iPhone.png at 1320x2868 (the 6.9" size).
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, readdirSync, rmSync, mkdirSync } from "fs";

const src = process.argv[2];
const loc = process.argv[3] || "en-US";
const out = process.env.OUT || `C:/Users/Matthew/clear-the-strait/fastlane/screenshots/${loc}`;
// [file stem, headline, sub, tag]. Paid content is tagged on the image (guideline 2.3.2). NO price words on
// any image: "free", "$", "99-cent", "one-time", "no subscription" all count (guideline 2.3.7 rejections, Oct 2026).
const plans = {
  main: [
    [process.env.PLAY || "play-22", "Shove him out<br>of the strait.", "Time your taps with his rock. <b>Pop his ego</b> first.", ""],
    [process.env.LAUNCH || "launch-c", "Then send him<br>skipping.", "The better the rhythm, <b>the further he flies.</b>", ""],
    ["title", "A new strait<br>every day.", "The Daily Strait: <b>one goal for everyone</b>, a streak to build.", ""],
    ["season", "Ten goals<br>every month.", "The <b>Club Season</b>: every channel, harder as it goes.", "STRAIT CLUB"],
    ["widgets", "Your streak on<br>your Lock Screen.", "Widgets, a <b>Control Center button</b> and Siri.", ""],
    ["play-tycoon", "Four blowhards.<br>Four channels.", "Each one with <b>his own twist.</b>", "IN-APP PURCHASE"],
    ["locker", "14 medals<br>to earn.", "From Cleared to <b>Moonshot.</b>", ""],
    ["result", "Every launch<br>on the record.", "Medals, bests and <b>Game Center leaderboards.</b>", ""],
    ["trails", "Trails for<br>the flight.", "Earn them with medals. <b>Season Stars</b> for a full season.", "INCLUDES IN-APP PURCHASES"],
    ["club", "Join the<br>Strait Club.", "All four blowhards, every season, <b>unlimited retries.</b>", "IN-APP PURCHASE"],
  ],
  // Custom product page: daily challenge players.
  daily: [
    ["title", "One strait.<br>Everyone. Today.", "The Daily Strait: <b>same goal for all</b>, new every day.", ""],
    ["dailyresult", "Beat it.<br>Keep the streak.", "Back tomorrow for <b>a new one.</b>", ""],
    ["widgets", "Your streak on<br>your Lock Screen.", "Widgets, a <b>Control Center button</b> and Siri.", ""],
    ["locker", "Medals for<br>every streak.", "Daily Driver, Week Streak and <b>12 more.</b>", ""],
    [process.env.PLAY || "play-22", "Shove him out<br>of the strait.", "Time your taps. <b>Pop his ego</b> first.", ""],
    [process.env.LAUNCH || "launch-c", "Then send him<br>skipping.", "The better the rhythm, <b>the further he flies.</b>", ""],
  ],
  // Custom product page: the satire / funny crowd.
  satire: [
    ["play-windbag", "He will not<br>stop talking.", "Pop every compliment <b>before it lands.</b>", "IN-APP PURCHASE"],
    [process.env.PLAY || "play-22", "Wedged. And<br>delighted.", "Shove the blowhard <b>out of the channel.</b>", ""],
    ["play-tycoon", "Bought the channel.<br>Got stuck in it.", "The Tycoon: <b>harder to budge, flies further.</b>", "IN-APP PURCHASE"],
    ["play-mayor", "Ribbon cutting<br>at midnight.", "The Mayor's promises <b>come home fast.</b>", "IN-APP PURCHASE"],
    [process.env.LAUNCH || "launch-c", "Then send him<br>skipping.", "Still talking, <b>the whole way.</b>", ""],
    ["result", "Every launch<br>on the record.", "Medals, bests and <b>Game Center leaderboards.</b>", ""],
  ],
  // Custom product page: competitive players.
  compete: [
    ["result", "Top the<br>leaderboards.", "Longest Launch, Fastest Clear and <b>a daily board.</b>", ""],
    ["locker", "14 medals.<br>14 achievements.", "Every one <b>in Game Center.</b>", ""],
    ["season", "Ten goals<br>every month.", "The <b>Club Season</b>: harder as it goes.", "STRAIT CLUB"],
    ["play-14", "All in<br>the timing.", "Shove with his rock for <b>TREMENDOUS.</b>", ""],
    [process.env.LAUNCH || "launch-c", "Chase the<br>100,000 m launch.", "The <b>Moonshot</b> medal awaits.", ""],
    ["trails", "Trails for<br>the flight.", "Earn them with medals. <b>Season Stars</b> for a full season.", "INCLUDES IN-APP PURCHASES"],
  ],
};
const planName = process.env.PLAN || "main";
const plan = plans[planName];
// Captions for the Japanese, Korean and Simplified Chinese pages (Store/art/captions.json); app screens stay English.
const L10N = JSON.parse(readFileSync(new URL("./captions.json", import.meta.url), "utf8"));
const steps = loc === "en-US" ? plan : L10N[loc];
const cjk = { ja: "Noto Sans JP", ko: "Noto Sans KR", "zh-Hans": "Noto Sans SC" }[loc];
const files = readdirSync(src);
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1320, height: 2868 } });
let n = 1;
for (const [key, head, sub, tag] of steps) {
  const f = files.find((x) => x === `${key}.png`);
  if (!f) { console.log("missing", key); continue; }
  const img = readFileSync(`${src}/${f}`).toString("base64");
  await p.setContent(`<!doctype html><html><head>
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@700;800;900&display=block" rel="stylesheet">${cjk ? `
<link href="https://fonts.googleapis.com/css2?family=${cjk.replace(/ /g, "+")}:wght@500;600;700;800;900&display=block" rel="stylesheet">` : ""}
<style>
  body{margin:0;width:1320px;height:2868px;overflow:hidden;background:linear-gradient(180deg,#1f99d1 0%,#106ba3 46%,#0f5487 100%);font-family:Nunito,${cjk ? `"${cjk}",` : ""}sans-serif}
  .waves{position:absolute;left:0;right:0;top:620px;height:60px;background:repeating-linear-gradient(90deg,rgba(255,255,255,.18) 0 60px,transparent 60px 120px);opacity:.5;border-radius:30px}
  .col{position:absolute;left:96px;right:96px;top:170px;display:flex;flex-direction:column}
  h1{margin:0;color:#fdc73d;font-weight:900;font-size:116px;line-height:1.0;letter-spacing:-1px;text-shadow:0 8px 0 rgba(18,31,56,.35)}
  p{margin:30px 0 0;color:rgba(240,252,255,.9);font-weight:800;font-size:50px;line-height:1.2}
  p b{color:#fff;font-weight:900}
  .tag{position:absolute;right:96px;top:96px;background:#121f38;color:#fdc73d;font-weight:900;font-size:30px;letter-spacing:3px;padding:12px 22px;border-radius:40px}
  .phone{margin:70px auto 0;width:1080px;border-radius:120px;padding:22px;background:#121f38;box-shadow:0 0 0 4px rgba(253,199,61,.6),0 60px 140px rgba(0,0,0,.45)}
  .phone img{display:block;width:100%;border-radius:100px}
${cjk ? "h1,p{text-wrap:balance}" : ""}</style></head><body>
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
