"""One offline technical portrait, two budgets; does not import or run a game."""
from pathlib import Path
import argparse
import hashlib
import json
import platform
import sys
import time
import copy

from PIL import Image, ImageDraw
import numpy as np


def export_lua(result, lua_export, name):
    # fill_shaper uses top-left / Y-up; upstream Lua expects bottom-left / Y-up.
    # Adapt only the exporter input; preserve the raw JSON coordinate contract.
    adapted = copy.deepcopy(result)
    height = result["image_size"]["height"] / result["config"]["pixel_per_unit"]
    for element in adapted["elements"]:
        element["center"]["y"] += height
    lua = lua_export.build_lua_export_text(adapted, image_name=name)
    return ("-- DIAGNOSTIC ONLY: unbounded ellipses; PNG preview is cropped.\n"
            "-- Not a production portrait candidate without verified parent clipping.\n" + lua)


def source_image(path):
    # Project-authored geometry, not an official asset or approved final portrait.
    scale = 4
    image = Image.new("RGB", (128 * scale, 128 * scale), "#0F1117")
    d = ImageDraw.Draw(image)
    def poly(points, color):
        d.polygon([(x * scale, y * scale) for x, y in points], fill=color)
    def ellipse(box, color):
        d.ellipse(tuple(x * scale for x in box), fill=color)
    ellipse((21, 7, 106, 112), "#D4AA62")
    poly([(20,105),(34,78),(53,76),(77,76),(97,85),(114,128),(13,128)], "#E8E4DA")
    poly([(41,83),(61,101),(84,82),(93,128),(34,128)], "#6F9EA9")
    poly([(54,76),(75,76),(76,89),(64,100),(52,89)], "#EBCDB5")
    ellipse((37, 25, 93, 86), "#F5DBC2")
    poly([(27,58),(28,27),(47,13),(76,13),(100,30),(95,67),(87,40),(74,32),(62,52),(57,30),(42,47),(37,71)], "#EDD195")
    poly([(29,48),(37,40),(36,96),(24,109)], "#E3BF78")
    poly([(91,41),(99,42),(105,103),(89,89)], "#E3BF78")
    ellipse((45,54,56,63), "#503B2E")
    ellipse((73,54,84,63), "#503B2E")
    ellipse((48,55,54,62), "#D9A443")
    ellipse((75,55,81,62), "#D9A443")
    ellipse((49,55,51,57), "#FFFFFF")
    ellipse((76,55,78,57), "#FFFFFF")
    poly([(59,73),(66,75),(71,72),(65,77)], "#B57569")
    for box in [(91,24,101,35),(87,29,97,40),(97,29,107,40),(92,35,102,45)]:
        ellipse(box, "#E6F2F3")
    ellipse((94,31,100,37), "#8FC1D2")
    poly([(64,101),(71,110),(64,120),(57,110)], "#F0B850")
    poly([(64,105),(67,110),(64,115),(61,110)], "#8C652A")
    image.resize((128,128), Image.Resampling.LANCZOS).save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vendor", required=True, type=Path)
    args = parser.parse_args()
    sys.path.insert(0, str(args.vendor.resolve()))
    import cv2
    import primitive_backend
    import fill_shaper
    import lua_export
    out = Path(__file__).resolve().parent
    source = out / "source.png"
    source_image(source)
    image = cv2.imread(str(source), cv2.IMREAD_UNCHANGED)
    records = []
    for count in (64, 256):
        config = {"num_primitives": count, "allowed_shapes": ["circle"],
                  "detail_scale": 1.0, "workers": 2, "transparent_output": False}
        start = time.perf_counter()
        fit = primitive_backend.fit_image_with_primitive(image, config)
        seconds = time.perf_counter() - start
        elements = fill_shaper.results_to_elements(fit["results"], 1, (64,64), output_alpha=1)
        result = {"mode":"fill", "image_size":{"width":128,"height":128},
                  "config":{"pixel_per_unit":1, **config}, "elements":elements}
        stem = f"portrait-{count}"
        (out / f"{stem}.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        lua = export_lua(result, lua_export, f"TECHNICAL SAMPLE {count}")
        (out / f"{stem}.lua").write_text(lua, encoding="utf-8", newline="\n")
        cv2.imwrite(str(out / f"{stem}.png"), fit["preview"])
        error = image[:,:,:3].astype(float) - fit["preview"][:,:,:3].astype(float)
        mse = float(np.mean(error ** 2))
        records.append({"requested_primitives":count,"exported_controls":len(elements),
                        "fit_seconds":round(seconds,3),"rgb_rmse_0_255":round(mse ** 0.5,3),
                        "psnr_db":round(10*np.log10(255**2/mse),3),
                        "lua_bytes":len(lua.encode("utf-8")),"config":config})
        print(records[-1], flush=True)
    contact = Image.new("RGB", (384,128))
    for i, name in enumerate(("source.png","portrait-64.png","portrait-256.png")):
        contact.paste(Image.open(out/name).convert("RGB"),(i*128,0))
    contact.save(out/"comparison.png")
    metadata = {"upstream_commit":"0526509e73d36b359d3c9bee1104718e4a600ed0",
                "python":sys.version,"opencv":cv2.__version__,"numpy":np.__version__,
                "platform":platform.platform(),"source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),
                "primitive_exe_sha256":hashlib.sha256((args.vendor/"tools/primitive.exe").read_bytes()).hexdigest(),
                "seed":"Upstream seeds from wall clock; reruns are not bit-for-bit deterministic.",
                "runs":records}
    (out/"measurements.json").write_text(json.dumps(metadata, indent=2)+"\n",encoding="utf-8")


if __name__ == "__main__":
    main()
