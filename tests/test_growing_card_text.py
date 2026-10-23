import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('renderer', ROOT / 'tools/render_traveler_cards.py')
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)

class GrowingCardTextTests(unittest.TestCase):
    def setUp(self):
        self.source = r.load_json(ROOT / 'data/cards.json')
        self.overlay = r.load_json(ROOT / 'data/presentation/traveler.zh-CN.json')

    def test_only_rampage_preserves_exact_damage_token_and_renders_growth(self):
        before = copy.deepcopy((self.source, self.overlay))
        cards = r.render_cards(self.source, self.overlay)['cards']
        for card in cards:
            source = next(c for c in self.source['cards'] if c['id'] == card['id'])
            overlay = self.overlay['cards'][card['id']]
            upgraded = {**source, **source.get('upgrade', {})}
            self.assertEqual(card['text'], r.render_template(overlay['textTemplate'], source))
            self.assertEqual(card['upgradeText'], r.render_template(overlay.get('upgradeTextTemplate', overlay['textTemplate']), upgraded))
            if card['id'] == 'rampage':
                self.assertEqual(card.get('combatText'), '对目标造成 {effects.0.value} 点伤害；随后本牌在本场战斗中的伤害增加 5 点。')
                self.assertEqual(card.get('upgradeCombatText'), '对目标造成 {effects.0.value} 点伤害；随后本牌在本场战斗中的伤害增加 8 点。')
            else:
                self.assertNotIn('combatText', card)
                self.assertNotIn('upgradeCombatText', card)
        self.assertEqual(len(cards), 37)
        self.assertEqual(before, (self.source, self.overlay))

    def test_damage_need_not_be_first_number_and_all_occurrences_are_preserved(self):
        self.overlay['cards']['rampage']['textTemplate'] = '{cost}费：成长{effects.1.value}；伤害{effects.0.value}，再述{effects.0.value}。'
        card = next(c for c in r.render_cards(self.source, self.overlay)['cards'] if c['id'] == 'rampage')
        self.assertEqual(card.get('combatText'), '1费：成长5；伤害{effects.0.value}，再述{effects.0.value}。')

    def test_preserved_damage_token_still_requires_valid_numeric_path(self):
        for value in (None, True, float('inf'), '8'):
            with self.subTest(value=value):
                source = copy.deepcopy(self.source)
                next(c for c in source['cards'] if c['id'] == 'rampage')['effects'][0]['value'] = value
                with self.assertRaises(r.PresentationError):
                    r.render_cards(source, self.overlay)

if __name__ == '__main__': unittest.main()
