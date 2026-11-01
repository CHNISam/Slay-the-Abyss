"""Audit existing compact rectangles; not a fitter or a game-performance benchmark."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import platform
import time

from PIL import Image, ImageDraw, __version__ as pillow_version

ROOT = Path(__file__).resolve().parents[3]
RECIPE = ROOT / 'scripts/art/build-performance-pack.py'
spec = importlib.util.spec_from_file_location('existing_performance_pack', RECIPE)
recipe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recipe)
IDS = ('strike', 'defend', 'bash')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_source(path, expected_hash, canvas):
    raw = path.read_bytes()
    if raw.startswith(b'version https://git-lfs.github.com/spec/v1'):
        raise ValueError('LFS pointer is not image content')
    if digest(raw) != expected_hash:
        raise ValueError('Source SHA256 mismatch')
    with Image.open(path) as image:
        image.load()
        if image.size != tuple(canvas):
            raise ValueError('Source must already match the fixed display canvas')
        if image.convert('RGBA').getextrema()[3] != (255, 255):
            raise ValueError('This RGB card baseline requires an opaque source')
        return image.convert('RGB')


def reconstruct(encoded, count, canvas):
    if type(count) is not int or count < 1 or len(encoded) != count * 14:
        raise ValueError('Encoded rectangle count mismatch')
    if any(c not in '0123456789abcdef' for c in encoded):
        raise ValueError('Invalid rectangle hex encoding')
    width, height = canvas
    image = Image.new('RGB', canvas)
    coverage = bytearray(width * height)
    for offset in range(0, len(encoded), 14):
        x, y, w, h, r, g, b = [int(encoded[offset+i:offset+i+2], 16) for i in range(0, 14, 2)]
        if not w or not h or x+w > width or y+h > height:
            raise ValueError('Rectangle outside canvas or empty')
        for yy in range(y, y+h):
            for xx in range(x, x+w):
                index = yy * width + xx
                if coverage[index]:
                    raise ValueError('Rectangle overlap')
                coverage[index] = 1
                image.putpixel((xx, yy), (r, g, b))
    if not all(coverage):
        raise ValueError('Rectangle coverage gap')
    return image


def errors(source, rebuilt):
    if source.size != rebuilt.size or source.mode != 'RGB' or rebuilt.mode != 'RGB':
        raise ValueError('Metrics require identical RGB canvases')
    delta = [a-b for a, b in zip(source.tobytes(), rebuilt.tobytes())]
    mse = sum(d*d for d in delta) / len(delta)
    return {'rgb_mae': sum(abs(d) for d in delta) / len(delta), 'rgb_mse': mse,
            'rgb_psnr_db': 10 * math.log10(255**2/mse) if mse else None,
            'psnr_infinite': mse == 0}


def audit_asset(asset, root=ROOT):
    if asset['canvas'] != [144, 64] or asset['grid'] != [48, 22]:
        raise ValueError('Only the existing fixed 144x64 card baseline is supported')
    path = (root / asset['source']).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError('Source escapes repository')
    source = read_source(path, asset['sha256'], asset['canvas'])
    started = time.perf_counter()
    rows, encoded = recipe.rectangles(source, tuple(asset['grid']), tuple(asset['canvas']), False)
    elapsed = (time.perf_counter() - started) * 1000
    if len(rows) != asset['count'] or encoded != asset['rectangles']:
        raise ValueError('Existing compact baseline no longer reproduces')
    rebuilt = reconstruct(encoded, len(rows), tuple(asset['canvas']))
    result = {'source': asset['source'], 'source_sha256': asset['sha256'],
              'grid': asset['grid'], 'canvas': asset['canvas'], 'rectangle_controls': len(rows),
              'containers_included': False, 'encoding_bytes': len(encoded.encode('ascii')),
              'encoding_sha256': digest(encoded.encode('ascii')),
              'rebuilt_rgb_sha256': digest(rebuilt.tobytes()),
              'existing_encoding_matches': True, 'generation_ms_single_observation': elapsed,
              **errors(source, rebuilt)}
    return result, source, rebuilt


def main(output):
    pack_path = ROOT / 'art/performance/compact-v1.json'
    pack = json.loads(pack_path.read_text())
    if pack['profile'] != 'compact-v1' or pack['schemaVersion'] != 1:
        raise ValueError('Unsupported baseline manifest')
    results, reconstructions = {}, {}
    comparison = Image.new('RGB', (900, 260 * len(IDS)), '#19202b')
    draw = ImageDraw.Draw(comparison)
    for index, name in enumerate(IDS):
        result, source, rebuilt = audit_asset(pack['assets'][name])
        results[name] = result
        reconstructions[name] = rebuilt
        y = index * 260
        draw.text((12, y+8), f'{name}: source 144x64 | compact {result["rectangle_controls"]} rectangles', fill='white')
        for column, image in enumerate((source, rebuilt)):
            comparison.paste(image.resize((432, 192), Image.Resampling.NEAREST), (12+column*450, y+32))
        draw.text((12, y+232), f'MAE {result["rgb_mae"]:.3f}; PSNR {result["rgb_psnr_db"]:.3f} dB; enlarged nearest-neighbor 3x', fill='white')
    output.mkdir(parents=True, exist_ok=True)
    for name, rebuilt in reconstructions.items():
        rebuilt.save(output / f'{name}-compact.png')
    comparison.save(output / 'comparison.png')
    report = {'schemaVersion': 1, 'scope': 'Existing opaque card compact baseline only; no new algorithm or quality victory claim',
              'performance_boundary': 'Single offline Python generation observation, excludes decoding, validation and rendering; NOT FPS, official loading or device performance',
              'quality_boundary': 'RGB sRGB-code-value MAE/PSNR are descriptive, not perceptual or equal-quality acceptance',
              'recipe_sha256': digest(RECIPE.read_bytes()), 'pack_sha256': digest(pack_path.read_bytes()),
              'environment': {'python': platform.python_version(), 'pillow': pillow_version}, 'assets': results}
    (output / 'results.json').write_text(json.dumps(report, indent=2, allow_nan=False)+'\n')
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path(__file__).parent / 'results')
    main(parser.parse_args().output)
