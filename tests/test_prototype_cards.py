"""The offline review prototype must not drift from the canonical card data."""
import importlib.util
import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


class PrototypeCardTests(unittest.TestCase):
    def test_embedded_cards_match_source_and_presentation(self):
        html = (ROOT / 'docs/design/prototype/index.html').read_text(encoding='utf-8')
        declarations = list(re.finditer(r'\bconst\s+CARDS\s*=\s*', html))
        self.assertEqual(len(declarations), 1, 'expected one embedded CARDS declaration')
        tail = html[declarations[0].end():]
        rows, end = json.JSONDecoder().raw_decode(tail)
        self.assertTrue(tail[end:].lstrip().startswith(';'), 'CARDS must be plain JSON')
        self.assertIsInstance(rows, list)
        for row in rows:
            self.assertIsInstance(row, list)
            self.assertEqual(len(row), 8, 'expected eight card fields')
            self.assertTrue(all(isinstance(value, str) for value in row))
        by_id = {row[0]: row for row in rows}
        self.assertEqual(len(by_id), len(rows), 'duplicate prototype card ID')

        spec = importlib.util.spec_from_file_location('renderer', ROOT / 'tools/render_traveler_cards.py')
        renderer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(renderer)
        source = renderer.load_json(ROOT / 'data/cards.json')
        overlay = renderer.load_json(ROOT / 'data/presentation/traveler.zh-CN.json')
        rendered = renderer.render_cards(source, overlay)['cards']
        definitions = {card['id']: card for card in source['cards']}
        self.assertEqual(set(by_id), set(definitions), 'missing or unknown prototype card IDs')
        for card in rendered:
            definition = definitions[card['id']]
            expected = [card['id'], card['name'], definition['type'], definition['rarity'],
                        card['cost'], card['text'], card['upgradeCost'], card['upgradeText']]
            with self.subTest(card=card['id']):
                self.assertEqual(by_id[card['id']], expected)


if __name__ == '__main__':
    unittest.main()
