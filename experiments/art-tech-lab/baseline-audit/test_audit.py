import copy
import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image
import audit


class BaselineAuditTests(unittest.TestCase):
    def test_real_baseline_determinism(self):
        pack = json.loads((audit.ROOT / 'art/performance/compact-v1.json').read_text())
        for name in audit.IDS:
            a, _, image_a = audit.audit_asset(pack['assets'][name])
            b, _, image_b = audit.audit_asset(pack['assets'][name])
            a.pop('generation_ms_single_observation')
            b.pop('generation_ms_single_observation')
            self.assertEqual(a, b)
            self.assertEqual(image_a.tobytes(), image_b.tobytes())

    def test_source_rejections(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'image.png'
            path.write_text('version https://git-lfs.github.com/spec/v1\noid sha256:abc\n')
            with self.assertRaisesRegex(ValueError, 'LFS pointer'):
                audit.read_source(path, audit.digest(path.read_bytes()), (144, 64))
            Image.new('RGB', (2, 2)).save(path)
            with self.assertRaisesRegex(ValueError, 'SHA256'):
                audit.read_source(path, 'wrong', (2, 2))
            with self.assertRaisesRegex(ValueError, 'canvas'):
                audit.read_source(path, audit.digest(path.read_bytes()), (144, 64))
            Image.new('RGBA', (2, 2), (0, 0, 0, 0)).save(path)
            with self.assertRaisesRegex(ValueError, 'opaque'):
                audit.read_source(path, audit.digest(path.read_bytes()), (2, 2))

    def test_encoding_rejections(self):
        for encoding, count, message in [('', 1, 'count'), ('z'*14, 1, 'hex'),
                ('00000302000000', 1, 'outside'), ('00000101000000', 1, 'gap'),
                ('00000202000000'*2, 2, 'overlap')]:
            with self.subTest(message=message), self.assertRaisesRegex(ValueError, message):
                audit.reconstruct(encoding, count, (2, 2))

    def test_manifest_mismatch(self):
        pack = json.loads((audit.ROOT / 'art/performance/compact-v1.json').read_text())
        asset = copy.deepcopy(pack['assets']['strike'])
        asset['rectangles'] = '0' + asset['rectangles'][1:]
        asset['count'] += 1
        with self.assertRaisesRegex(ValueError, 'no longer reproduces'):
            audit.audit_asset(asset)
        asset['canvas'] = [143, 64]
        with self.assertRaisesRegex(ValueError, 'fixed'):
            audit.audit_asset(asset)

    def test_metrics_known_values(self):
        black, white = Image.new('RGB', (2, 2)), Image.new('RGB', (2, 2), 'white')
        self.assertEqual(audit.errors(black, white)['rgb_mae'], 255)
        self.assertEqual(audit.errors(black, white)['rgb_psnr_db'], 0)
        self.assertTrue(audit.errors(black, black)['psnr_infinite'])
        self.assertIsNone(audit.errors(black, black)['rgb_psnr_db'])


if __name__ == '__main__':
    unittest.main()
