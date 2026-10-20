"""Game Center for 1.2: three leaderboards and an achievement for every medal.

    python Store/gamecenter.py create           leaderboards + achievements + en-US text (idempotent)
    python Store/gamecenter.py images <dir>     upload <dir>/<medal>.png as each achievement's image
    python Store/gamecenter.py status

IDs must match Sources/Services/GameCenter.swift and the medal ids in Sources/Game/Daily.swift.
"""
import hashlib
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

DETAIL = "77cf5b0f-6467-432c-be91-5ab79c3f7052"

# vendor id, reference name, formatter, sort, recurrence (start, duration) or None, display name, suffix, singular suffix
BOARDS = [
    ("clearthestrait.longest", "Longest Launch", "INTEGER", "DESC", None, "Longest Launch", " m", " m"),
    ("clearthestrait.fastest", "Fastest Clear", "ELAPSED_TIME_CENTISECOND", "ASC", None, "Fastest Clear", None, None),
    ("clearthestrait.daily", "Daily Strait", "INTEGER", "DESC", ("2026-10-21T04:00:00Z", "PT24H"), "Daily Strait: Today's Launch", " m", " m"),
]

# medal id, name, points, before, after
MEDALS = [
    ("first", "Cleared", 10, "Clear your first strait.", "Cleared your first strait."),
    ("combo15", "In the Groove", 30, "Hit a x15 combo.", "Hit a x15 combo."),
    ("combo30", "Metronome", 60, "Hit a x30 combo.", "Hit a x30 combo. The Comet trail is yours."),
    ("tremendous", "Tremendous", 30, "Let his ego reach Tremendous Mode.", "Let his ego reach Tremendous Mode."),
    ("needle", "Needle", 50, "Pop 15 bubbles in one round.", "Popped 15 bubbles in one round."),
    ("quick", "Quick Shove", 70, "Clear a strait in under 50 seconds.", "Cleared a strait in under 50 seconds."),
    ("far", "Long Haul", 40, "Launch him 30,000 m.", "Launched him 30,000 m."),
    ("moon", "Moonshot", 100, "Launch him 100,000 m.", "Launched him 100,000 m. The Gold Coins trail is yours."),
    ("ships", "Harbour Master", 60, "Free 25 ships in one round.", "Freed 25 ships in one round."),
    ("rounds10", "Regular", 30, "Clear 10 straits.", "Cleared 10 straits. The Smoke trail is yours."),
    ("rounds50", "Old Salt", 90, "Clear 50 straits.", "Cleared 50 straits."),
    ("daily", "Daily Driver", 30, "Beat a Daily Strait.", "Beat a Daily Strait."),
    ("streak7", "Week Streak", 100, "Beat the Daily Strait 7 days running.", "Beat the Daily Strait 7 days running."),
    ("season", "Full Season", 100, "Finish all ten goals of a Club Season.", "Finished a whole Club Season. The Season Stars trail is yours."),
]


def listing(rel):
    got = asc.call("GET", f"/v1/gameCenterDetails/{DETAIL}/{rel}", params={"limit": 200}) or {"data": []}
    return {d["attributes"]["vendorIdentifier"]: d for d in got["data"]}


