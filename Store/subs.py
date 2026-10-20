"""The Strait Club: an auto-renewable subscription group with a monthly and a yearly plan.

    python Store/subs.py create              group + localizations + both plans: text, price in every territory,
                                             availability, the yearly plan's one-week free trial (idempotent)
    python Store/subs.py shot <png>          App Review screenshot for both plans
    python Store/subs.py promo <kind> <png>  1024x1024 promotional image (kind: monthly | yearly)
    python Store/subs.py status              state of the group and each plan
    python Store/subs.py offercode           the BLOWHARD custom offer code (first month free, for Blowhard Pack owners)

Product ids must match Sources/Services/Club.swift.
"""
import hashlib
import sys
import time
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP = "6810644510"
GROUP_NAME = "Strait Club"
BASE = "com.mattbusel.clearthestrait.club."
EULA = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

REVIEW = ("Auto-renewable subscription in the group Strait Club. To test: on the title screen tap the CLUB button "
          "(top left), or Locker (top right) > Shop > Strait Club, or a locked Season goal. The paywall lists every "
          "benefit, both plans with price and period, the yearly plan's one-week free trial, auto-renew terms, Terms "
          "of Use (Apple standard EULA) and Privacy Policy links, Restore Purchases and Redeem Code. While subscribed: "
          "all four blowhards, every trail and app icon, unlimited Daily Strait retries, unlimited postcards, three "
          "Streak Shields each month, and all ten goals of the monthly Club Season (free players get the first three). "
          "Manage Subscription appears on the same screen once subscribed. The Blowhard Pack (one-time) is unchanged.")

# suffix, period, level, reference name, display name (30), description (45)
PLANS = [
    ("yearly", "ONE_YEAR", 1, "Strait Club Yearly", "Strait Club (Yearly)", "Every blowhard, every season, all year."),
    ("monthly", "ONE_MONTH", 2, "Strait Club Monthly", "Strait Club (Monthly)", "Every blowhard and a new season each month."),
]
PRICES = {"monthly": "2.99", "yearly": "14.99"}

# locale -> (group display name, custom app name or None)
GROUP_L10N = {"en-US": ("Strait Club", None)}


