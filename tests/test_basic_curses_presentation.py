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
        ordinary_ids = {'regret', 'injury', 'doubt', 'pain', 'decay', 'shame',
                        'writhe', 'clumsy', 'normality', 'parasite'}
        self.assertEqual({card['id'] for card in curses}, ordinary_ids | {'curse_of_the_bell', 'necronomicurse'})
        self.assertEqual(sum(card['id'] in ordinary_ids for card in curses), 10)
        pools = json.loads((ROOT / 'data/reference/sts1-card-pools/pools.json').read_text(encoding='utf8'))['pools']
        for key in ('curseRaw', 'curseLibrarySelection'):
            self.assertEqual(len(pools[key]), 10)
            self.assertEqual(set(pools[key]), {card['sts_name'] for card in curses if card['id'] in ordinary_ids})
            self.assertNotIn('CurseOfTheBell', pools[key])
            self.assertNotIn('Necronomicurse', pools[key])
        bell = next(card for card in curses if card['id'] == 'curse_of_the_bell')
        self.assertEqual(bell['sourceId'], 'CurseOfTheBell')
        self.assertEqual(bell['effects'], [])
        self.assertEqual(bell['text'], '无法打出。无法从牌组中移除。')
        necro = next(card for card in curses if card['id'] == 'necronomicurse')
        self.assertEqual(necro['sourceId'], 'Necronomicurse')
        self.assertEqual(necro['rarity'], 'special')
        self.assertEqual(necro['effects'], [])
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
