"""Deterministic, bounded native rectangles from existing approved previews.

Original artwork is never modified. The manifest records the reduced display
resolution and source hashes; these are performance candidates, not pixel-exact
copies of the full primitive exports.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


def rectangles(image, grid, canvas, transparent):
    small = image.convert("RGBA").resize(grid, Image.Resampling.BOX)
    pixels = list(small.getdata())
    result, previous = [], {}
    for y in range(grid[1]):
        current, x = {}, 0
        while x < grid[0]:
            rgba = pixels[y * grid[0] + x]
            color = tuple(min(255, round(c / 8) * 8) for c in rgba[:3]) + (rgba[3] if transparent else 255,)
            end = x + 1
            while end < grid[0]:
                other = pixels[y * grid[0] + end]
                candidate = tuple(min(255, round(c / 8) * 8) for c in other[:3]) + (other[3] if transparent else 255,)
                if candidate != color:
                    break
                end += 1
            if color[3] >= 8:
                key = (x, end - x, color)
                old = previous.get(key)
                if old is not None:
                    result[old][3] += 1
                    current[key] = old
                else:
                    current[key] = len(result)
                    result.append([x, y, end - x, 1, color])
            x = end
        previous = current
    rows, encoded = [], []
    for x, y, width, height, color in result:
        left, right = round(x * canvas[0] / grid[0]), round((x + width) * canvas[0] / grid[0])
        top, bottom = round(y * canvas[1] / grid[1]), round((y + height) * canvas[1] / grid[1])
        w, h = right - left, bottom - top
        rows.append([100001, left + w / 2 - canvas[0] / 2, canvas[1] / 2 - top - h / 2,
                     w, h, .5, .5, .5, .5, .5, .5, 1, 1, 0, *color])
        if canvas == (144, 64):
            encoded.append(f"{left:02x}{top:02x}{w:02x}{h:02x}{color[0]:02x}{color[1]:02x}{color[2]:02x}")
    return rows, "".join(encoded)


def build(root):
    converted = json.loads((root / "art/cards/traveler-geo/runtime-candidate/rectangles.json").read_text(encoding="utf-8"))
    cards = json.loads((root / "data/cards.json").read_text(encoding="utf-8"))["cards"]
    specs = [(c["id"], converted["cards"].get(c["id"], {}).get("sourcePreviewPath",
              f'art/cards/traveler-geo/{c["id"]}/preview-native.png'), (48, 22), (144, 64), False)
             for c in cards if c["type"] not in ("status", "curse")]
    specs += [
        ("background", "art/characters/key-visual/traveler-geo/official-landscape-v1/preview-native.png", (80, 45), (480, 270), False),
        ("avatar96", "art/characters/traveler-geo/portraits/avatar96/preview-native-1x.png", (32, 32), (96, 96), True),
        ("battle133", "art/characters/traveler-geo/portraits/battle133/preview-native-1x.png", (48, 48), (133, 133), True),
    ]
    assets = {}
    for name, source, grid, canvas, transparent in specs:
        path = root / source
        with Image.open(path) as image:
            rows, encoded = rectangles(image, grid, canvas, transparent)
        assets[name] = {"source": source, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                        "grid": grid, "canvas": canvas, "count": len(rows)}
        if name in ("background", "avatar96", "battle133"):
            assets[name]["rows"] = rows
        else:
            assets[name]["rectangles"] = encoded
    if len(assets) != 78:
        raise ValueError("Expected 75 cards and 3 character/background assets")
    return {"schemaVersion": 1, "profile": "compact-v1", "degradation": "BOX downsample; RGB quantization step 8; original assets preserved", "assets": assets}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    pack = build(root)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(pack, separators=(",", ":")), encoding="utf-8")
    print(json.dumps({"assets": len(pack["assets"]), "maxCardRectangles": max(a["count"] for a in pack["assets"].values() if "rectangles" in a),
                      "background": pack["assets"]["background"]["count"], "avatar": pack["assets"]["avatar96"]["count"], "battle": pack["assets"]["battle133"]["count"]}))
