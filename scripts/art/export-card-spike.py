"""One-card data fixture; all conversions come from the pinned upstream editor."""

import argparse
import copy
import hashlib
import importlib.metadata
import json
from pathlib import Path
import subprocess
import sys


UPSTREAM_COMMIT = "103025f9095d8089e3f9bf097f4d0c5fe039d546"
ROOT = Path(__file__).resolve().parents[2]


def native_text_height_candidate(source):
    """Test only the short-box hypothesis; the platform's padding is undocumented."""
    candidate = copy.deepcopy(source)
    elements = {element["id"]: element for element in candidate["elements"]}
    # The cost textbox rendered on the same device at height 40 / font size 22.
    # Keep center, width, fonts, middle alignment and every other property intact.
    observed_visible_height = elements["card-cost"]["height"]
    for name in ("card-title", "card-type"):
        elements[name]["height"] = max(elements[name]["height"], observed_visible_height)
    return candidate


def compose(theme, card):
    c, font, space = theme["color"], theme["font"], theme["space"]
    layout = theme["layout"]["card"]
    width, height = layout["size"]
    border, margin = space["border"], space["l"]
    canvas_width, canvas_height = width + 2 * margin, height + 2 * margin
    elements = []

    def shape(name, kind, left, top, w, h, color, **extra):
        element = dict(id=name, name=name, type=kind, x=left + w / 2,
                       y=top + h / 2, width=w, height=h, color=color,
                       zIndex=len(elements), **extra)
        elements.append(element)
        return element

    def text(name, value, left, top, w, h, size, color):
        shape(name, "textbox", left, top, w, h, color, textBox=dict(
            text=value, fontSize=size, minFontSize=font["minimum"],
            autoSize=True, textColor=color, bgOpacity=0,
            outlineEnabled=False, alignH="center", alignV="middle"))

    x, y = margin, margin
    shape("rarity-frame", "rectangle", x, y, width, height, c["rarity"][card["rarity"]])
    shape("card-panel", "rectangle", x + border, y + border,
          width - 2 * border, height - 2 * border, c["panel"])
    inner = width - 2 * border
    band, art_height, type_height = layout["nameBand"], layout["art"], layout["typeLine"]
    shape("name-band", "rectangle", x + border, y + border, inner, band, c["panelRaised"])
    # Match the approved prototype's 32% attack tint over the panel.
    def blend(a, b):
        return "#" + "".join(f"{round(int(a[i:i+2], 16)*.32 + int(b[i:i+2], 16)*.68):02x}"
                             for i in (1, 3, 5))
    art_y = y + border + band
    shape("attack-art-panel", "rectangle", x + border, art_y, inner, art_height,
          blend(c["cardType"][card["type"]], c["panel"]))
    # Deliberately a geometric placeholder, not character art or a new mechanic.
    center = x + width / 2
    shape("geo-crystal-outline", "rectangle", center - 13, art_y + 19, 26, 26,
          c["geoDeep"], rotation=45)
    shape("geo-crystal", "rectangle", center - 10, art_y + 22, 20, 20,
          c["geo"], rotation=45)
    shape("geo-crystal-face", "triangle", center - 6, art_y + 23, 12, 18, c["goldBright"])
    type_y = art_y + art_height
    shape("type-band", "rectangle", x + border, type_y, inner, type_height, c["panelSunken"])
    text("card-title", card["name"], x, y + 6, width, 22, font["cardName"], c["text"])
    text("card-type", "攻击", x + border, type_y, inner, type_height,
         font["small"], c["textDim"])
    text_width, text_height = layout["textBox"]
    text("card-description", card["text"], center - text_width / 2,
         y + height - text_height - space["xs"], text_width, text_height,
         font["card"], c["text"])
    diameter = layout["costDisc"]
    cost_x, cost_y = x - diameter / 4, y - diameter / 4
    # Nested solid discs replace the prototype's CSS outline; no Lua masks.
    shape("cost-outline", "ellipse", cost_x - border - space["hairline"],
          cost_y - border - space["hairline"], diameter + 2 * (border + space["hairline"]),
          diameter + 2 * (border + space["hairline"]), c["goldBright"])
    shape("cost-separator", "ellipse", cost_x - border, cost_y - border,
          diameter + 2 * border, diameter + 2 * border, c["backdrop"])
    shape("cost-energy", "ellipse", cost_x, cost_y, diameter, diameter, c["energy"])
    text("card-cost", str(card["cost"]), cost_x, cost_y, diameter, diameter,
         font["number"], c["textOnLight"])
    return dict(canvas=dict(width=canvas_width, height=canvas_height,
                            background="transparent", mask=dict(enabled=False)),
                elements=elements, meta=dict(sourceType="json", sourceName="geo-strike-card-spike"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--editor", type=Path, required=True, help="Pinned upstream checkout")
    parser.add_argument("--text-height-compat", action="store_true",
                        help="Export the height-only candidate separately; preserves original outputs")
    args = parser.parse_args()
    editor = args.editor.resolve()
    actual = subprocess.check_output(["git", "-C", str(editor), "rev-parse", "HEAD"], text=True).strip()
    if actual != UPSTREAM_COMMIT:
        parser.error(f"Expected editor {UPSTREAM_COMMIT}; found {actual}")
    sys.path.insert(0, str(editor / "backend"))
    from app import main as upstream
    from app import lua_scene
    from vendor.primitive_shape.gia_lua import (
        _children, _components, _fields, _get, _message, _messages, _transform,
    )

    theme_path, card_path = ROOT / "data/presentation/ui_theme.json", ROOT / "data/cards.json"
    theme = json.loads(theme_path.read_text(encoding="utf-8"))
    card = next(c for c in json.loads(card_path.read_text(encoding="utf-8"))["cards"] if c["id"] == "strike")
    output = ROOT / "art/spikes/card-editor"
    if args.text_height_compat:
        output = output / "text-height-compat"
    output.mkdir(parents=True, exist_ok=True)
    source = compose(theme, card)
    if args.text_height_compat:
        source = native_text_height_candidate(source)
    (output / "card.source.json").write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    imported = upstream.import_scene(upstream.ImportRequest(sourceType="json", content=json.dumps(source)))
    scene = imported.scene
    request = upstream.ExportRequest(scene=scene, giaGroupName="Abyss_Geo_Card_Spike")
    exporters = {"json": upstream.export_json, "lua": upstream.export_lua,
                 "gia": upstream.export_gia, "png": upstream.export_png}
    for extension, exporter in exporters.items():
        (output / f"card.{extension}").write_bytes(exporter(request).body)
    gia_document = upstream.scene_to_gia_document(scene, request.giaGroupName)
    (output / "card.gia-document.json").write_text(json.dumps(gia_document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # Verify independent read paths instead of equating file creation with validity.
    json_scene = upstream.parse_json_scene((output / "card.json").read_text(encoding="utf-8"))
    lua_text = (output / "card.lua").read_text(encoding="utf-8")
    lua_roundtrip = upstream.parse_lua_scene(lua_text)
    assert json_scene.elements == scene.elements == lua_roundtrip.elements
    drawing = lua_scene.read_drawing(lua_text)
    expected_assets = [upstream.element_asset_id(e) for e in scene.elements if e.type != "textbox"]
    gia_bytes = (output / "card.gia").read_bytes()
    assert int.from_bytes(gia_bytes[:4], "big") == len(gia_bytes) - 4
    assert int.from_bytes(gia_bytes[16:20], "big") == len(gia_bytes) - 24
    gia_root = _fields(gia_bytes[20:-4])
    root_content = _message(_message(next(_messages(gia_root, 1)), 19), 1)
    units = [_message(_message(unit, 19), 1) for unit in _messages(gia_root, 2)]
    units_by_id = {_get(unit, 501): unit for unit in units}
    ordered_units = [units_by_id[guid] for guid in reversed(_children(root_content)) if guid in units_by_id]
    assert len(ordered_units) == len(scene.elements)
    records = []
    for unit, element in zip(ordered_units, scene.elements):
        parts = _components(unit)
        if element.type == "textbox":
            assert 25 in parts
            transform = _transform(parts)
            assert transform[:4] == [element.x - scene.canvas.width / 2,
                                     scene.canvas.height / 2 - element.y,
                                     element.width, element.height]
        else:
            image = _message(_message(parts.get(38, {}), 503), 31)
            records.append([_get(image, 2)] + _transform(parts))
    assert [row[0] for row in records] == expected_assets
    payloads = [gia_bytes[20:-4]]
    for tag in (2, 19, 1, 505, 503, 19):
        payloads = [value for data in payloads for wire, value in _fields(data).get(tag, []) if wire == 2]
    text_elements = [e for e in scene.elements if e.type == "textbox"]
    assert len(payloads) == len(text_elements) == 4
    # Binary resource units are not serialized in drawing order; GUID references are.
    assert all(any(e.textBox.text.encode("utf-8") in payload for payload in payloads) for e in text_elements)
    assert len(drawing["order"]) == len(scene.elements)
    assert all(e.textBox is None or e.textBox.minFontSize >= theme["font"]["minimum"] for e in scene.elements)
    image_index = 0
    for element, payload in zip(scene.elements, gia_document["elements"]):
        assert payload["relative"] == {"x": element.x - scene.canvas.width / 2,
                                        "y": scene.canvas.height / 2 - element.y}
        if element.type != "textbox":
            assert records[image_index][1:5] == [payload["relative"]["x"], payload["relative"]["y"], element.width, element.height]
            image_index += 1
    report = dict(editorCommit=actual, python=sys.version.split()[0],
                  dependencies={name: importlib.metadata.version(name) for name in ("fastapi", "pillow", "pydantic", "uvicorn")},
                  cardId=card["id"], canvas=[scene.canvas.width, scene.canvas.height],
                  controls=len(scene.elements), images=len(records), nativeTextboxes=len(payloads),
                  staticImageIds=sorted(set(expected_assets)),
                  checks=["JSON/Lua normalized element round-trip", "GIA image count/asset/geometry independent reader",
                          "GIA native UTF-8 textbox payloads", "GIA native textbox centers/sizes independent reader",
                          "Y-up center conversion", "DRAW_ORDER complete", "minimum font 14"],
                  platformCompile="not run", saveImport="not run", devicePlaytest="not run",
                  imageTemplateIndex=None, textboxTemplateIndex=None,
                  sha256={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in
                          [theme_path, card_path, output / "card.source.json", *(output / f"card.{ext}" for ext in exporters)]})
    if args.text_height_compat:
        report["compatibilityCandidate"] = {
            "hypothesis": "Short native textboxes may not contain a full font line; internal padding is undocumented",
            "change": "Only card-title height 22 -> 40 and card-type height 18 -> 40; same center/font/style/layers",
            "reference": "Parent-supplied real-device screenshot: cost height40/font22 and description height92/font15 visible; title/type missing",
            "candidateDevicePlaytest": "not run; parent must confirm title/type appear",
            "comparisonInputSha256": hashlib.sha256((output.parent / "card.source.json").read_bytes()).hexdigest(),
        }
    (output / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ("controls", "images", "nativeTextboxes", "checks")}, ensure_ascii=False))


if __name__ == "__main__":
    main()
