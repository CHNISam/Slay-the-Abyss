"""Bind four literal review exports to one bounded, preallocated native pool.

The upstream exporter remains authoritative. This adapter neither fits images
nor renders shapes: it proves a shared rectangular clip (within measured float32
roundoff), then records the existing properties for the native control API.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
EDITOR_COMMIT = '103025f9095d8089e3f9bf097f4d0c5fe039d546'
IDS = ('heavy_blade', 'bloodletting', 'iron_wave', 'shockwave')
CLIP_TOLERANCE = 0.0001


def outside_canvas(row, angles):
    """Exact projected polygon vertices / analytic ellipse extrema, Y up."""
    image, x, y, w, h = row[:5]
    rx, ry, rz = map(math.radians, [*angles, row[13]])
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    a, b, c, d = cy * cz + sy * sx * sz, cx * sz, -cy * sz + sy * sx * cz, cx * cz
    if image == 100002:
        ex, ey = math.hypot(a * w / 2, c * h / 2), math.hypot(b * w / 2, d * h / 2)
        points = [(x - ex, y - ey), (x + ex, y + ey)]
    else:
        if image == 100001:
            local = [(u * w / 2, v * h / 2) for u in (-1, 1) for v in (-1, 1)]
        elif image == 100003:
            local = [(0, h / 2), (-w / 2, -h / 2), (w / 2, -h / 2)]
        elif image == 100004:
            local = [(0, h / 2), (.12 * w, .12 * h), (w / 2, 0), (.12 * w, -.12 * h),
                     (0, -h / 2), (-.12 * w, -.12 * h), (-w / 2, 0), (-.12 * w, .12 * h)]
        else:
            raise AssertionError('Unsupported native primitive')
        points = [(x + a * u + c * v, y + b * u + d * v) for u, v in local]
    return max(max(abs(px) - 72, abs(py) - 17, 0) for px, py in points)


def slot_path(index):
    return ['clip', f'group{index // 60:03d}', f'shape{index:03d}']


def assemble(drawing, name):
    root = drawing['root']
    assert drawing['format'] == 'gia' and root == [0, 0, 144, 34, .5, .5, .5, .5, .5, .5, 1, 1, 0]
    rows, masks, xy = drawing['rows'], drawing['imageMasks'], drawing['rotations']
    assert len(rows) == len(masks) == len(xy) and rows
    assert not drawing.get('textboxes') and not drawing.get('bindings') and not drawing.get('textMasks')
    slots, mask_error, outside_error = [], 0, 0
    for index, (row, mask, angles) in enumerate(zip(rows, masks, xy)):
        assert row[0] in (100001, 100002, 100003, 100004)
        assert row[5:11] == [.5] * 6 and row[11:13] == [1, 1]
        assert not mask['enableSoftEdge'] and not mask['reverseMaskArea']
        if mask['enabled']:
            assert mask['imageId'] == 100001 and [mask['width'], mask['height']] == root[2:4]
            assert mask['softEdgeWidthX'] == mask['softEdgeWidthY'] == 0
            error = max(abs(row[1] + mask['offsetX']), abs(row[2] - mask['offsetY']))
            assert error <= CLIP_TOLERANCE, f'{name}: non-equivalent source clip {index}: {error}'
            mask_error = max(mask_error, error)
        else:
            error = outside_canvas(row, angles)
            assert error <= CLIP_TOLERANCE, f'{name}: unmasked shape outside shared clip {index}: {error}'
            outside_error = max(outside_error, error)
        slots.append(dict(path=slot_path(index), image=row[0], position=row[1:3], size=row[3:5],
                          scale=row[11:13], rotation=[*angles, row[13]], colour=row[14:18]))
    return dict(slots=slots, sourceCounts=dict(images=len(rows), masks=sum(bool(mask['enabled']) for mask in masks)),
                clipProof=dict(tolerance=CLIP_TOLERANCE, maxMaskCenterError=mask_error, maxUnmaskedOutside=outside_error,
                               reason='Source float32 export roundoff; not mathematical or pixel identity.'))


def pool_tree(capacity):
    groups = []
    for index in range(capacity):
        path = slot_path(index)
        if index % 60 == 0:
            groups.append(dict(name=path[1], kind='container', position=[0, 0], size=[144, 34], children=[]))
        groups[-1]['children'].append(dict(name=path[2], kind='image', image=100001, position=[0, 0],
                                          size=[1, 1], scale=[1, 1], rotation=0, colour='#FFFFFF', opacity=0, visible=False))
    clip = dict(name='clip', kind='image', image=100001, position=[0, 0], size=[144, 34],
                scale=[1, 1], rotation=0, colour='#FFFFFF', opacity=0, mask=True)
    return dict(name='artSamples', kind='container', position=[0, 0], size=[144, 34], visible=False, children=[clip, *groups])


def reject_output_alias(output, inputs):
    target = output.resolve()
    if not target.is_relative_to(ROOT.resolve()):
        raise ValueError('Output must stay within the candidate repository')
    for source in inputs:
        if target == source.resolve() or (output.exists() and source.exists() and output.samefile(source)):
            raise ValueError(f'Output must not overwrite an input file: {source}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--editor', type=Path, required=True)
    args = parser.parse_args()
    output = ROOT / 'art/cards/geo-samples/native-layout.json'
    sources = [ROOT / 'art/cards/geo-samples' / name / f'native-art.{extension}'
               for name in IDS for extension in ('lua', 'json')]
    reject_output_alias(output, [*sources, Path(__file__)])
    actual = subprocess.check_output(['git', '-C', str(args.editor), 'rev-parse', 'HEAD'], text=True).strip()
    assert actual == EDITOR_COMMIT, 'pinned upstream editor revision mismatch'
    sys.path.insert(0, str(args.editor / 'backend'))
    from app import lua_scene
    samples = {}
    for name in IDS:
        path = ROOT / 'art/cards/geo-samples' / name / 'native-art.lua'
        # Match the legal inventory and source guards across checkout line endings.
        # Normalize only CRLF; do not rewrite the frozen source file.
        source = path.read_bytes().decode('utf-8').replace('\r\n', '\n')
        samples[name] = assemble(lua_scene.read_drawing(source), name)
        samples[name]['source'] = dict(path=path.relative_to(ROOT).as_posix(), sha256=hashlib.sha256(source.encode('utf-8')).hexdigest())
    capacity = max(sample['sourceCounts']['images'] for sample in samples.values())
    for sample in samples.values():
        sample['slots'].extend(dict(path=slot_path(index), visible=False) for index in range(len(sample['slots']), capacity))
    result = dict(schemaVersion=1, editorCommit=actual, capacity=capacity, pool=pool_tree(capacity), samples=samples)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(dict(output=output.relative_to(ROOT).as_posix(), capacity=capacity,
                         sourceCounts={name: sample['sourceCounts'] for name, sample in samples.items()},
                         clipProof={name: sample['clipProof'] for name, sample in samples.items()},
                         controlsPerPool=capacity + math.ceil(capacity / 60) + 2,
                         officialImport='not_run', inGame='not_run'), ensure_ascii=False))


if __name__ == '__main__':
    main()
