"""Check existing alpha bytes/rectangle occupancy, without rendering or fixing art.

Exit 1 truthfully records a canonical PNG alpha mismatch; Lua RGBA preservation
is a separate result. Neither result establishes native rendering or cleanup.
"""
import argparse
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from export_portrait import load_cache, record, verify_literal


def stats(values, width):
    nonzero = [(i % width, i // width) for i, value in enumerate(values) if value]
    return {'pixels': len(values), 'zero': values.count(0), 'partial': sum(0 < v < 255 for v in values),
            'opaque': values.count(255), 'min': min(values), 'max': max(values),
            'nonzeroBoundsLTRB': ([min(x for x, y in nonzero), min(y for x, y in nonzero),
                                   max(x for x, y in nonzero) + 1, max(y for x, y in nonzero) + 1] if nonzero else None)}


def rectangle_plane(rows, width, height):
    """Integer half-open cells, not an image exporter/Pillow polygon renderer."""
    plane, coverage = [0] * (width * height), [0] * (width * height)
    for x, y, w, h, alpha in rows:
        values = [x - w / 2, y - h / 2, x + w / 2, y + h / 2]
        if any(v != round(v) for v in values) or not (0 < alpha <= 255):
            raise ValueError('Require positive-alpha integer-grid rectangles')
        left, top, right, bottom = map(round, values)
        if not (0 <= left < right <= width and 0 <= top < bottom <= height):
            raise ValueError('Rectangle outside alpha plane')
        for py in range(top, bottom):
            for px in range(left, right):
                index = py * width + px
                coverage[index] += 1
                if coverage[index] != 1:
                    raise ValueError('Authoring rectangles overlap in half-open cells')
                plane[index] = alpha
    return plane, coverage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache-root', type=Path, required=True)
    parser.add_argument('--asset-directory', type=Path, required=True)
    args = parser.parse_args()
    folder = args.asset_directory.resolve()
    target = folder / 'alpha-verification.json'
    if target.exists():
        raise ValueError('Do not overwrite prior alpha evidence')
    upstream, literal, loader = load_cache(args.cache_root)
    from PIL import Image
    names = ['source.png', 'preview-source-1x.png', 'preview-redraw-draft-1x.png',
             'native-art.json', 'native-art.lua', 'preview-native-1x.png']
    inputs = [record(folder / name) for name in names]
    scene = upstream.parse_json_scene((folder / 'native-art.json').read_text())
    drawing = verify_literal(upstream, literal, scene, (folder / 'native-art.lua').read_bytes())
    width, height = int(scene.canvas.width), int(scene.canvas.height)
    ordered = sorted(scene.elements, key=lambda e: (not e.isBackground, e.zIndex))
    if any(e.type != 'rectangle' or e.rotation or e.rotationX or e.rotationY for e in ordered):
        raise ValueError('This occupancy check requires the unchanged axis-aligned region draft')
    expected, coverage = rectangle_plane([(e.x, e.y, e.width, e.height, round(e.opacity * 255)) for e in ordered], width, height)
    actual_rows = drawing['rows']
    lua_plane, lua_coverage = rectangle_plane([(r[1] + width / 2, height / 2 - r[2], r[3], r[4], r[17]) for r in actual_rows], width, height)
    planes, image_stats = {}, {}
    for name in ['source.png', 'preview-source-1x.png', 'preview-redraw-draft-1x.png', 'preview-native-1x.png']:
        with Image.open(folder / name) as image:
            if 'A' not in image.getbands():
                raise ValueError('Expected an actual alpha channel: ' + name)
            values = list(image.getchannel('A').getdata())
            image_stats[name] = {'mode': image.mode, 'dimensions': list(image.size), **stats(values, image.width)}
            if name != 'source.png' and image.size != (width, height):
                raise ValueError('Reference/canonical canvas mismatch')
            planes[name] = values
    reference = planes['preview-redraw-draft-1x.png']
    png = planes['preview-native-1x.png']
    differences = [i for i, (a, b) in enumerate(zip(reference, png)) if a != b]
    checks = {
        'sourcePreviewAndDraftAlphaEqual': planes['preview-source-1x.png'] == reference,
        'sceneAlphaEqualsDraft': expected == reference,
        'literalAlphaEqualsDraft': lua_plane == reference,
        'literalAndSceneCoverageEqual': lua_coverage == coverage,
        'allAndOnlyNonzeroAlphaCellsIncluded': all(bool(c) == bool(a) for c, a in zip(coverage, reference)),
        'canonicalPNGAlphaEqualsDraft': png == reference,
        'canonicalPNGHasActualTransparency': 0 in png,
    }
    report = {
        'scope': 'V2 alpha byte and literal RGBA verification; no source or exporter modification',
        'inputs': inputs, 'checker': record(Path(__file__)), 'counts': {'literalImages': len(actual_rows), 'masks': 0},
        'method': 'Compare exact half-open authored rectangle cells and literal row alpha to existing draft alpha; separately inspect unmodified pinned canonical PNG bytes.',
        'images': image_stats, 'checks': checks,
        'pngAlphaDifference': {'pixels': len(differences), 'maxAbsolute': max([abs(a - b) for a, b in zip(reference, png)]),
                               'referenceZeroBecameNonzero': sum(a == 0 and b != 0 for a, b in zip(reference, png)),
                               'referencePartialBecameOpaque': sum(0 < a < 255 and b == 255 for a, b in zip(reference, png)),
                               'first10': [{'x': i % width, 'y': i // width, 'draft': reference[i], 'canonicalPNG': png[i]} for i in differences[:10]]},
        'result': 'pass' if all(checks.values()) else 'canonical_png_alpha_mismatch' if all(v for k, v in checks.items() if k != 'canonicalPNGAlphaEqualsDraft') else 'alpha_contract_failure',
        'sourceInspection': 'Pinned PNG renderer uses closed Pillow polygon edges and source-over for adjacent rectangles; no workaround or vendor change applied.',
        'nativeB0B1': 'not_run', 'visualOwnerApproval': 'pending', 'productionEnabled': False,
    }
    assert inputs == [record(folder / name) for name in names]
    assert loader.EXTERNAL_ATTEMPTS == []
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'result': report['result'], 'checks': checks, 'pngAlphaDifference': report['pngAlphaDifference']}))
    if not all(checks.values()):
        sys.exit(1)


if __name__ == '__main__':
    main()
