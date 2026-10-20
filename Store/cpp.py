"""Custom product pages: three audiences, each its own screenshots and promotional text.

    python Store/cpp.py create          pages + en-US localization + screenshots from fastlane/cpp/<key>/*.png (idempotent)
    python Store/cpp.py state

Screenshots come from Store/art/frame.mjs with PLAN=<key> OUT=fastlane/cpp/<key>.
"""
import hashlib
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP = "6810644510"
ROOT = Path(__file__).resolve().parent.parent / "fastlane" / "cpp"
PAGES = [
    ("daily", "Daily Strait challenge", "clearthestrait://daily",
     "One strait, the same for everyone, new every day. Beat it to grow your streak; your Lock Screen widget keeps count.",
     ["daily challenge", "streak", "daily puzzle", "brain", "habit"]),
    ("satire", "Satire and parody", "clearthestrait://club",
     "Four round, self-important blowhards, wedged in four channels, talking the whole time. Shove them out and pop their egos.",
     ["satire", "parody", "politician", "funny", "meme"]),
    ("compete", "Leaderboards and medals", "clearthestrait://season",
     "Longest Launch, Fastest Clear and a daily leaderboard in Game Center, 14 achievements and ten new goals every month.",
     ["leaderboard", "arcade", "high score", "timing", "reflex"]),
]


def pages():
    got = asc.call("GET", f"/v1/apps/{APP}/appCustomProductPages", params={"limit": 50}) or {"data": []}
    return {d["attributes"]["name"]: d for d in got["data"]}


def upload_set(loc_id, files):
    sets = asc.call("GET", f"/v1/appCustomProductPageLocalizations/{loc_id}/appScreenshotSets") or {"data": []}
    sset = next((s for s in sets["data"] if s["attributes"]["screenshotDisplayType"] == "APP_IPHONE_67"), None)
    if not sset:
        sset = asc.call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": "APP_IPHONE_67"},
                        "relationships": {"appCustomProductPageLocalization": {"data": {"type": "appCustomProductPageLocalizations", "id": loc_id}}}}})["data"]
    have = [s["attributes"].get("sourceFileChecksum") for s in asc.call("GET", f"/v1/appScreenshotSets/{sset['id']}/appScreenshots", params={"limit": 20})["data"]]
    local = [hashlib.md5(f.read_bytes()).hexdigest() for f in files]
    if have == local:
        print("   screenshots MATCH")
        return
    for s in asc.call("GET", f"/v1/appScreenshotSets/{sset['id']}/appScreenshots", params={"limit": 20})["data"]:
        asc.call("DELETE", f"/v1/appScreenshots/{s['id']}")
    for f in files:
        data = f.read_bytes()
        made = asc.call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": f.name, "fileSize": len(data)},
                        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sset["id"]}}}}})["data"]
        for op in made["attributes"]["uploadOperations"]:
            h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
            requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
        asc.call("PATCH", f"/v1/appScreenshots/{made['id']}", {"data": {"type": "appScreenshots", "id": made["id"],
                 "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print(f"   uploaded {len(files)} screenshots")


def create():
    have = pages()
    for key, name, link, promo, kws in PAGES:
        assert len(promo) <= 170, (key, len(promo))
        page = have.get(name)
        if not page:
            made = asc.call("POST", "/v1/appCustomProductPages", {
                "data": {"type": "appCustomProductPages", "attributes": {"name": name},
                         "relationships": {"app": {"data": {"type": "apps", "id": APP}},
                                           "appCustomProductPageVersions": {"data": [{"type": "appCustomProductPageVersions", "id": "${v1}"}]}}},
                "included": [
                    {"type": "appCustomProductPageVersions", "id": "${v1}", "attributes": {"deepLink": link},
                     "relationships": {"appCustomProductPageLocalizations": {"data": [{"type": "appCustomProductPageLocalizations", "id": "${l1}"}]}}},
                    {"type": "appCustomProductPageLocalizations", "id": "${l1}", "attributes": {"locale": "en-US", "promotionalText": promo}},
                ]})
            if not made:
                print(key, "create FAILED")
                continue
            page = made["data"]
        print(key, page["id"])
        vers = asc.call("GET", f"/v1/appCustomProductPages/{page['id']}/appCustomProductPageVersions")["data"]
        ver = vers[0]
        locs = asc.call("GET", f"/v1/appCustomProductPageVersions/{ver['id']}/appCustomProductPageLocalizations")["data"]
        loc = next(l for l in locs if l["attributes"]["locale"] == "en-US")
        print("  version", ver["id"], ver["attributes"].get("state"), "loc", loc["id"])
        files = sorted((ROOT / key).glob("*.png"))
        if files:
            upload_set(loc["id"], files)
        # Search keywords for the page (API support varies; skipped quietly if refused).
        r = asc.call("GET", f"/v1/appCustomProductPageLocalizations/{loc['id']}/searchKeywords", quiet=True)
        if r is not None and not r.get("data"):
            ok = asc.call("POST", f"/v1/appCustomProductPageLocalizations/{loc['id']}/relationships/searchKeywords",
                          {"data": [{"type": "appKeywords", "id": k} for k in kws]}, quiet=True)
            print("  keywords", "set" if ok is not None else "not accepted by the API")


def state():
    for name, p in pages().items():
        vers = asc.call("GET", f"/v1/appCustomProductPages/{p['id']}/appCustomProductPageVersions")["data"]
        print(p["id"], name, [(v["id"], v["attributes"].get("state")) for v in vers])


if __name__ == "__main__":
    {"create": create, "state": state}[sys.argv[1] if len(sys.argv) > 1 else "state"]()
