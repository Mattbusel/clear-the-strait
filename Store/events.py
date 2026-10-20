"""In-App Event for 1.2: the premiere of the Club Season mode (no recurring challenge events: Guideline 2.3.13).

    python Store/events.py <media dir> [--dry]     media dir: <key>-card.png (1920x1080), <key>-details.png (1080x1920)
    python Store/events.py state

Idempotent (reuses events by reference name). Submitting events for review is done with the version (or in the browser).
"""
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP = "6810644510"
EVENTS = [
    {"key": "season", "ref": "Club Season premiere (Nov 2026)", "badge": "PREMIERE", "deepLink": "clearthestrait://season",
     "purchaseRequirement": "SUBSCRIPTION", "purpose": "KEEP_ACTIVE_USERS_INFORMED", "priority": "HIGH",
     "schedule": {"publishStart": "2026-10-25T16:00:00Z", "eventStart": "2026-11-01T04:00:00Z", "eventEnd": "2026-12-01T04:59:00Z"},
     "copy": {"en-US": ("The Club Season Premieres", "A new mode: ten goals across every channel",
                        "New in 1.2: ten goals through all four channels, harder as you go. Finish them for the Full Season medal.")}},
]


def upload(lid, kind, f):
    data = f.read_bytes()
    made = asc.call("POST", "/v1/appEventScreenshots", {"data": {"type": "appEventScreenshots",
                    "attributes": {"fileName": f.name, "fileSize": len(data), "appEventAssetType": kind},
                    "relationships": {"appEventLocalization": {"data": {"type": "appEventLocalizations", "id": lid}}}}})
    if not made:
        return False
    made = made["data"]
    for op in made["attributes"]["uploadOperations"]:
        h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
        requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
    return bool(asc.call("PATCH", f"/v1/appEventScreenshots/{made['id']}", {"data": {"type": "appEventScreenshots", "id": made["id"], "attributes": {"uploaded": True}}}))


def run(media: Path, dry: bool):
    for e in EVENTS:
        for loc, (n, s, l) in e["copy"].items():
            assert len(n) <= 30 and len(s) <= 50 and len(l) <= 120, (e["key"], loc, len(n), len(s), len(l))
            assert "—" not in n + s + l
    if dry:
        print("copy ok")
        return
    terr = [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]
    have = {x["attributes"]["referenceName"]: x for x in asc.call("GET", f"/v1/apps/{APP}/appEvents", params={"limit": 50})["data"]}
    for e in EVENTS:
        ev = have.get(e["ref"])
        if not ev:
            made = asc.call("POST", "/v1/appEvents", {"data": {"type": "appEvents", "attributes": {
                "referenceName": e["ref"], "badge": e["badge"], "deepLink": e["deepLink"], "purchaseRequirement": e["purchaseRequirement"],
                "primaryLocale": "en-US", "priority": e["priority"], "purpose": e["purpose"],
                "territorySchedules": [dict(territories=terr, **e["schedule"])]},
                "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
            if not made:
                print(e["key"], "create FAILED")
                continue
            ev = made["data"]
        print(e["key"], ev["id"], ev["attributes"].get("eventState"))
        locs = {l["attributes"]["locale"]: l for l in asc.call("GET", f"/v1/appEvents/{ev['id']}/localizations")["data"]}
        for loc, (n, s, l) in e["copy"].items():
            attrs = {"name": n, "shortDescription": s, "longDescription": l}
            if loc in locs:
                asc.call("PATCH", f"/v1/appEventLocalizations/{locs[loc]['id']}", {"data": {"type": "appEventLocalizations", "id": locs[loc]["id"], "attributes": attrs}})
            else:
                made = asc.call("POST", "/v1/appEventLocalizations", {"data": {"type": "appEventLocalizations", "attributes": dict(locale=loc, **attrs),
                                "relationships": {"appEvent": {"data": {"type": "appEvents", "id": ev["id"]}}}}})
                locs[loc] = made["data"]
            lid = locs[loc]["id"]
            got = {x["attributes"]["appEventAssetType"] for x in asc.call("GET", f"/v1/appEventLocalizations/{lid}/appEventScreenshots")["data"]}
            for kind, f in (("EVENT_CARD", media / f"{e['key']}-card.png"), ("EVENT_DETAILS_PAGE", media / f"{e['key']}-details.png")):
                if kind not in got and f.exists():
                    print("  ", loc, kind, "ok" if upload(lid, kind, f) else "FAILED")


def state():
    for x in asc.call("GET", f"/v1/apps/{APP}/appEvents", params={"limit": 50})["data"]:
        print(x["id"], x["attributes"]["referenceName"], x["attributes"]["eventState"])


if __name__ == "__main__":
    if sys.argv[1] == "state":
        state()
    else:
        run(Path(sys.argv[1]), "--dry" in sys.argv)
