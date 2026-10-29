"""One portrait: call the existing pinned editor, never fit/render/export ourselves.

The cache is read-only. This recipe verifies its exact loader/source manifest,
then reuses its network/process-denying load_upstream(). Outputs are offline
export evidence only, not a platform compilation, GIL or upload measurement.
"""
import argparse
import hashlib
import io
import importlib.metadata
import importlib.util
import json
import math
from pathlib import Path
import re
import struct
import sys

sys.dont_write_bytecode = True
EDITOR_COMMIT = '103025f9095d8089e3f9bf097f4d0c5fe039d546'
CACHE_PINS = {
    'export_candidate.py': '7744aca5c0b096d54d2927df6c2fbb9d86d4bc06d36cb80887c6574ac050879a',
    'upstream-source-manifest.json': '2cc653f17437dd28090d99b44bcfe7c700d330696082d709880a14991d0de795',
}
ASSETS = {'rectangle': 100001, 'ellipse': 100002, 'triangle': 100003}
SIZES = {'avatar96': 96, 'battle133': 133}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def record(path):
    data = path.read_bytes()
    return {'path': str(path.resolve()), 'bytes': len(data), 'sha256': sha256(data)}


def load_cache(cache):
    cache = cache.resolve()
    for name, digest in CACHE_PINS.items():
        if sha256((cache / name).read_bytes()) != digest:
            raise ValueError('Pinned cache mismatch: ' + name)
    manifest = json.loads((cache / 'upstream-source-manifest.json').read_text())
    if manifest['ref'] != EDITOR_COMMIT:
        raise ValueError('Wrong upstream editor commit')
    spec = importlib.util.spec_from_file_location('portrait_cached_export_recipe', cache / 'export_candidate.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    upstream, literal = module.load_upstream()
    return upstream, literal, module


def bounds(element):
    """Independent exact 2D primitive bounds; not an alternate image renderer."""
    x, y, w, h = element.x, element.y, element.width / 2, element.height / 2
    angle = math.radians(element.rotation)
    c, s = math.cos(angle), math.sin(angle)
    if element.type == 'ellipse':
        ex, ey = math.hypot(w * c, h * s), math.hypot(w * s, h * c)
        return [x - ex, y - ey, x + ex, y + ey]
    vertices = [(0, -h), (-w, h), (w, h)] if element.type == 'triangle' else [(-w, -h), (-w, h), (w, -h), (w, h)]
    points = [(x + c * px + s * py, y - s * px + c * py) for px, py in vertices]
    return [min(px for px, py in points), min(py for px, py in points),
            max(px for px, py in points), max(py for px, py in points)]


def validate_scene(scene, kind):
    size = SIZES[kind]
    if (scene.canvas.width, scene.canvas.height) != (size, size):
        raise ValueError('Expected exact square canvas: ' + str(size))
    if scene.canvas.mask.enabled:
        raise ValueError('Canvas mask is not proven Lua clipping; disable it explicitly')
    if not scene.elements or len({e.id for e in scene.elements}) != len(scene.elements):
        raise ValueError('Require nonempty drawing and unique element IDs')
    extents = []
    for e in scene.elements:
        if e.type not in ASSETS or e.rotationX or e.rotationY:
            raise ValueError('This portrait slice supports only 2D rectangle/ellipse/triangle: ' + e.id)
        if e.luaMask is not None:
            raise ValueError('This PNG/Lua benchmark requires no per-element mask data: ' + e.id)
        if not all(math.isfinite(v) for v in [e.x, e.y, e.width, e.height, e.rotation, e.opacity]):
            raise ValueError('Non-finite geometry: ' + e.id)
        if min(e.width, e.height) <= 0 or not 0 <= e.opacity <= 1 or not re.fullmatch(r'#[0-9a-fA-F]{6}', e.color):
            raise ValueError('Invalid dimensions/colour/opacity: ' + e.id)
        extent = bounds(e)
        if extent[0] < -1e-6 or extent[1] < -1e-6 or extent[2] > size + 1e-6 or extent[3] > size + 1e-6:
            raise ValueError('Unclipped geometry outside portrait: ' + e.id)
        extents.append(extent)
    return [min(b[0] for b in extents), min(b[1] for b in extents),
            max(b[2] for b in extents), max(b[3] for b in extents)]


def verify_literal(upstream, literal, scene, lua_bytes):
    source = lua_bytes.decode('utf-8')
    # Do not use the encoded editor snapshot to certify its own geometry.
    stripped = source.split('-- 编辑器回导数据')[0]
    drawing = literal.read_drawing(stripped)
    if drawing != literal.read_drawing(source):
        raise ValueError('Literal/snapshot-independent drawing mismatch')
    expected = sorted(scene.elements, key=lambda e: (not e.isBackground, e.zIndex))
    if drawing.get('format') != 'gia' or len(drawing['rows']) != len(expected):
        raise ValueError('Exporter dropped or added native image rows')
    if drawing.get('textboxes') or drawing.get('prefabBindings'):
        raise ValueError('Unexpected text/prefab ownership in portrait')
    root = [0, 0, scene.canvas.width, scene.canvas.height, .5, .5, .5, .5, .5, .5, 1, 1, 0]
    if drawing.get('root') != root:
        raise ValueError('Unexpected exported root transform')
    f32 = lambda v: struct.unpack('<f', struct.pack('<f', v))[0]
    for e, row in zip(expected, drawing['rows']):
        size = [round(e.width / 2, 4) * 2, round(e.height / 2, 4) * 2] if e.type == 'ellipse' else [round(e.width, 4), round(e.height, 4)]
        geometry = [round(e.x - scene.canvas.width / 2, 4), round(scene.canvas.height / 2 - e.y, 4), *size]
        rgba = [int(e.color[i:i + 2], 16) for i in (1, 3, 5)] + [round(e.opacity * 255)]
        if row != [ASSETS[e.type], *map(f32, geometry), .5, .5, .5, .5, .5, .5, 1, 1, f32(round(e.rotation, 4)), *rgba]:
            raise ValueError('Literal geometry/RGBA/order mismatch: ' + e.id)
    bindings = dict(re.findall(r'local (\w+_PREFAB_ID) = (\d+)', source))
    if bindings != {'IMAGE_PREFAB_ID': '0'}:
        raise ValueError('Expected one unbound image template; no guessed native index')
    return drawing


def literal_bounds(scene, drawing):
    ordered = sorted(scene.elements, key=lambda e: (not e.isBackground, e.zIndex))
    extents = [bounds(e.model_copy(update={'x': row[1] + scene.canvas.width / 2,
                                         'y': scene.canvas.height / 2 - row[2],
                                         'width': row[3], 'height': row[4], 'rotation': row[13]}))
               for e, row in zip(ordered, drawing['rows'])]
    return [min(b[0] for b in extents), min(b[1] for b in extents),
            max(b[2] for b in extents), max(b[3] for b in extents)]


def export_one(cache, scene_path, source_image, output, kind, crop=None, asset_directory=False):
    scene_path, source_image, output = scene_path.resolve(), source_image.resolve(), output.resolve()
    if output.exists() and not asset_directory:
        raise ValueError('Use a new output directory; never overwrite evidence')
    if not asset_directory and (scene_path.is_relative_to(output) or source_image.is_relative_to(output)):
        raise ValueError('Output must not contain or replace inputs')
    generated_names = ['native-art.json', 'native-art.lua', 'preview-native-1x.png', 'preview-native-4x.png',
                       'runtime-no-snapshot.lua', 'literal-drawing.json', 'export-report.json',
                       'LICENSE-editor-GPL-3.0.txt', 'LICENSE-runtime-MIT.txt', 'PROVENANCE-runtime.md']
    if any((output / name).exists() for name in generated_names):
        raise ValueError('Generated evidence already exists; never overwrite it')
    input_records = [record(scene_path), record(source_image)]
    upstream, literal, loader = load_cache(cache)
    from PIL import Image
    with Image.open(source_image) as image:
        source_dimensions = list(image.size)
        image.verify()
    if crop is not None and not (len(crop) == 4 and 0 <= crop[0] < crop[2] <= source_dimensions[0] and 0 <= crop[1] < crop[3] <= source_dimensions[1]):
        raise ValueError('Crop must be [left,top,right,bottom] inside the source image')
    scene = upstream.import_scene(upstream.ImportRequest(sourceType='json', content=scene_path.read_text(encoding='utf-8'), sourceName=kind)).scene
    extent = validate_scene(scene, kind)
    request = upstream.ExportRequest(scene=scene, giaGroupName='Lumine_' + kind + '_Offline_Benchmark')
    outputs = {}
    for extension, exporter in [('json', upstream.export_json), ('lua', upstream.export_lua), ('png', upstream.export_png)]:
        first, second = exporter(request).body, exporter(request).body
        if first != second:
            raise ValueError('Nondeterministic upstream export: ' + extension)
        outputs['preview-native-1x.png' if extension == 'png' else 'native-art.' + extension] = first
    drawing = verify_literal(upstream, literal, scene, outputs['native-art.lua'])
    actual_extent = literal_bounds(scene, drawing)
    if min(actual_extent[:2]) < -.00021 or max(actual_extent[2:]) > SIZES[kind] + .00021:
        raise ValueError('Quantized native drawing escapes the portrait canvas')
    if upstream.parse_json_scene(outputs['native-art.json'].decode()) != scene:
        raise ValueError('Canonical JSON did not round-trip')
    # Only the inert trailing editor comment is omitted. Keep canonical output.
    canonical_lua = outputs['native-art.lua'].decode('utf-8')
    marker = '-- 编辑器回导数据'
    if canonical_lua.count(marker) != 1:
        raise ValueError('Unexpected editor comment structure')
    runtime, comment = canonical_lua.split(marker, 1)
    if not all(line.startswith('--') for line in (marker + comment).splitlines() if line.strip()):
        raise ValueError('Refuse to remove a non-comment after editor marker')
    # Preserve canonical Lua; the derivative only omits editor comments and
    # extra trailing LF. Do not leave a blank EOF line or strip other content.
    if not runtime.endswith('\n'):
        raise ValueError('Unexpected runtime terminator; refuse to add non-prefix bytes')
    normalized_runtime = runtime.rstrip('\n') + '\n'
    if not canonical_lua.startswith(normalized_runtime):
        raise ValueError('Runtime body must remain an exact canonical prefix')
    comment_bytes_removed = len(canonical_lua.encode('utf-8')) - len(runtime.encode('utf-8'))
    trailing_lf_bytes_removed = len(runtime.encode('utf-8')) - len(normalized_runtime.encode('utf-8'))
    outputs['runtime-no-snapshot.lua'] = normalized_runtime.encode('utf-8')
    if verify_literal(upstream, literal, scene, outputs['runtime-no-snapshot.lua']) != drawing:
        raise ValueError('Removing editor comment changed literal drawing')
    with Image.open(io.BytesIO(outputs['preview-native-1x.png'])) as image:
        image.load()
        if image.size != (SIZES[kind], SIZES[kind]):
            raise ValueError('Upstream preview dimensions changed')
        enlarged = image.resize((image.width * 4, image.height * 4), Image.Resampling.NEAREST)
        buffer = io.BytesIO(); enlarged.save(buffer, format='PNG')
        outputs['preview-native-4x.png'] = buffer.getvalue()
    if input_records != [record(scene_path), record(source_image)]:
        raise ValueError('Input changed while exporting')
    if loader.EXTERNAL_ATTEMPTS:
        raise ValueError('Unexpected external activity: ' + str(loader.EXTERNAL_ATTEMPTS))
    output.mkdir(parents=True, exist_ok=asset_directory)
    for name, content in outputs.items():
        (output / name).write_bytes(content)
    license_paths = {
        'LICENSE-editor-GPL-3.0.txt': 'LICENSE',
        'LICENSE-runtime-MIT.txt': 'backend/vendor/primitive_shape/LICENSE',
        'PROVENANCE-runtime.md': 'backend/vendor/primitive_shape/PROVENANCE.md',
    }
    for name, original in license_paths.items():
        (output / name).write_bytes((cache / 'upstream' / original).read_bytes())
    (output / 'literal-drawing.json').write_text(json.dumps(drawing, ensure_ascii=False, indent=2) + '\n')
    report = {
        'schemaVersion': 1, 'kind': kind, 'editorCommit': EDITOR_COMMIT,
        'route': 'verified cached upstream import_scene(JSON) -> export_json/export_lua/export_png -> literal read_drawing',
        'cacheRoot': str(cache.resolve()), 'cachePins': CACHE_PINS, 'upstreamFiles': loader.verify_sources(),
        'inputs': input_records, 'sourceDimensions': source_dimensions, 'sourceCropLTRB': crop,
        'sourcePixelToGeometryEquivalence': 'not asserted; visual benchmark requires review',
        'canvas': [scene.canvas.width, scene.canvas.height], 'sourceSceneBoundsLTRB': extent,
        'drawingBoundsLTRB': actual_extent,
        'localCanvasBounds': [-SIZES[kind] / 2, -SIZES[kind] / 2, SIZES[kind] / 2, SIZES[kind] / 2],
        'counts': {'contentImages': len(drawing['rows']), 'contentTexts': 0, 'extraMasks': 0,
                   'dynamicContentInstances': len(drawing['rows']), 'requiredDedicatedHostInstances': 1,
                   'requiredImageTemplateDefinitions': 1, 'templateIndex': 'unbound'},
        'outputs': [record(output / name) for name in [*outputs, 'literal-drawing.json']],
        'licenseFiles': [record(output / name) for name in license_paths],
        'checks': {'deterministicTwice': True, 'canonicalJsonRoundtrip': True, 'literalGeometryRGBAOrder': True,
                   'metadataIndependent': True, 'sourceBounds': True, 'externalAttempts': loader.EXTERNAL_ATTEMPTS,
                   'runtimeNoSnapshotDrawingEquivalent': True, 'runtimeNoSnapshotExactCodeDataPrefix': True},
        'editorSnapshotBytes': {'canonicalLua': len(outputs['native-art.lua']),
                                'runtimeNoSnapshotLua': len(outputs['runtime-no-snapshot.lua']),
                                'commentBytesRemoved': comment_bytes_removed,
                                'trailingBlankLFBytesRemoved': trailing_lf_bytes_removed,
                                'totalRawBytesRemoved': len(outputs['native-art.lua']) - len(outputs['runtime-no-snapshot.lua']),
                                'scope': 'raw Lua comment bytes only; not measured GIL/upload savings'},
        'preview4x': 'nearest-neighbour enlargement of canonical 1x PNG, not native/device rendering',
        'python': sys.version.split()[0],
        'dependencies': {name: importlib.metadata.version(name) for name in ('fastapi', 'starlette', 'pydantic', 'pillow')},
        'visualAcceptance': 'not_approved', 'lifecycleVM': 'run separate check_lifecycle.cjs; see its receipt',
        'nativeB0B1': 'not_run', 'officialCompile': 'not_run', 'officialImport': 'not_run',
        'nativeRuntime': 'not_run', 'uploadIncrementBytes': None, 'platformArchiveSize': None,
        'performance': 'not_measured',
        'limits': ['PNG/Lua/source bytes are not upload/GIL bytes or a 20MB safety guarantee.',
                   '96 has no wired UI slot; existing 133.333 battle plate has only 117.333 drawable area.',
                   'No UI integration, new native exporter, random fitting, native input or publishing.'],
        'licenses': {'editor': 'GPL-3.0; upstream/LICENSE',
                     'emittedPrimitiveRuntime': 'MIT; upstream/backend/vendor/primitive_shape/LICENSE',
                     'projectLicenseReferences': ['art/processed/ai-samples/licenses/', 'art/spikes/card-editor/licenses/']},
    }
    (output / 'export-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache-root', type=Path, required=True)
    parser.add_argument('--scene', type=Path, required=True)
    parser.add_argument('--source-image', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--kind', choices=SIZES, required=True)
    parser.add_argument('--crop', type=float, nargs=4)
    parser.add_argument('--into-existing-asset-directory', action='store_true',
                        help='Allow the existing asset directory, but never overwrite any generated evidence')
    args = parser.parse_args()
    report = export_one(args.cache_root, args.scene, args.source_image, args.output, args.kind, args.crop,
                        args.into_existing_asset_directory)
    print(json.dumps({'counts': report['counts'], 'output': str(args.output), 'nativeB0B1': 'not_run'}))


if __name__ == '__main__':
    main()
