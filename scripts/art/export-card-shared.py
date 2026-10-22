"""Author a small shared card kit; export with the pinned upstream editor only."""

import argparse
import hashlib
import importlib.metadata
import json
import math
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
UPSTREAM_COMMIT = "103025f9095d8089e3f9bf097f4d0c5fe039d546"
OUTPUT = ROOT / "art/cards/shared"


def blend(front, back, amount):
    return "#" + "".join(f"{round(int(front[i:i+2], 16)*amount + int(back[i:i+2], 16)*(1-amount)):02X}"
                         for i in (1, 3, 5))


def artifact_hash(path):
    data = path.read_bytes()
    if path.suffix != ".png":
        data = data.replace(b"\r\n", b"\n")
    return hashlib.sha256(data).hexdigest()


def scene(name, size):
    return dict(canvas=dict(width=size[0], height=size[1], background="transparent",
                            mask=dict(enabled=False)), elements=[],
                meta=dict(sourceType="json", sourceName=name))


def shape(source, name, kind, x, y, width, height, color, rotation=0):
    source["elements"].append(dict(id=name, name=name, type=kind, x=x, y=y,
                                   width=width, height=height, color=color,
                                   rotation=rotation, zIndex=len(source["elements"])))


def textbox(source, name, x, y, width, height, size, color, minimum):
    shape(source, name, "textbox", x, y, width, height, color)
    source["elements"][-1]["textBox"] = dict(
        text="", fontSize=size, minFontSize=minimum, autoSize=True,
        textColor=color, bgOpacity=0, outlineEnabled=False,
        alignH="center", alignV="middle")


def frame(theme, rarity):
    c, f, sp, layout = theme["color"], theme["font"], theme["space"], theme["layout"]["card"]
    w, h = layout["size"]
    margin, border = sp["l"], sp["border"]
    source = scene("frame-" + rarity, (w + margin * 2, h + margin * 2))
    cx, cy = margin + w / 2, margin + h / 2
    inner = w - border * 2
    name_y = margin + border + layout["nameBand"] / 2
    art_y = margin + border + layout["nameBand"] + layout["art"] / 2
    type_y = margin + border + layout["nameBand"] + layout["art"] + layout["typeLine"] / 2
    shape(source, "rarity-frame", "rectangle", cx, cy, w, h, c["rarity"][rarity])
    shape(source, "card-panel", "rectangle", cx, cy, inner, h - border * 2, c["panel"])
    shape(source, "name-band", "rectangle", cx, name_y, inner, layout["nameBand"], c["panelRaised"])
    # Neutral shared slot: tint from cardType only when composing an actual card.
    shape(source, "art-panel", "rectangle", cx, art_y, inner, layout["art"], c["panel"])
    shape(source, "type-band", "rectangle", cx, type_y, inner, layout["typeLine"], c["panelSunken"])
    textbox(source, "card-title", cx, name_y, w, 40, f["cardName"], c["text"], f["minimum"])
    textbox(source, "card-type", cx, type_y, inner, 40, f["small"], c["textDim"], f["minimum"])
    tw, th = layout["textBox"]
    textbox(source, "card-description", cx, margin + h - th / 2 - sp["xs"], tw, th,
            f["card"], c["text"], f["minimum"])
    diameter = layout["costDisc"]
    cost = margin + diameter / 4
    for name, d, color in (("cost-outline", diameter + 2 * (border + sp["hairline"]), c["goldBright"]),
                           ("cost-separator", diameter + 2 * border, c["backdrop"]),
                           ("cost-energy", diameter, c["energy"])):
        shape(source, name, "ellipse", cost, cost, d, d, color)
    textbox(source, "card-cost", cost, cost, diameter, diameter, f["number"], c["textOnLight"], f["minimum"])
    return source


def crystal(source, center, scale, colors):
    x, y = center
    for name, kind, w, h, color, rotation in (
        ("geo-outline", "rectangle", 26, 26, colors["geoDeep"], 45),
        ("geo-body", "rectangle", 20, 20, colors["geo"], 45),
        ("geo-face", "triangle", 12, 18, colors["goldBright"], 0),
    ):
        shape(source, name, kind, x, y, w * scale, h * scale, color, rotation)


def card_back(theme):
    c, layout, sp = theme["color"], theme["layout"]["card"], theme["space"]
    w, h = layout["size"]
    margin, border = sp["l"], sp["border"]
    source = scene("card-back", (w + margin * 2, h + margin * 2))
    cx, cy = margin + w / 2, margin + h / 2
    for name, dw, dh, color in (
        ("back-frame", 0, 0, c["goldDim"]),
        ("back-panel", border * 2, border * 2, c["panel"]),
        ("back-inset-line", sp["s"] * 2, sp["s"] * 2, c["goldDim"]),
        ("back-inset-panel", sp["s"] * 2 + 2 * sp["hairline"],
         sp["s"] * 2 + 2 * sp["hairline"], c["panelSunken"]),
    ):
        shape(source, name, "rectangle", cx, cy, w - dw, h - dh, color)
    crystal(source, (cx, cy), 1.6, c)
    return source


