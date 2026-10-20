"""The Icon Pack: the app icon recoloured into the three pack channels' water and land.

    python Store/art/icons.py

Writes Resources/Assets.xcassets/AppIcon-<Name>.appiconset from the main icon. The icon is flat
colour, so the land, water and sand are swapped exactly, with anti-aliased edges blended toward
the new colour by distance.
"""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / "Resources" / "Assets.xcassets"
SRC = ROOT / "AppIcon.appiconset" / "icon-1024.png"

LAND, WATER, SAND, STRIPE = (112, 199, 112), (16, 107, 163), (247, 227, 168), (33, 153, 209)


def rgb(r, g, b):
    return (round(r * 255), round(g * 255), round(b * 255))


THEMES = {
    "Night": {LAND: rgb(0.16, 0.30, 0.26), WATER: rgb(0.09, 0.20, 0.38), SAND: rgb(0.42, 0.46, 0.40), STRIPE: rgb(0.28, 0.42, 0.66)},
    "Marina": {LAND: rgb(0.98, 0.86, 0.62), WATER: rgb(0.10, 0.62, 0.66), SAND: rgb(1.00, 0.95, 0.80), STRIPE: rgb(0.42, 0.85, 0.82)},
    "Fog": {LAND: rgb(0.55, 0.64, 0.56), WATER: rgb(0.42, 0.56, 0.64), SAND: rgb(0.86, 0.85, 0.78), STRIPE: rgb(0.66, 0.76, 0.80)},
}


def dist(a, b):
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def main():
    src = Image.open(SRC).convert("RGB")
    px = src.load()
    w, h = src.size
    for name, swap in THEMES.items():
        out = src.copy()
        op = out.load()
        for y in range(h):
            for x in range(w):
                c = px[x, y]
                for old, new in swap.items():
                    d = dist(c, old)
                    if d < 40:
                        k = 1 - d / 40
                        op[x, y] = tuple(round(c[i] + (new[i] - old[i]) * k) for i in range(3))
                        break
        folder = ROOT / f"AppIcon-{name}.appiconset"
        folder.mkdir(exist_ok=True)
        out.save(folder / "icon-1024.png")
        (folder / "Contents.json").write_text(json.dumps({"images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
                                                          "info": {"author": "xcode", "version": 1}}, indent=2))
        print("wrote", name)


if __name__ == "__main__":
    main()
