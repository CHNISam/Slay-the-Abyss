"""Card-local art order, without fitting, editor dependencies or file writes."""
import copy
from pathlib import Path
import runpy
from types import SimpleNamespace
import unittest


ROOT = Path(__file__).resolve().parents[1]
ASSEMBLE = runpy.run_path(str(ROOT / 'scripts/art/process-ai-samples.py'))['assemble_card_art']


class Model(SimpleNamespace):
    def model_copy(self, *, deep=False):
        return copy.deepcopy(self) if deep else copy.copy(self)


def element(id_, *, background=False, z=0, mask=None, **extra):
    return Model(id=id_, isBackground=background, zIndex=z, x=43, y=21,
                 width=60, height=28, luaMask=mask, rotation=31, rotationX=-7,
                 rotationY=11, color='#ab4321', opacity=.7, **extra)


def order(elements):
    # Pinned editor main.scene_to_gia_document and lua_scene._control_script.
    return sorted(elements, key=lambda e: (0 if e.isBackground else 1, e.zIndex))


class CardArtAssemblyTests(unittest.TestCase):
    def setUp(self):
        self.frame = Model(elements=[element('shell', z=10), element('attack-art-panel', z=20),
                                     element('type-band', z=30),
                                     *[element('card-' + slot, z=40+i, type='textbox',
                                       textBox={'text': value, 'fontSize': 14, 'minFontSize': 14,
                                                'autoSize': True})
                                       for i, (slot, value) in enumerate([
                                           ('title', '星陨剑'), ('type', '攻击'),
                                           ('description', '对所有敌人造成 8 点伤害。'), ('cost', '1')])]],
                           canvas={'width': 180, 'height': 240}, meta={'source': ['unchanged']},
                           library={'preserved': [1, 2]})
        self.mask = Model(enabled=True, offsetX=-11, offsetY=15, width=288, height=128,
                          imageId=100001, rotation=17, enableSoftEdge=True,
                          softEdgeLeft=3, reverseMaskArea=False)
        # Deliberately NOT already in canonical order. Background z's can be
        # greater than foreground z's; equal z's must remain stable.
        self.art = Model(elements=[
            element('ink-a', z=-100, mask=self.mask),
            element('base-high', background=True, z=900),
            element('base-low', background=True, z=700),
            element('ink-b', z=-100),
            element('ink-last', z=1000),
        ])

    def test_nested_background_is_not_promoted_behind_card_shell(self):
        result = ASSEMBLE(self.frame, self.art)
        expected = ['shell', 'attack-art-panel', 'art-base-low', 'art-base-high',
                    'art-ink-a', 'art-ink-b', 'art-ink-last', 'type-band',
                    'card-title', 'card-type', 'card-description', 'card-cost']
        self.assertEqual([e.id for e in order(result.elements)], expected)
        self.assertTrue(all(not e.isBackground for e in result.elements if e.id.startswith('art-')))
        self.assertEqual([e.zIndex for e in result.elements], list(range(len(expected))))

    def test_canonical_local_art_order_including_stable_ties_is_preserved(self):
        result = ASSEMBLE(self.frame, self.art)
        self.assertEqual([e.id for e in result.elements if e.id.startswith('art-')],
                         ['art-' + e.id for e in order(self.art.elements)])

    def test_masks_transforms_and_all_other_art_properties_are_preserved(self):
        result = ASSEMBLE(self.frame, self.art)
        by_id = {e.id: e for e in result.elements}
        for source in self.art.elements:
            expected = source.model_copy(deep=True)
            expected.id = 'art-' + source.id
            expected.isBackground = False
            expected.zIndex = by_id[expected.id].zIndex
            expected.x, expected.y = 18 + source.x / 2, 48 + source.y / 2
            expected.width, expected.height = source.width / 2, source.height / 2
            if expected.luaMask:
                for field in ('offsetX', 'offsetY', 'width', 'height'):
                    setattr(expected.luaMask, field, getattr(expected.luaMask, field) / 2)
            self.assertEqual(by_id[expected.id], expected)

    def test_four_text_slots_outer_properties_and_background_are_not_restyled(self):
        self.frame.elements[0].isBackground = True
        result = ASSEMBLE(self.frame, self.art)
        by_id = {e.id: e for e in result.elements}
        for source in self.frame.elements:
            expected = source.model_copy(deep=True)
            expected.zIndex = by_id[expected.id].zIndex
            self.assertEqual(by_id[expected.id], expected)
        self.assertEqual([e.id for e in result.elements if getattr(e, 'type', '') == 'textbox'],
                         ['card-title', 'card-type', 'card-description', 'card-cost'])
        self.assertEqual(result.canvas, self.frame.canvas)
        self.assertEqual(result.meta, self.frame.meta)
        self.assertEqual(result.library, self.frame.library)

    def test_inputs_standalone_background_and_copies_are_independent(self):
        frame_before, art_before = copy.deepcopy(self.frame), copy.deepcopy(self.art)
        result = ASSEMBLE(self.frame, self.art)
        result.meta['source'].append('output-only')
        result.library['preserved'].append('output-only')
        result.canvas['width'] = 999
        result.elements[0].color = '#000000'
        next(e for e in result.elements if e.id == 'card-title').textBox['text'] = 'output-only'
        next(e for e in result.elements if e.id == 'art-ink-a').luaMask.offsetX = 999
        self.assertEqual(self.frame, frame_before)
        self.assertEqual(self.art, art_before)
        self.assertEqual([e.id for e in order(self.art.elements)],
                         ['base-low', 'base-high', 'ink-a', 'ink-b', 'ink-last'])
        self.assertTrue(self.art.elements[1].isBackground)

    def test_empty_art_adds_no_controls_and_does_not_mutate_frame(self):
        before = copy.deepcopy(self.frame)
        result = ASSEMBLE(self.frame, Model(elements=[]))
        self.assertEqual([e.id for e in result.elements], [e.id for e in self.frame.elements])
        self.assertEqual(self.frame, before)


if __name__ == '__main__':
    unittest.main(verbosity=2)