def create():
    have = listing("gameCenterLeaderboards")
    for vendor, ref, fmt, sort, rec, name, suffix, single in BOARDS:
        b = have.get(vendor)
        if not b:
            attrs = {"referenceName": ref, "vendorIdentifier": vendor, "submissionType": "BEST_SCORE",
                     "scoreSortType": sort, "defaultFormatter": fmt}
            if rec:
                attrs.update({"recurrenceStartDate": rec[0], "recurrenceDuration": rec[1], "recurrenceRule": "FREQ=DAILY;INTERVAL=1"})
            made = asc.call("POST", "/v1/gameCenterLeaderboards", {"data": {"type": "gameCenterLeaderboards", "attributes": attrs,
                            "relationships": {"gameCenterDetail": {"data": {"type": "gameCenterDetails", "id": DETAIL}}}}})
            if not made:
                print(vendor, "FAILED")
                continue
            b = made["data"]
        print(f"board {vendor}: {b['id']}")
        locs = asc.call("GET", f"/v1/gameCenterLeaderboards/{b['id']}/localizations") or {"data": []}
        if not any(l["attributes"]["locale"] == "en-US" for l in locs["data"]):
            attrs = {"locale": "en-US", "name": name}
            if suffix:
                attrs.update({"formatterSuffix": suffix, "formatterSuffixSingular": single})
            r = asc.call("POST", "/v1/gameCenterLeaderboardLocalizations", {"data": {"type": "gameCenterLeaderboardLocalizations",
                         "attributes": attrs, "relationships": {"gameCenterLeaderboard": {"data": {"type": "gameCenterLeaderboards", "id": b["id"]}}}}})
            print("  en-US", "ok" if r else "FAILED")
    have = listing("gameCenterAchievements")
    for mid, name, pts, before, after in MEDALS:
        vendor = f"clearthestrait.medal.{mid}"
        a = have.get(vendor)
        if not a:
            made = asc.call("POST", "/v1/gameCenterAchievements", {"data": {"type": "gameCenterAchievements",
                            "attributes": {"referenceName": name, "vendorIdentifier": vendor, "points": pts,
                                           "showBeforeEarned": True, "repeatable": False},
                            "relationships": {"gameCenterDetail": {"data": {"type": "gameCenterDetails", "id": DETAIL}}}}})
            if not made:
                print(vendor, "FAILED")
                continue
            a = made["data"]
        print(f"achievement {vendor}: {a['id']}")
        locs = asc.call("GET", f"/v1/gameCenterAchievements/{a['id']}/localizations") or {"data": []}
        if not any(l["attributes"]["locale"] == "en-US" for l in locs["data"]):
            r = asc.call("POST", "/v1/gameCenterAchievementLocalizations", {"data": {"type": "gameCenterAchievementLocalizations",
                         "attributes": {"locale": "en-US", "name": name, "beforeEarnedDescription": before, "afterEarnedDescription": after},
                         "relationships": {"gameCenterAchievement": {"data": {"type": "gameCenterAchievements", "id": a["id"]}}}}})
            print("  en-US", "ok" if r else "FAILED")


def images(folder):
    have = listing("gameCenterAchievements")
    for mid, *_ in MEDALS:
        a = have.get(f"clearthestrait.medal.{mid}")
        png = Path(folder) / f"{mid}.png"
        if not a or not png.exists():
            print(mid, "skipped")
            continue
        locs = asc.call("GET", f"/v1/gameCenterAchievements/{a['id']}/localizations") or {"data": []}
        for l in locs["data"]:
            cur = asc.call("GET", f"/v1/gameCenterAchievementLocalizations/{l['id']}/gameCenterAchievementImage", quiet=True)
            if cur and cur.get("data"):
                continue
            data = png.read_bytes()
            made = asc.call("POST", "/v1/gameCenterAchievementImages", {"data": {"type": "gameCenterAchievementImages",
                            "attributes": {"fileName": png.name, "fileSize": len(data)},
                            "relationships": {"gameCenterAchievementLocalization": {"data": {"type": "gameCenterAchievementLocalizations", "id": l["id"]}}}}})
            if not made:
                print(mid, l["attributes"]["locale"], "reserve FAILED")
                continue
            for op in made["data"]["attributes"]["uploadOperations"]:
                headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
                requests.request(op["method"], op["url"], headers=headers, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
            r = asc.call("PATCH", f"/v1/gameCenterAchievementImages/{made['data']['id']}", {"data": {"type": "gameCenterAchievementImages",
                         "id": made["data"]["id"], "attributes": {"uploaded": True}}})
            print(mid, l["attributes"]["locale"], "image", "ok" if r else "FAILED")


def status():
    for rel in ["gameCenterLeaderboards", "gameCenterAchievements"]:
        for v, d in listing(rel).items():
            print(rel[10:], v, d["id"], {k: d["attributes"].get(k) for k in ("archived", "points", "recurrenceDuration")})


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "images":
        images(sys.argv[2])
    else:
        {"create": create, "status": status}.get(cmd, lambda: sys.exit(__doc__))()
