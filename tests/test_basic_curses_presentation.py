import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('curse_renderer', ROOT / 'tools/render_traveler_cards.py')
renderer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(renderer)

class BasicCursePresentationTests(unittest.TestCase):
    def test_all_basic_curses_render_blank_cost_and_source_numeric_text(self):
        source = json.loads((ROOT / 'data/cards.json').read_text(encoding='utf8'))
        overlay = json.loads((ROOT / 'data/presentation/traveler.zh-CN.json').read_text(encoding='utf8'))
        rendered = {row['id']: row for row in renderer.render_cards(source, overlay)['cards']}
        curses = [row for row in source['cards'] if row['type'] == 'curse']
        self.assertEqual(len(curses), 10)
        for card in curses:
            with self.subTest(card=card['id']):
                row = rendered[card['id']]
                self.assertEqual(row['cost'], '')
                self.assertEqual(row['text'], card['text'])
                self.assertEqual(row.get('combatText', row['text']), card['text'])

    def test_unknown_curse_is_not_silently_rendered_as_supported(self):
        with self.assertRaises(renderer.PresentationError):
            renderer.cost_label({'id': 'unknown_curse', 'type': 'curse', 'cost': -2})

if __name__ == '__main__':
    unittest.main()