def type_icon(theme, card_type):
    source = scene("type-" + card_type, (40, 40))
    c = theme["color"]
    color = blend(c["cardType"][card_type], "#FFFFFF", .45)
    if card_type == "attack":
        # A single sword, matching the approved semantic silhouette.
        shape(source, "blade", "rectangle", 20, 15, 5, 20, color)
        shape(source, "blade-tip", "triangle", 20, 4, 5, 6, color)
        shape(source, "guard", "rectangle", 20, 26, 16, 4, color)
        shape(source, "grip", "rectangle", 20, 32, 4, 8, color)
    elif card_type == "skill":
        shape(source, "shield-upper", "rectangle", 20, 14, 26, 17, color)
        shape(source, "shield-point", "triangle", 20, 27, 26, 19, color, 180)
    else:
        crystal(source, (20, 20), 1, c)
    return source


def verify(source, upstream, lua_scene, output):
    normalized = upstream.parse_json_scene(output.with_suffix(".json").read_text(encoding="utf-8"))
    lua = output.with_suffix(".lua").read_text(encoding="utf-8")
    assert upstream.parse_lua_scene(lua).elements == normalized.elements
    assert len(source["elements"]) == len(normalized.elements)
    drawing = lua_scene.read_drawing(lua)
    if any(e.type == "textbox" for e in normalized.elements):
        assert len(drawing["order"]) == len(normalized.elements)
    else:
        assert len(drawing["rows"]) == len(normalized.elements)
    assert "local IMAGE_PREFAB_ID = 0" in lua
    texts = [e for e in normalized.elements if e.type == "textbox"]
    if texts:
        assert "local TEXTBOX_PREFAB_ID = 0" in lua
    for e in normalized.elements:
        # Rotated bounds, rather than unrotated rectangles, must fit the canvas.
        angle = math.radians(e.rotation)
        w = abs(e.width * math.cos(angle)) + abs(e.height * math.sin(angle))
        h = abs(e.width * math.sin(angle)) + abs(e.height * math.cos(angle))
        assert 0 <= e.x - w / 2 and e.x + w / 2 <= normalized.canvas.width
        assert 0 <= e.y - h / 2 and e.y + h / 2 <= normalized.canvas.height
        if e.type == "textbox":
            assert e.textBox.minFontSize >= 14 and e.textBox.bgOpacity == 0
            assert e.textBox.text == "" and e.height >= 40
        else:
            assert upstream.element_asset_id(e) in (100001, 100002, 100003)
    return dict(id=output.name, canvas=[normalized.canvas.width, normalized.canvas.height],
                controls=len(normalized.elements), images=len(normalized.elements) - len(texts),
                nativeTextboxes=len(texts), staticImageIds=sorted({upstream.element_asset_id(e)
                    for e in normalized.elements if e.type != "textbox"}),
                elements={e.id: dict(type=e.type, index=i + 1,
                    center=[e.x, e.y], platformCenter=[e.x-normalized.canvas.width/2,
                    normalized.canvas.height/2-e.y], size=[e.width, e.height],
                    staticImageId=upstream.element_asset_id(e))
                    for i, e in enumerate(normalized.elements)})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--editor", type=Path, required=True)
    parser.add_argument("--fengari", type=Path, help="Existing Fengari module; run upstream textbox VM checker")
    args = parser.parse_args()
    editor = args.editor.resolve()
    actual = subprocess.check_output(["git", "-C", str(editor), "rev-parse", "HEAD"], text=True).strip()
    if actual != UPSTREAM_COMMIT:
        parser.error(f"Expected editor {UPSTREAM_COMMIT}; found {actual}")
    sys.path.insert(0, str(editor / "backend"))
    from app import main as upstream, lua_scene
    from PIL import Image, ImageDraw

    theme_path, cards_path = ROOT / "data/presentation/ui_theme.json", ROOT / "data/cards.json"
    theme = json.loads(theme_path.read_text(encoding="utf-8"))
    cards = json.loads(cards_path.read_text(encoding="utf-8"))["cards"]
    rarities = [r for r in theme["color"]["rarity"] if any(c["rarity"] == r for c in cards)]
    types = [t for t in theme["color"]["cardType"] if any(c["type"] == t for c in cards)]
    sources = {"frame-" + r: frame(theme, r) for r in rarities}
    sources["card-back"] = card_back(theme)
    sources.update({"type-" + t: type_icon(theme, t) for t in types})
    OUTPUT.mkdir(parents=True, exist_ok=True)
    records = []
    for name, source in sources.items():
        output = OUTPUT / name
        output.with_suffix(".source.json").write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        imported = upstream.import_scene(upstream.ImportRequest(sourceType="json", content=json.dumps(source)))
        request = upstream.ExportRequest(scene=imported.scene, giaGroupName="Abyss_Shared_" + name)
        for extension, exporter in (("json", upstream.export_json), ("lua", upstream.export_lua), ("png", upstream.export_png)):
            output.with_suffix("." + extension).write_bytes(exporter(request).body)
        records.append(verify(source, upstream, lua_scene, output))

    # A review sheet only; it is not exported to the platform or used by the UI.
    sheet = Image.new("RGBA", (940, 360), theme["color"]["backdrop"])
    draw = ImageDraw.Draw(sheet)
    for i, name in enumerate(sources):
        image = Image.open(OUTPUT / (name + ".png")).convert("RGBA")
        x, y = (i * 188, 30) if i < 5 else (200 + (i-5) * 188, 296)
        sheet.alpha_composite(image, (x, y))
        draw.text((x + 16, y - 18), name, fill=theme["color"]["text"])
    sheet.save(OUTPUT / "contact-sheet.png")

    license_dir = OUTPUT / "licenses"
    license_dir.mkdir(exist_ok=True)
    for source, name in ((editor / "LICENSE", "EDITOR-GPL-3.0.txt"),
                         (editor / "backend/vendor/primitive_shape/LICENSE", "PRIMITIVE-SHAPE-MIT.txt")):
        (license_dir / name).write_bytes(source.read_bytes())
    vm_result = "not run: pass --fengari; JSON/Lua parse round-trip is not VM execution"
    if args.fengari:
        fengari = args.fengari.resolve()
        # fengaric 0.1.0 splits require.resolve() on '/', which fails on Windows.
        # Use its public VM parser directly; do not edit the installed package.
        syntax_check = (
            "const {lua,lauxlib,to_jsstring}=require(process.argv[1]);"
            "const L=lauxlib.luaL_newstate();"
            "const src=require('node:fs').readFileSync(process.argv[2]);"
            "if(lauxlib.luaL_loadbuffer(L,src,src.length,'asset')!==lua.LUA_OK)"
            "throw Error(to_jsstring(lua.lua_tostring(L,-1)));"
        )
        for name in sources:
            subprocess.run(["node", "-e", syntax_check, str(fengari), str(OUTPUT / (name + ".lua"))], check=True)
        for rarity in rarities:
            name = "frame-" + rarity
            subprocess.run(["node", str(editor / "backend/tests/check_textbox_lua.cjs"),
                            str(fengari), str(OUTPUT / (name + ".lua")),
                            str(OUTPUT / (name + ".json"))], check=True)
        vm_result = "passed: 8 Lua syntax checks; 4 frames with upstream textbox VM checker (12 controls each); image-only runtime not executed"
    manifest = dict(editorCommit=actual, templateIndices=dict(image=0, textbox=0),
        sourceData=dict(rarities=rarities, types=types, cardCount=len(cards)),
        nativeShapeIds=dict(rectangle=100001, ellipse=100002, triangle=100003),
        targetLibraryIcons={t: theme["icon"]["cardArt"][t] for t in types},
        artTint={t: blend(theme["color"]["cardType"][t], theme["color"]["panel"], .32) for t in types},
        assets=records)
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = dict(editorCommit=actual, python=sys.version.split()[0],
        dependencies={n: importlib.metadata.version(n) for n in ("fastapi", "pillow", "pydantic", "uvicorn")},
        checks=["all 8 JSON/Lua normalized element round-trips", "complete mixed draw order",
                "rotated canvas bounds", "only verified primitive image IDs", "empty native text slots; minimum 14; height >=40",
                "template indices remain zero"],
        platformCompile="not run", saveImport="not run", devicePlaytest="not run",
        luaVM=vm_result,
        hashConvention="SHA-256; text CRLF normalized to LF for Git portability; PNG raw bytes",
        sha256={p.relative_to(ROOT).as_posix(): artifact_hash(p)
                for p in [theme_path, cards_path, Path(__file__), *sorted(OUTPUT.glob("*.source.json")),
                          *sorted(OUTPUT.glob("*.json")), *sorted(OUTPUT.glob("*.lua")),
                          *sorted(OUTPUT.glob("*.png")), *sorted(license_dir.glob("*.txt"))]
                if p.name != "verification.json"})
    (OUTPUT / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({r["id"]: [r["images"], r["nativeTextboxes"]] for r in records}))


if __name__ == "__main__":
    main()
