"""The restricted shared-clip adapter rejects geometry it cannot preserve."""
import copy
import importlib.util
import contextlib
import io
import json
import sys
import types
from pathlib import Path
import unittest
import tempfile
import os
from unittest.mock import Mock, call, patch

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/art/assemble-native-card-samples.py'
spec = importlib.util.spec_from_file_location('native_card_samples', SCRIPT)
assembly = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assembly)


def drawing():
    return dict(format='gia', root=[0, 0, 144, 34, .5, .5, .5, .5, .5, .5, 1, 1, 0],
                rows=[[100001, 0, 0, 144, 34, .5, .5, .5, .5, .5, .5, 1, 1, 0, 12, 34, 56, 78]],
                rotations=[[0, 0]], imageMasks=[dict(enabled=False, imageId=100001,
                    offsetX=0, offsetY=0, width=144, height=34, reverseMaskArea=False,
                    enableSoftEdge=False, softEdgeWidthX=0, softEdgeWidthY=0)])


class NativeCardSamplesTest(unittest.TestCase):
    def test_default_samples_are_the_four_explicit_review_card_ids(self):
        self.assertEqual(assembly.IDS, ('heavy_blade', 'bloodletting', 'iron_wave', 'shockwave'))

    def test_literal_fields_and_xyz_are_retained_without_rounding(self):
        source = drawing()
        source['rows'][0][2] = .000001
        source['imageMasks'][0]['enabled'] = True
        source['rotations'][0] = [23.123456789, -45.987654321]
        original = copy.deepcopy(source)
        result = assembly.assemble(source, 'example')
        self.assertEqual(source, original)
        self.assertEqual(result['slots'][0]['position'], [0, .000001])
        self.assertEqual(result['slots'][0]['rotation'], [23.123456789, -45.987654321, 0])
        self.assertEqual(result['slots'][0]['colour'], [12, 34, 56, 78])
        self.assertEqual(result['sourceCounts'], dict(images=1, masks=1))

    def test_float32_tolerance_is_bounded_and_not_a_crop_permission(self):
        source = drawing()
        source['rows'][0][1] = .00009
        self.assertLess(assembly.assemble(source, 'example')['clipProof']['maxUnmaskedOutside'], .0001)
        source['rows'][0][1] = .001
        with self.assertRaisesRegex(AssertionError, 'outside shared clip'):
            assembly.assemble(source, 'example')
        source = drawing()
        source['imageMasks'][0].update(enabled=True, offsetX=.00009)
        self.assertEqual(assembly.assemble(source, 'example')['clipProof']['maxMaskCenterError'], .00009)
        source['imageMasks'][0]['offsetX'] = .001
        with self.assertRaisesRegex(AssertionError, 'non-equivalent source clip'):
            assembly.assemble(source, 'example')

    def test_non_equivalent_parent_and_mask_semantics_are_rejected(self):
        for mutate in [
            lambda d: d['root'].__setitem__(3, 64),
            lambda d: d['rows'][0].__setitem__(5, 0),
            lambda d: d['rows'][0].__setitem__(11, 2),
            lambda d: d['imageMasks'][0].update(enabled=True, width=143),
            lambda d: d['imageMasks'][0].update(enabled=True, imageId=100002),
            lambda d: d['imageMasks'][0].update(enabled=True, reverseMaskArea=True),
            lambda d: d['imageMasks'][0].update(enabled=True, enableSoftEdge=True),
        ]:
            with self.subTest(mutate=mutate):
                source = drawing()
                mutate(source)
                with self.assertRaises(AssertionError):
                    assembly.assemble(source, 'example')

    def test_main_rejects_all_source_aliases_before_parsing_or_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            script = root / 'scripts/art/assemble-native-card-samples.py'
            script.parent.mkdir(parents=True)
            script.write_bytes(SCRIPT.read_bytes())
            isolated_spec = importlib.util.spec_from_file_location('isolated_native_card_samples', script)
            isolated = importlib.util.module_from_spec(isolated_spec)
            isolated_spec.loader.exec_module(isolated)
            sources = [script]
            for name in assembly.IDS:
                for extension in ('lua', 'json'):
                    source = root / 'art/cards/geo-samples' / name / f'native-art.{extension}'
                    source.parent.mkdir(parents=True, exist_ok=True)
                    source.write_text(f'preserve {name} {extension}', encoding='utf-8')
                    sources.append(source)
            output = root / 'art/cards/geo-samples/native-layout.json'
            for source in sources:
                for kind in ('symlink', 'hardlink'):
                    with self.subTest(source=source.name, kind=kind):
                        before = {path: path.read_bytes() for path in sources}
                        if kind == 'symlink':
                            output.symlink_to(source)
                        else:
                            os.link(source, output)
                        try:
                            with patch('sys.argv', [str(script), '--editor', str(root / 'not-needed')]), \
                                 patch.object(isolated.subprocess, 'check_output', side_effect=AssertionError('preflight ran too late')):
                                with self.assertRaisesRegex(ValueError, 'must not overwrite an input'):
                                    isolated.main()
                            self.assertEqual({path: path.read_bytes() for path in sources}, before)
                        finally:
                            output.unlink()

    def test_cli_canonicalizes_crlf_for_parser_and_hash_without_rewriting_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source_text = {name: f'-- {name}\nreturn {{}}\n' for name in assembly.IDS}
            parser = Mock(side_effect=lambda text: drawing())
            app = types.ModuleType('app')
            app.lua_scene = types.SimpleNamespace(read_drawing=parser)
            outputs = []
            for newline in ('\n', '\r\n'):
                inputs = {}
                for name, text in source_text.items():
                    folder = root / 'art/cards/geo-samples' / name
                    folder.mkdir(parents=True, exist_ok=True)
                    for extension, content in [('lua', text), ('json', '{}\n')]:
                        source = folder / f'native-art.{extension}'
                        inputs[source] = content.replace('\n', newline).encode('utf-8')
                        source.write_bytes(inputs[source])
                with patch.object(assembly, 'ROOT', root), \
                     patch.object(sys, 'argv', [str(SCRIPT), '--editor', str(root / 'mock-editor')]), \
                     patch.object(sys, 'path', list(sys.path)), \
                     patch.dict(sys.modules, {'app': app}), \
                     patch.object(assembly.subprocess, 'check_output', return_value=assembly.EDITOR_COMMIT), \
                     contextlib.redirect_stdout(io.StringIO()):
                    assembly.main()
                outputs.append((root / 'art/cards/geo-samples/native-layout.json').read_bytes())
                self.assertEqual({path: path.read_bytes() for path in inputs}, inputs)
            self.assertEqual(outputs[0], outputs[1], 'source hashes and output must not depend on checkout line endings')
            self.assertEqual(parser.call_args_list, [call(text) for text in source_text.values()] * 2)
            self.assertEqual(list(json.loads(outputs[0])['samples']), list(assembly.IDS))

    def test_output_symlink_cannot_escape_the_isolated_repository(self):
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            root = parent / 'repo'
            root.mkdir()
            outside = parent / 'outside.txt'
            outside.write_text('untouched', encoding='utf-8')
            output = root / 'output.json'
            output.symlink_to(outside)
            with patch.object(assembly, 'ROOT', root):
                with self.assertRaisesRegex(ValueError, 'within the candidate repository'):
                    assembly.reject_output_alias(output, [])
            self.assertEqual(outside.read_text(encoding='utf-8'), 'untouched')

    def test_pool_has_one_mask_and_never_more_than_sixty_direct_children(self):
        pool = assembly.pool_tree(138)
        self.assertFalse(pool['visible'])
        clip = pool['children'][0]
        self.assertTrue(clip['mask'])
        self.assertEqual(clip['size'], [144, 34])
        self.assertNotIn('children', clip)
        self.assertEqual([len(group['children']) for group in pool['children'][1:]], [60, 60, 18])
        self.assertEqual(sum(len(group['children']) for group in pool['children'][1:]) + 5, 143)
        for group in pool['children'][1:]:
            self.assertEqual(group['position'], [0, 0])
            for slot in group['children']:
                self.assertFalse(slot['visible'])
                self.assertNotIn('script', slot)


if __name__ == '__main__':
    unittest.main()
