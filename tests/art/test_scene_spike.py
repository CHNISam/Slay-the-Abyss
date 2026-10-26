"""Focused offline regression tests; never launches SDK, client or downloaded scripts."""
import copy
import importlib.util
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/art/verify-scene-spike.py'
spec = importlib.util.spec_from_file_location('scene_validator', SCRIPT)
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class SceneTests(unittest.TestCase):
    def setUp(self):
        self.docs = validator.load_documents(ROOT / 'docs/art/scene-spike')
        self.scene = self.docs['geo-ruins.scene.json']
        self.probe = self.docs['ruin-gateway.asset.json']

    def invalid(self, phrase):
        with self.assertRaisesRegex(ValueError, phrase):
            validator.verify_documents(self.docs)

    def test_current_inputs_and_rotation_bounds(self):
        report = validator.verify_documents(self.docs)
        self.assertEqual(report['platformAcceptance'], 'unverified')
        scene, probe = report['packs']
        self.assertEqual((scene['count'], probe['count']), (7, 1))
        for actual, expected in zip(scene['approximateXZBounds'],
                                    [-8.388328, -5.65915, 8.542007, 7.335044]):
            self.assertAlmostEqual(actual, expected, places=5)
        self.assertAlmostEqual(scene['boundsByName']['ARTS_GrayRock'][1], 3.019109, places=5)
        # Probe occupies centre intentionally; it is a separate clean copy.
        self.assertTrue(validator.intersects_centre(probe['approximateXZBounds']))

    def test_ninth_instance(self):
        self.scene['blocks'] *= 2
        self.invalid('1..8')

    def test_empty_pack(self):
        self.scene['blocks'] = []
        self.invalid('1..8')

    def test_install_true_or_missing(self):
        for value in (True, None, 0):
            with self.subTest(value=value):
                self.scene['install'] = value
                self.invalid('install must be false')

    def test_solid_true_or_missing(self):
        for value in (True, None, 0):
            with self.subTest(value=value):
                self.scene['blocks'][0]['solid'] = value
                self.invalid('solid must be false')

    def test_duplicate_name_across_packs(self):
        self.probe['blocks'][0]['name'] = self.scene['blocks'][0]['name']
        self.invalid('duplicate block name')

    def test_invalid_model(self):
        self.scene['blocks'][0]['template'] = 123
        self.invalid('unknown model')

    def test_invalid_scale(self):
        for value in (0, -1, math.inf, math.nan, True):
            with self.subTest(value=value):
                self.scene['blocks'][0]['scale'] = value
                self.invalid('invalid scale')

    def test_invalid_transforms(self):
        for field in ('position', 'rotation'):
            for value in ([0, 0], [0, math.inf, 0], [True, 0, 0], ['0', 0, 0]):
                with self.subTest(field=field, value=value):
                    block = self.scene['blocks'][0]
                    original = copy.deepcopy(block.get(field))
                    block[field] = value
                    self.invalid('expected three finite')
                    if original is None:
                        del block[field]
                    else:
                        block[field] = original

    def test_pitch_or_roll_not_silently_ignored(self):
        self.scene['blocks'][0]['rotation'] = [1, 0, 0]
        self.invalid('pitch/roll')

    def test_duplicate_catalog_id(self):
        assets = self.docs['asset-selection.json']['assets']
        assets.append(copy.deepcopy(assets[0]))
        self.invalid('duplicate model ID')

    def test_scaled_size_mismatch(self):
        self.docs['asset-selection.json']['assets'][0]['scaledSizeMetres'][0] += .001
        self.invalid('scaled dimensions disagree')

    def test_selection_scale_mismatch(self):
        self.scene['blocks'][0]['scale'] += .01
        self.invalid('selection scale differs')

    def test_verification_model_mismatch(self):
        self.docs['verification.json']['packs'][0]['templateIds'][0] = 123
        self.invalid('verification record differs')

    def test_verification_duplicate_pack(self):
        packs = self.docs['verification.json']['packs']
        packs[1] = copy.deepcopy(packs[0])
        self.invalid('duplicate pack input')

    def test_entity_range_overlap(self):
        self.probe['entityIdStart'] = self.scene['entityIdStart'] + 6
        self.invalid('overlapping entity ID')

    def test_entity_range_invalid(self):
        for value in (-1, 2**32, True, 1.1):
            with self.subTest(value=value):
                self.scene['entityIdStart'] = value
                self.invalid('invalid uint32')

    def test_build_range_is_endpoint_pair(self):
        self.docs['building-build-result.json']['result']['entityIds'] = [1078011000, 1078011001]
        self.invalid('build record differs')

    def test_recorded_numeric_types_are_strict(self):
        for field in ('count', 'nativeCollisionDisabled'):
            with self.subTest(field=field):
                record = self.docs['verification.json']['packs'][1]
                record[field] = True
                self.invalid('verification record differs')
                record[field] = 1
        result = self.docs['building-build-result.json']['result']
        result['count'] = True
        self.invalid('build record differs')
        result['count'] = 1
        result['entityIds'] = [1078011000.0, 1078011000.0]
        self.invalid('build record differs')

    def test_recorded_model_ids_reject_floats(self):
        self.docs['verification.json']['packs'][1]['templateIds'] = [20002586.0]
        self.invalid('verification record differs')

    def test_central_nonfloor_overlap(self):
        self.scene['blocks'][2]['position'] = [0, 0, 0]
        self.invalid('central rectangle')

    def test_floor_can_overlap_centre(self):
        self.assertTrue(validator.intersects_centre(
            validator.yaw_bounds(self.scene['blocks'][0], [16.169, .406, 16.169])))
        validator.verify_documents(self.docs)

    def test_ninety_degree_and_negative_yaw(self):
        block = {'position': [1, 0, 2], 'scale': 1, 'rotation': [0, 90, 0]}
        self.assertEqual([round(v, 10) for v in validator.yaw_bounds(block, [4, 1, 2])],
                         [0, 0, 2, 4])
        block['rotation'][1] = -90
        self.assertEqual([round(v, 10) for v in validator.yaw_bounds(block, [4, 1, 2])],
                         [0, 0, 2, 4])

    def test_cli_success_and_missing_file_failure(self):
        passed = subprocess.run([sys.executable, str(SCRIPT)], capture_output=True, text=True)
        self.assertEqual(passed.returncode, 0, passed.stderr)
        self.assertIn('"platformAcceptance": "unverified"', passed.stdout)
        with tempfile.TemporaryDirectory() as directory:
            failed = subprocess.run([sys.executable, str(SCRIPT), '--directory', directory],
                                    capture_output=True, text=True)
        self.assertEqual(failed.returncode, 1)
        self.assertIn('validation failed', failed.stderr)


if __name__ == '__main__':
    unittest.main()