def group():
    got = asc.call("GET", f"/v1/apps/{APP}/subscriptionGroups", params={"limit": 20})
    for g in (got or {}).get("data", []):
        if g["attributes"]["referenceName"] == GROUP_NAME:
            return g
    made = asc.call("POST", "/v1/subscriptionGroups", {"data": {"type": "subscriptionGroups",
                    "attributes": {"referenceName": GROUP_NAME},
                    "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
    return made["data"]


def plans(gid):
    got = asc.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptions", params={"limit": 20}) or {"data": []}
    return {d["attributes"]["productId"]: d for d in got["data"]}


def territories():
    return [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]


def set_prices(sid, price):
    have = asc.call("GET", f"/v1/subscriptions/{sid}/prices", params={"limit": 200, "include": "territory"}) or {"data": []}
    done = {d["relationships"]["territory"]["data"]["id"] for d in have["data"] if d.get("relationships", {}).get("territory", {}).get("data")}
    if len(done) >= 170:
        print(f"  prices already set in {len(done)} territories")
        return
    pts = asc.call("GET", f"/v1/subscriptions/{sid}/pricePoints", params={"filter[territory]": "USA", "limit": 200})
    usa = None
    url = f"/v1/subscriptions/{sid}/pricePoints"
    params = {"filter[territory]": "USA", "limit": 200}
    while True:
        usa = next((d for d in (pts or {}).get("data", []) if d["attributes"]["customerPrice"] == price), None)
        nxt = (pts or {}).get("links", {}).get("next")
        if usa or not nxt:
            break
        pts = asc.call("GET", nxt)
    if not usa:
        print("  no USA price point for", price)
        return
    eq = [usa]
    nxt = f"/v1/subscriptionPricePoints/{usa['id']}/equalizations?limit=200&include=territory"
    while nxt:
        page = asc.call("GET", nxt)
        if not page:
            break
        eq += page["data"]
        nxt = page.get("links", {}).get("next")
    ok = 0
    for pp in eq:
        terr = pp.get("relationships", {}).get("territory", {}).get("data", {}).get("id") or "USA"
        if terr in done:
            continue
        r = asc.call("POST", "/v1/subscriptionPrices", {"data": {"type": "subscriptionPrices",
                     "attributes": {"startDate": None, "preserveCurrentPrice": False},
                     "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                       "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": pp["id"]}},
                                       "territory": {"data": {"type": "territories", "id": terr}}}}}, quiet=True)
        ok += 1 if r else 0
        time.sleep(0.3)
    print(f"  prices: {ok} new of {len(eq)} territories (USA ${price})")


def trial(sid, terr):
    have = asc.call("GET", f"/v1/subscriptions/{sid}/introductoryOffers", params={"limit": 200}) or {"data": []}
    if len(have["data"]) >= 170:
        print(f"  free trial already in {len(have['data'])} territories")
        return
    got = asc.call("GET", f"/v1/subscriptions/{sid}/introductoryOffers", params={"limit": 200, "include": "territory"}) or {"data": []}
    done = {d["relationships"]["territory"]["data"]["id"] for d in got["data"] if d.get("relationships", {}).get("territory", {}).get("data")}
    ok = 0
    for t in terr:
        if t in done:
            continue
        r = asc.call("POST", "/v1/subscriptionIntroductoryOffers", {"data": {"type": "subscriptionIntroductoryOffers",
                     "attributes": {"duration": "ONE_WEEK", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1, "startDate": None, "endDate": None},
                     "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                       "territory": {"data": {"type": "territories", "id": t}}}}}, quiet=True)
        ok += 1 if r else 0
        time.sleep(0.3)
    print(f"  free trial: {ok} new territories")


def create():
    g = group()
    gid = g["id"]
    print("group", gid)
    locs = asc.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptionGroupLocalizations") or {"data": []}
    have = {l["attributes"]["locale"]: l for l in locs["data"]}
    for loc, (name, custom) in GROUP_L10N.items():
        attrs = {"name": name, "customAppName": custom}
        if loc in have:
            asc.call("PATCH", f"/v1/subscriptionGroupLocalizations/{have[loc]['id']}", {"data": {"type": "subscriptionGroupLocalizations", "id": have[loc]["id"], "attributes": attrs}})
        else:
            r = asc.call("POST", "/v1/subscriptionGroupLocalizations", {"data": {"type": "subscriptionGroupLocalizations",
                         "attributes": {"locale": loc, **attrs},
                         "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": gid}}}}})
            print(f"  group {loc}", "added" if r else "FAILED")
    terr = territories()
    existing = plans(gid)
    for suffix, period, level, ref, name, desc in PLANS:
        pid = BASE + suffix
        s = existing.get(pid)
        if not s:
            made = asc.call("POST", "/v1/subscriptions", {"data": {"type": "subscriptions",
                            "attributes": {"name": ref, "productId": pid, "subscriptionPeriod": period, "familySharable": False,
                                           "reviewNote": REVIEW, "groupLevel": level},
                            "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": gid}}}}})
            if not made:
                print(pid, "create FAILED")
                continue
            s = made["data"]
        sid = s["id"]
        print(f"{pid}: {sid} {s['attributes'].get('state')}")
        asc.call("PATCH", f"/v1/subscriptions/{sid}", {"data": {"type": "subscriptions", "id": sid, "attributes": {"reviewNote": REVIEW}}}, quiet=True)
        sl = asc.call("GET", f"/v1/subscriptions/{sid}/subscriptionLocalizations") or {"data": []}
        if not any(l["attributes"]["locale"] == "en-US" for l in sl["data"]):
            r = asc.call("POST", "/v1/subscriptionLocalizations", {"data": {"type": "subscriptionLocalizations",
                         "attributes": {"locale": "en-US", "name": name, "description": desc},
                         "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
            print("  localization", "added" if r else "FAILED")
        av = asc.call("GET", f"/v1/subscriptions/{sid}/subscriptionAvailability", quiet=True)
        if not av or not av.get("data"):
            r = asc.call("POST", "/v1/subscriptionAvailabilities", {"data": {"type": "subscriptionAvailabilities",
                         "attributes": {"availableInNewTerritories": True},
                         "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                           "availableTerritories": {"data": [{"type": "territories", "id": t} for t in terr]}}}})
            print("  availability", f"{len(terr)} territories" if r else "FAILED")
        set_prices(sid, PRICES[suffix])
        if suffix == "yearly":
            trial(sid, terr)


def upload(kind_path, rel_type, rel_name, sid, png):
    data = Path(png).read_bytes()
    made = asc.call("POST", f"/v1/{kind_path}", {"data": {"type": kind_path,
                    "attributes": {"fileName": Path(png).name, "fileSize": len(data)},
                    "relationships": {rel_name: {"data": {"type": rel_type, "id": sid}}}}})
    if not made:
        return False
    for op in made["data"]["attributes"]["uploadOperations"]:
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        requests.request(op["method"], op["url"], headers=headers, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
    r = asc.call("PATCH", f"/v1/{kind_path}/{made['data']['id']}", {"data": {"type": kind_path, "id": made["data"]["id"],
                 "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    return bool(r)


def shot(png):
    g = group()
    for pid, s in plans(g["id"]).items():
        cur = asc.call("GET", f"/v1/subscriptions/{s['id']}/appStoreReviewScreenshot", quiet=True)
        if cur and cur.get("data"):
            asc.call("DELETE", f"/v1/subscriptionAppStoreReviewScreenshots/{cur['data']['id']}")
        ok = upload("subscriptionAppStoreReviewScreenshots", "subscriptions", "subscription", s["id"], png)
        print(pid, "review screenshot", "uploaded" if ok else "FAILED")


def promo(kind, png):
    g = group()
    s = plans(g["id"]).get(BASE + kind)
    if not s:
        sys.exit("no such plan")
    cur = asc.call("GET", f"/v1/subscriptions/{s['id']}/images", quiet=True) or {"data": []}
    for d in cur.get("data", []):
        asc.call("DELETE", f"/v1/subscriptionImages/{d['id']}")
    ok = upload("subscriptionImages", "subscriptions", "subscription", s["id"], png)
    print(kind, "promo image", "uploaded" if ok else "FAILED")


def l10n():
    """Group and plan localizations for every store locale, from Store/l10n.json."""
    import json
    data = json.loads((Path(__file__).resolve().parent / "l10n.json").read_text(encoding="utf-8"))
    g = group()
    glocs = {l["attributes"]["locale"]: l for l in (asc.call("GET", f"/v1/subscriptionGroups/{g['id']}/subscriptionGroupLocalizations") or {"data": []})["data"]}
    for loc, d in data.items():
        if loc not in glocs:
            r = asc.call("POST", "/v1/subscriptionGroupLocalizations", {"data": {"type": "subscriptionGroupLocalizations",
                         "attributes": {"locale": loc, "name": d["club_group_name"]},
                         "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": g["id"]}}}}})
            print("group", loc, "ok" if r else "FAILED")
    for pid, sub in plans(g["id"]).items():
        kind = "club_yearly" if pid.endswith("yearly") else "club_monthly"
        have = {l["attributes"]["locale"] for l in (asc.call("GET", f"/v1/subscriptions/{sub['id']}/subscriptionLocalizations") or {"data": []})["data"]}
        for loc, d in data.items():
            if loc in have:
                continue
            r = asc.call("POST", "/v1/subscriptionLocalizations", {"data": {"type": "subscriptionLocalizations",
                         "attributes": {"locale": loc, "name": d[kind]["name"], "description": d[kind]["description"]},
                         "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub["id"]}}}}})
            print(pid[-7:], loc, "ok" if r else "FAILED")


def status():
    g = group()
    print("group", g["id"], g["attributes"])
    for pid, s in plans(g["id"]).items():
        print(f"  {pid}: {s['id']} {s['attributes'].get('state')}")


def offercode():
    """A custom offer code anyone can type: BLOWHARD, first month free on the monthly plan."""
    g = group()
    s = plans(g["id"]).get(BASE + "monthly")
    have = asc.call("GET", f"/v1/subscriptions/{s['id']}/offerCodes", params={"limit": 50}) or {"data": []}
    oc = next((d for d in have["data"] if d["attributes"].get("name") == "Blowhard Pack thanks"), None)
    terr = territories()
    if not oc:
        made = asc.call("POST", "/v1/subscriptionOfferCodes", {"data": {"type": "subscriptionOfferCodes",
                        "attributes": {"name": "Blowhard Pack thanks", "customerEligibilities": ["NEW", "EXPIRED"],
                                       "offerEligibility": "STACK_WITH_INTRO_OFFERS", "duration": "ONE_MONTH",
                                       "offerMode": "FREE_TRIAL", "numberOfPeriods": 1},
                        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": s["id"]}},
                                          "prices": {"data": [{"type": "subscriptionOfferCodePrices", "id": f"${{t{i}}}"} for i, _ in enumerate(terr)]}}},
                        "included": [{"type": "subscriptionOfferCodePrices", "id": f"${{t{i}}}",
                                      "relationships": {"territory": {"data": {"type": "territories", "id": t}}}} for i, t in enumerate(terr)]})
        if not made:
            print("offer code FAILED")
            return
        oc = made["data"]
        print("offer code", oc["id"])
    customs = asc.call("GET", f"/v1/subscriptionOfferCodes/{oc['id']}/customCodes", params={"limit": 20}) or {"data": []}
    if not any(c["attributes"].get("customCode") == "BLOWHARD" for c in customs["data"]):
        r = asc.call("POST", "/v1/subscriptionOfferCodeCustomCodes", {"data": {"type": "subscriptionOfferCodeCustomCodes",
                     "attributes": {"customCode": "BLOWHARD", "numberOfCodes": 100000, "expirationDate": "2027-10-19"},
                     "relationships": {"offerCode": {"data": {"type": "subscriptionOfferCodes", "id": oc["id"]}}}}})
        print("custom code BLOWHARD", "created" if r else "FAILED")
    else:
        print("custom code BLOWHARD exists")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "shot":
        shot(sys.argv[2])
    elif cmd == "promo":
        promo(sys.argv[2], sys.argv[3])
    else:
        {"create": create, "status": status, "offercode": offercode, "l10n": l10n}.get(cmd, lambda: sys.exit(__doc__))()
