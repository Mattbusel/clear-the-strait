// App Store screenshots: a headline over each raw simulator shot, on the game's sea and sun.
//   node Store/art/frame.mjs <dir of CI shots> [locale: en-US | ja | ko | zh-Hans]
// Writes fastlane/screenshots/en-US/NN_iPhone.png at 1320x2868 (the 6.9" size).
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, readdirSync, rmSync, mkdirSync } from "fs";

const src = process.argv[2];
const loc = process.argv[3] || "en-US";
const out = `C:/Users/Matthew/clear-the-strait/fastlane/screenshots/${loc}`;
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
// Captions for the Japanese, Korean and Simplified Chinese store pages; the app screens themselves stay English. Paid items stay tagged (guideline 2.3.2).
const L10N = {
  "ja": [
    ["title", "毎日、新しい<br>海峡。", "デイリー・ストレイト:目標はひとつ、連続記録を伸ばそう。", ""],
    [process.env.PLAY || "play-22", "押すか、<br>エゴを割るか。", "<b>両方はできない。</b>", ""],
    [process.env.LAUNCH || "launch-c", "そして<br>海面を跳ねる。", "信じられないほど<b>遠くまで。</b>", ""],
    ["dailyresult", "クリアして<br>記録をつなぐ。", "明日はまた<b>新しい挑戦。</b>", ""],
    ["locker", "メダルは<br>13種類。", "Clearedから<b>Moonshotまで。</b>", ""],
    ["trails", "飛びに<br>トレイルを。", "メダルで解放。<b>Trail Pack</b>でさらに3種類。", "TRAIL PACK:App内課金"],
    ["records", "すべての飛びを<br>記録に。", "ほら吹きごとのベストと、<b>1か月分のデイリー。</b>", ""],
    ["result", "何をしても<br>メダル。", "<b>ポストカード</b>にして送ろう。", ""],
    ["pack", "ほら吹きが<br>あと3人。", "お好みで<b>Blowhard Pack。</b>", "App内課金"],
    ["shop", "広告なし。<br>ガチャなし。", "少額の追加アイテムは<b>中身がはっきり。</b>", "App内課金"],
  ],
  "ko": [
    ["title", "매일 새로운<br>해협.", "데일리 스트레이트: 목표 하나, 쌓아 가는 연속 기록.", ""],
    [process.env.PLAY || "play-22", "밀거나,<br>허세를 터뜨려.", "<b>둘 다는 못 해요.</b>", ""],
    [process.env.LAUNCH || "launch-c", "그리고<br>물수제비처럼.", "상상보다 <b>훨씬 멀리.</b>", ""],
    ["dailyresult", "깨고,<br>연속 기록 유지.", "내일은 <b>새로운 도전.</b>", ""],
    ["locker", "모을 메달<br>13개.", "Cleared부터 <b>Moonshot까지.</b>", ""],
    ["trails", "발사 트레일을<br>얻으세요.", "메달로 잠금 해제. <b>Trail Pack</b>은 3개 더.", "TRAIL PACK: 앱 내 구입"],
    ["records", "모든 발사를<br>기록으로.", "허풍쟁이별 최고 기록과 <b>한 달 치 데일리.</b>", ""],
    ["result", "모든 것에<br>메달을.", "그리고 보낼 수 있는 <b>엽서.</b>", ""],
    ["pack", "허풍쟁이<br>3명 추가.", "선택형 <b>Blowhard Pack.</b>", "앱 내 구입"],
    ["shop", "광고 없음.<br>랜덤 박스 없음.", "선택형 소액 아이템은 <b>내용이 정확히 적혀 있어요.</b>", "앱 내 구입"],
  ],
  "zh-Hans": [
    ["title", "每天一道<br>新海峡。", "每日海峡:一个目标,一路连胜。", ""],
    [process.env.PLAY || "play-22", "推他,<br>或戳破他的自负。", "<b>两样不能兼得。</b>", ""],
    [process.env.LAUNCH || "launch-c", "然后让他<br>打水漂。", "远到<b>你不敢信。</b>", ""],
    ["dailyresult", "过关,<br>保住连胜。", "明天还有<b>新的一关。</b>", ""],
    ["locker", "13 枚奖牌<br>等你拿。", "从 Cleared 到 <b>Moonshot。</b>", ""],
    ["trails", "赢取你的<br>发射尾迹。", "奖牌解锁。<b>Trail Pack</b> 再加三种。", "TRAIL PACK:App 内购买项目"],
    ["records", "每次发射,<br>都有记录。", "每个吹牛大王的最佳成绩,<b>还有整月的每日挑战。</b>", ""],
    ["result", "什么都能<br>拿奖牌。", "还有一张<b>明信片</b>可以寄出去。", ""],
    ["pack", "再来三个<br>吹牛大王。", "可选的 <b>Blowhard Pack。</b>", "App 内购买项目"],
    ["shop", "没有广告。<br>没有开箱。", "可选的小额附加内容,<b>写清楚是什么。</b>", "App 内购买项目"],
  ],
};
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
