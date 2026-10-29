"""Small offline adapter checks; synthetic geometry is never a final portrait."""
import json
import os
from pathlib import Path
import tempfile
import unittest

import export_portrait as adapter
from verify_alpha import rectangle_plane, stats

CACHE = Path(os.environ.get('PORTRAIT_EDITOR_CACHE', '/workspace/scratch/c1a4970a76e0/starfall-offline-export'))
REPOSITORY = Path(__file__).resolve().parents[5]
SOURCE = REPOSITORY / 'art/source/lumine_geo_portrait.png'


def fixture(size=96):
    return {'canvas': {'width': size, 'height': size, 'background': 'transparent', 'mask': {'enabled': False}},
            'elements': [
                {'id': 'test-base', 'type': 'rectangle', 'x': size / 2, 'y': size / 2,
                 'width': size, 'height': size, 'color': '#0F1117', 'zIndex': 0},
                {'id': 'test-ellipse', 'type': 'ellipse', 'x': size / 2, 'y': size / 2,
                 'width': 12, 'height': 18, 'rotation': 15, 'color': '#F0B850', 'opacity': .55, 'zIndex': 1},
                {'id': 'test-triangle', 'type': 'triangle', 'x': size / 2, 'y': size / 2,
                 'width': 12, 'height': 18, 'rotation': -15, 'color': '#FFFFFF', 'zIndex': 2},
            ]}


class AdapterChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.upstream, cls.literal, cls.loader = adapter.load_cache(CACHE)

    def scene(self, raw):
        return self.upstream.import_scene(self.upstream.ImportRequest(sourceType='json', content=json.dumps(raw))).scene

    def test_real_upstream_json_lua_png_and_separate_counts(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / 'editable.scene.json'
            source.write_text(json.dumps(fixture()))
            report = adapter.export_one(CACHE, source, SOURCE, root / 'export', 'avatar96')
            self.assertEqual(report['counts']['contentImages'], 3)
            self.assertEqual(report['counts']['requiredDedicatedHostInstances'], 1)
            self.assertEqual(report['counts']['requiredImageTemplateDefinitions'], 1)
            self.assertEqual(report['counts']['extraMasks'], 0)
            self.assertEqual(report['drawingBoundsLTRB'], [0, 0, 96, 96])
            self.assertEqual(report['sourceSceneBoundsLTRB'], report['drawingBoundsLTRB'])
            self.assertEqual(report['nativeB0B1'], 'not_run')
            self.assertIsNone(report['uploadIncrementBytes'])
            self.assertEqual((root / 'export/preview-native-1x.png').read_bytes()[:8], b'\x89PNG\r\n\x1a\n')
            self.assertTrue(report['checks']['runtimeNoSnapshotDrawingEquivalent'])
            self.assertGreater(report['editorSnapshotBytes']['commentBytesRemoved'], 0)
            runtime = (root / 'export/runtime-no-snapshot.lua').read_bytes()
            canonical = (root / 'export/native-art.lua').read_bytes()
            self.assertTrue(runtime.endswith(b'\n') and not runtime.endswith(b'\n\n'))
            self.assertTrue(canonical.startswith(runtime))
            sizes = report['editorSnapshotBytes']
            self.assertEqual(sizes['totalRawBytesRemoved'], sizes['commentBytesRemoved'] + sizes['trailingBlankLFBytesRemoved'])
            self.assertTrue(all(record['bytes'] > 0 for record in report['outputs']))
            self.assertEqual(report['checks']['externalAttempts'], [])
            with self.assertRaisesRegex(ValueError, 'new output directory'):
                adapter.export_one(CACHE, source, SOURCE, root / 'export', 'avatar96')

    def test_existing_asset_directory_preserves_inputs_and_refuses_output_replacement(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / 'editable.scene.json'
            original = json.dumps(fixture()); source.write_text(original)
            report = adapter.export_one(CACHE, source, SOURCE, root, 'avatar96', asset_directory=True)
            self.assertEqual(source.read_text(), original)
            self.assertEqual(report['counts']['contentImages'], 3)
            with self.assertRaisesRegex(ValueError, 'never overwrite'):
                adapter.export_one(CACHE, source, SOURCE, root, 'avatar96', asset_directory=True)

    def test_battle_canvas_and_true_bounds(self):
        scene = self.scene(fixture(133))
        self.assertEqual(adapter.validate_scene(scene, 'battle133'), [0, 0, 133, 133])
        with self.assertRaisesRegex(ValueError, 'exact square canvas'):
            adapter.validate_scene(scene, 'avatar96')

    def test_unclipped_overflow_is_rejected(self):
        raw = fixture(); raw['elements'][1]['x'] = 0
        with self.assertRaisesRegex(ValueError, 'outside portrait'):
            adapter.validate_scene(self.scene(raw), 'avatar96')

    def test_mask_data_never_silently_removed(self):
        raw = fixture(); raw['elements'][0]['luaMask'] = {'enabled': True, 'width': 96, 'height': 96}
        with self.assertRaisesRegex(ValueError, 'no per-element mask'):
            adapter.validate_scene(self.scene(raw), 'avatar96')

    def test_canvas_mask_does_not_certify_lua_clipping(self):
        raw = fixture(); raw['canvas']['mask']['enabled'] = True
        with self.assertRaisesRegex(ValueError, 'not proven Lua clipping'):
            adapter.validate_scene(self.scene(raw), 'avatar96')

    def test_duplicate_identity_and_unsupported_ownership(self):
        raw = fixture(); raw['elements'][1]['id'] = raw['elements'][0]['id']
        with self.assertRaisesRegex(ValueError, 'unique element IDs'):
            adapter.validate_scene(self.scene(raw), 'avatar96')
        raw = fixture(); raw['elements'][1]['type'] = 'four_point_star'
        with self.assertRaisesRegex(ValueError, 'only 2D'):
            adapter.validate_scene(self.scene(raw), 'avatar96')

    def test_literal_mutation_cannot_hide_behind_snapshot(self):
        scene = self.scene(fixture())
        data = self.upstream.export_lua(self.upstream.ExportRequest(scene=scene, giaGroupName='Portrait_Adapter_Test')).body
        source = data.decode()
        changed = source.replace('    {100001,0.0,0.0,', '    {100001,1.0,0.0,', 1)
        self.assertNotEqual(changed, source)
        with self.assertRaisesRegex(ValueError, 'geometry/RGBA/order mismatch'):
            adapter.verify_literal(self.upstream, self.literal, scene, changed.encode())

    def test_cache_mismatch_rejected_before_import(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'export_candidate.py').write_text('raise AssertionError("must never execute")')
            with self.assertRaisesRegex(ValueError, 'Pinned cache mismatch'):
                adapter.load_cache(root)

    def test_exact_alpha_occupancy_preserves_one_partial_and_opaque(self):
        plane, coverage = rectangle_plane([(1, .5, 2, 1, 1), (2.5, .5, 1, 1, 128),
                                           (3.5, .5, 1, 1, 255)], 5, 1)
        self.assertEqual(plane, [1, 1, 128, 255, 0])
        self.assertEqual(coverage, [1, 1, 1, 1, 0])
        self.assertEqual(stats(plane, 5)['partial'], 3)
        with self.assertRaisesRegex(ValueError, 'overlap'):
            rectangle_plane([(1, .5, 2, 1, 1), (1, .5, 2, 1, 128)], 5, 1)
        with self.assertRaisesRegex(ValueError, 'positive-alpha'):
            rectangle_plane([(1, .5, 2, 1, 0)], 5, 1)


if __name__ == '__main__':
    unittest.main(verbosity=2)
