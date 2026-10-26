"""Offline scene input checks. Never imports assets or certifies platform acceptance."""
import argparse
import json
import math
from pathlib import Path

FLOOR_IDS = {20003078, 20002899}
PACKS = (('geo-ruins.scene.json', 'build-result.json', True),
         ('ruin-gateway.asset.json', 'building-build-result.json', False))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def number(value):
    return type(value) in (int, float) and math.isfinite(value)


def vector(value, label, positive=False):
    require(isinstance(value, list) and len(value) == 3 and
            all(number(v) and (not positive or v > 0) for v in value),
            label + ': expected three finite' + (' positive' if positive else '') + ' numbers')
    return value


def yaw_bounds(block, size):
    """Catalogue-centred, yaw-only bounds; not mesh/pivot/collision truth."""
    width, _, depth = [v * block['scale'] for v in size]
    yaw = math.radians(block.get('rotation', [0, 0, 0])[1])
    half_x = (abs(math.cos(yaw)) * width + abs(math.sin(yaw)) * depth) / 2
    half_z = (abs(math.sin(yaw)) * width + abs(math.cos(yaw)) * depth) / 2
    x, _, z = block['position']
    bounds = [x - half_x, z - half_z, x + half_x, z + half_z]
    require(all(number(v) for v in bounds), 'calculated bounds must be finite')
    return bounds


def intersects_centre(bounds):
    # Boundary contact is conservatively treated as overlap.
    left, near, right, far = bounds
    return left <= 4 and right >= -4 and near <= 1 and far >= -1


def verify_documents(documents):
    """Accept a filename-to-decoded-JSON mapping, return offline-only report."""
    selection = documents['asset-selection.json']['assets']
    require(isinstance(selection, list) and selection, 'selection: missing assets')
    catalog = {}
    for asset in selection:
        ident = asset['id']
        require(type(ident) is int and ident > 0 and ident not in catalog,
                'selection: invalid or duplicate model ID')
        vector(asset['sizeMetres'], 'catalog size', positive=True)
        vector(asset['scaledSizeMetres'], 'recorded scaled size', positive=True)
        require(number(asset['scale']) and asset['scale'] > 0, 'selection: invalid scale')
        require(asset.get('solid') is False, 'selection: solid must be false')
        require(all(abs(raw * asset['scale'] - scaled) <= 0.000051
                    for raw, scaled in zip(asset['sizeMetres'], asset['scaledSizeMetres'])),
                'selection: scaled dimensions disagree')
        catalog[ident] = asset
    evidence = documents['verification.json']['packs']
    require(isinstance(evidence, list) and len(evidence) == len(PACKS),
            'verification: expected exactly two packs')
    evidence_by_input = {p['input']: p for p in evidence}
    require(set(evidence_by_input) == {p[0] for p in PACKS},
            'verification: missing or duplicate pack input')
    all_names, id_ranges, reports = set(), [], []
    for filename, result_file, is_scene in PACKS:
        pack = documents[filename]
        blocks = pack['blocks']
        require(isinstance(blocks, list) and 1 <= len(blocks) <= 8,
                filename + ': expected 1..8 instances')
        require(pack.get('install') is False, filename + ': install must be false')
        start = pack['entityIdStart']
        require(type(start) is int and 0 <= start <= 2**32 - len(blocks),
                filename + ': invalid uint32 entity ID range')
        end = start + len(blocks) - 1
        require(all(end < a or start > b for a, b in id_ranges), 'overlapping entity ID ranges')
        id_ranges.append((start, end))
        model_ids, bounds_by_name = [], {}
        for block in blocks:
            name = block['name']
            require(isinstance(name, str) and name.strip() and name not in all_names,
                    filename + ': empty or duplicate block name')
            all_names.add(name)
            ident = block['template']
            require(type(ident) is int and ident in catalog, name + ': unknown model ID')
            model_ids.append(ident)
            require(block.get('solid') is False, name + ': solid must be false')
            vector(block['position'], name + ' position')
            rotation = vector(block.get('rotation', [0, 0, 0]), name + ' rotation')
            require(rotation[0] == 0 and rotation[2] == 0,
                    name + ': pitch/roll require full 3D bounds; yaw-only check cannot certify')
            require(number(block['scale']) and block['scale'] > 0, name + ': invalid scale')
            if is_scene:
                require(block['scale'] == catalog[ident]['scale'], name + ': selection scale differs')
            bounds = yaw_bounds(block, catalog[ident]['sizeMetres'])
            bounds_by_name[name] = bounds
            if is_scene and ident not in FLOOR_IDS:
                require(not intersects_centre(bounds), name + ': non-floor bounds intersect central rectangle')
        require(len(set(model_ids)) == len(model_ids), filename + ': repeated model within pack')
        if is_scene:
            require(set(model_ids) == set(catalog), 'scene and selection model IDs disagree')
        recorded = evidence_by_input[filename]
        require(recorded.get('install') is False and recorded['name'] == pack['name'] and
                type(recorded['count']) is int and recorded['count'] == len(blocks) and
                isinstance(recorded['templateIds'], list) and
                all(type(v) is int for v in recorded['templateIds']) and
                recorded['templateIds'] == model_ids and
                type(recorded['nativeCollisionDisabled']) is int and
                recorded['nativeCollisionDisabled'] == len(blocks),
                filename + ': verification record differs from input')
        build = documents[result_file]
        result = build['result']
        require(build.get('isError') is False and result['installedTo'] is None and
                result['name'] == pack['name'] and type(result['count']) is int and
                result['count'] == len(blocks) and isinstance(result['entityIds'], list) and
                all(type(v) is int for v in result['entityIds']) and
                result['entityIds'] == [start, end], filename + ': build record differs from input')
        values = list(bounds_by_name.values())
        combined = [min(b[0] for b in values), min(b[1] for b in values),
                    max(b[2] for b in values), max(b[3] for b in values)]
        reports.append({'input': filename, 'count': len(blocks), 'offlineEntityIdRange': [start, end],
                        'approximateXZBounds': combined, 'boundsByName': bounds_by_name})
    return {'status': 'offline-input-checks-passed', 'platformAcceptance': 'unverified',
            'limitations': 'Catalogue-centred yaw bounds only. No GIA hash verification, import, '
                           'actual GUID readback, mesh/collision/foot-height, visibility or performance test.',
            'packs': reports}


def load_documents(directory):
    names = ['asset-selection.json', 'verification.json']
    names += [name for pack in PACKS for name in pack[:2]]
    return {name: json.loads((directory / name).read_text(encoding='utf-8')) for name in names}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path,
                        default=Path(__file__).resolve().parents[2] / 'docs/art/scene-spike')
    args = parser.parse_args()
    try:
        report = verify_documents(load_documents(args.directory))
    except (ValueError, KeyError, TypeError, OverflowError, OSError) as exc:
        parser.exit(1, f'scene input validation failed: {exc}\n')
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()
