"""The Blowhard Pack in App Store Connect: one non-consumable in-app purchase.

Usage: python Store/iap.py <command> [arg]

  create        create the IAP (idempotent), its en-US text, price and territories
  screenshot F  upload F as the App Review screenshot of the purchase screen
  free          set the app itself to Free
  submit        submit the IAP for review (the first one goes with the next version)
  status        print the IAP's state

Uses the helpers and the API key in asc.py.
"""
import hashlib
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
from asc import call, find_app  # noqa: E402

PRODUCT_ID = "com.mattbusel.clearthestrait.pack1"
REFERENCE_NAME = "Blowhard Pack"
PRICE = "1.99"
DISPLAY_NAME = "The Blowhard Pack"
DESCRIPTION = "Three new blowhards, three new channels."
REVIEW_NOTE = (
    "Unlocks three extra playable characters (The Windbag, The Tycoon, The Mayor), "
    "each in his own channel with a small rule twist. To test: on the title screen tap "
    "GET THE BLOWHARD PACK (or any locked character), then UNLOCK. After buying, the "
    "three characters become selectable in the row above PLAY. RESTORE PURCHASES is on "
    "the same screen. The base game is fully playable without buying anything."
)


def app_id() -> str:
    app = find_app()
    if not app:
        sys.exit("no app record")
    return app["id"]


def find_iap(app: str):
    got = call("GET", f"/v1/apps/{app}/inAppPurchasesV2", params={"limit": 50, "filter[productId]": PRODUCT_ID})
    for d in (got or {}).get("data", []):
        if d["attributes"].get("productId") == PRODUCT_ID:
            return d
    return None


def create():
    app = app_id()
    iap = find_iap(app)
    if iap:
        print(f"IAP exists: {iap['id']} {iap['attributes'].get('state')}")
    else:
        made = call("POST", "/v2/inAppPurchases", {"data": {
            "type": "inAppPurchases",
            "attributes": {
                "name": REFERENCE_NAME,
                "productId": PRODUCT_ID,
                "inAppPurchaseType": "NON_CONSUMABLE",
                "reviewNote": REVIEW_NOTE,
                "familySharable": True,
            },
            "relationships": {"app": {"data": {"type": "apps", "id": app}}},
        }})
        if not made:
            sys.exit("IAP creation failed (check the Paid Apps Agreement and banking in App Store Connect)")
        iap = made["data"]
        print(f"IAP created: {iap['id']}")
    iid = iap["id"]

    # en-US display name and description
    locs = call("GET", f"/v2/inAppPurchases/{iid}/inAppPurchaseLocalizations", params={"limit": 20})
    have = {d["attributes"]["locale"]: d["id"] for d in (locs or {}).get("data", [])}
    attrs = {"name": DISPLAY_NAME, "description": DESCRIPTION}
    if "en-US" in have:
        r = call("PATCH", f"/v1/inAppPurchaseLocalizations/{have['en-US']}", {"data": {
            "type": "inAppPurchaseLocalizations", "id": have["en-US"], "attributes": attrs}})
    else:
        r = call("POST", "/v1/inAppPurchaseLocalizations", {"data": {
            "type": "inAppPurchaseLocalizations",
            "attributes": {"locale": "en-US", **attrs},
            "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}})
    print("  localization", "ok" if r is not None else "FAILED")

    # price, USA base, equalised everywhere else by Apple
    points = call("GET", f"/v2/inAppPurchases/{iid}/pricePoints",
                  params={"filter[territory]": "USA", "limit": 200})
    point = next((d["id"] for d in (points or {}).get("data", [])
                  if d["attributes"].get("customerPrice") == PRICE), None)
    if not point:
        print(f"  no USA price point at {PRICE}")
    else:
        r = call("POST", "/v1/inAppPurchasePriceSchedules", {
            "data": {
                "type": "inAppPurchasePriceSchedules",
                "relationships": {
                    "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                    "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p1}"}]},
                },
            },
            "included": [{
                "type": "inAppPurchasePrices", "id": "${p1}",
                "attributes": {"startDate": None},
                "relationships": {
                    "inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}},
                    "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": point}},
                },
            }],
        })
        print(f"  price ${PRICE}", "ok" if r is not None else "FAILED")

    # available in every territory, and in new ones as they open
    terr = call("GET", "/v1/territories", params={"limit": 200})
    ids = [d["id"] for d in (terr or {}).get("data", [])]
    r = call("POST", "/v1/inAppPurchaseAvailabilities", {"data": {
        "type": "inAppPurchaseAvailabilities",
        "attributes": {"availableInNewTerritories": True},
        "relationships": {
            "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
            "availableTerritories": {"data": [{"type": "territories", "id": t} for t in ids]},
        }}}, quiet=True)
    print(f"  availability ({len(ids)} territories)", "ok" if r is not None else "(already set or failed)")
    status()


def screenshot(path: str):
    iid = find_iap(app_id())["id"]
    data = Path(path).read_bytes()
    old = call("GET", f"/v2/inAppPurchases/{iid}/appStoreReviewScreenshot", quiet=True)
    if old and old.get("data"):
        call("DELETE", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{old['data']['id']}")
    made = call("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots",
        "attributes": {"fileName": Path(path).name, "fileSize": len(data)},
        "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}})
    if not made:
        sys.exit("reserve failed")
    shot = made["data"]
    for op in shot["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        requests.request(op["method"], op["url"], data=chunk, headers=headers, timeout=120).raise_for_status()
    r = call("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{shot['id']}", {"data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots", "id": shot["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print("review screenshot", "uploaded" if r is not None else "FAILED")


def free():
    app = app_id()
    points = call("GET", f"/v1/apps/{app}/appPricePoints", params={"filter[territory]": "USA", "limit": 200})
    point = next((d["id"] for d in (points or {}).get("data", [])
                  if float(d["attributes"].get("customerPrice") or 1) == 0), None)
    if not point:
        sys.exit("no free price point")
    r = call("POST", "/v1/appPriceSchedules", {
        "data": {
            "type": "appPriceSchedules",
            "relationships": {
                "app": {"data": {"type": "apps", "id": app}},
                "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                "manualPrices": {"data": [{"type": "appPrices", "id": "${p1}"}]},
            },
        },
        "included": [{
            "type": "appPrices", "id": "${p1}",
            "attributes": {"startDate": None, "endDate": None},
            "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": point}}},
        }],
    })
    print("app price set to Free" if r is not None else "price change FAILED")


def submit():
    iid = find_iap(app_id())["id"]
    r = call("POST", "/v1/inAppPurchaseSubmissions", {"data": {
        "type": "inAppPurchaseSubmissions",
        "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}})
    print("IAP submitted" if r is not None else "IAP submission refused")
    status()


def status():
    app = app_id()
    iap = find_iap(app)
    if not iap:
        print("no IAP")
        return
    print(f"IAP {iap['attributes']['productId']}: {iap['attributes'].get('state')}")
    sched = call("GET", f"/v1/apps/{app}/appPriceSchedule/manualPrices",
                 params={"include": "appPricePoint", "limit": 5}, quiet=True)
    for inc in (sched or {}).get("included", []):
        if inc["type"] == "appPricePoints":
            print(f"app price: {inc['attributes'].get('customerPrice')}")


COMMANDS = {"create": create, "screenshot": screenshot, "free": free, "submit": submit, "status": status}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        sys.exit(__doc__)
    COMMANDS[sys.argv[1]](*sys.argv[2:])
