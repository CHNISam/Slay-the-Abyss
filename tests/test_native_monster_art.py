"""Bounds/provenance checks; use the existing analytical projection, not a renderer."""
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('native_adapter', ROOT / 'scripts/art/assemble-native-card-samples.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class NativeMonsterArtTest(unittest.TestCase):
    def test_exact_r02_source_identity_and_primitive_bounds(self):
        registry = json.loads((ROOT / 'data/presentation/native-monster-art.json').read_text())
        self.assertEqual(registry['canvas'], [106, 106])
        self.assertTrue(registry['enabled'])
        self.assertFalse(registry['approval']['nativeFinalApproved'])
        self.assertFalse(registry['approval']['deviceVerified'])
        self.assertEqual(registry['approval']['ownerEvidence']['at'], '2026-10-30T03:22:27Z')
        for record in registry['sourceInputs'][:2]:
            self.assertEqual(hashlib.sha256((ROOT / record['path']).read_bytes()).hexdigest(), record['sha256'])
        slots = registry['asset']['slots']
        self.assertEqual(sum(s['image'] == 100003 for s in slots), 534)
        self.assertEqual(sum(s['image'] == 100002 for s in slots), 63)
        for slot in slots:
            row = [slot['image'], *slot['position'], *slot['size'], *slot['pivot'],
                   *slot['anchorMin'], *slot['anchorMax'], *slot['scale'], slot['rotation'][2], *slot['colour']]
            self.assertEqual(adapter.outside_canvas(row, slot['rotation'][:2], canvas=(106, 106)), 0)


if __name__ == '__main__':
    unittest.main()
