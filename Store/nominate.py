"""Featuring nomination for 1.2 (App Store Connect > Featuring > Nominations), through the API."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP = "6810644510"
NAME = "Clear the Strait 1.2: the Club Season and Game Center"
DESC = ("Clear the Strait is a one-thumb physics arcade game: a round, self-important cartoon blowhard is wedged in a "
        "shipping channel, and the player shoves him out in time with his rocking while popping the compliments that float "
        "back to inflate his ego. Version 1.2 turns it into a daily habit: the Daily Strait (one challenge a day, the same for "
        "everyone, with streaks), a monthly Club Season of ten goals across four channels, Game Center leaderboards including a "
        "recurring daily board and 14 achievements, Home and Lock Screen widgets, an iOS 18 Control Center control, App "
        "Shortcuts for Siri, TipKit tips and a first-round coach. An In-App Event premieres the Club Season "
        "in November. No account, no adverts, no tracking; sound is synthesised on device, everything else is SwiftUI "
        "and SpriteKit.")

if __name__ == "__main__":
    have = []
    for st in ("DRAFT", "SUBMITTED"):
        got = asc.call("GET", "/v1/nominations", params={"limit": 50, "filter[state]": st, "include": "relatedApps"})
        have += [d for d in (got or {}).get("data", []) if d["attributes"].get("name") == NAME]
    if have:
        print("exists", have[0]["id"], have[0]["attributes"].get("state")); sys.exit()
    r = asc.call("POST", "/v1/nominations", {"data": {"type": "nominations", "attributes": {
        "name": NAME, "type": "APP_ENHANCEMENTS", "description": DESC, "submitted": True,
        "publishStartDate": "2026-10-28T00:00:00Z", "deviceFamilies": ["IPHONE"], "hasInAppEvents": True,
        "locales": ["en-US", "en-GB", "en-AU", "en-CA", "ja", "ko", "zh-Hans", "es-MX", "es-ES", "de-DE", "fr-FR", "pt-BR", "it"]},
        "relationships": {"relatedApps": {"data": [{"type": "apps", "id": APP}]}}}})
    print(json.dumps(r["data"]["attributes"]) if r else "FAILED")
