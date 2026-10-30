import copy
import re
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

    def test_live_tokens_cover_exactly_modifiable_damage_and_block_values(self):
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
            for key, data, printed in (('combatText', source, card['text']), ('upgradeCombatText', upgraded, card['upgradeText'])):
                live = [i for i, e in enumerate(data['effects']) if e['op'] in ('damage', 'damageAll', 'block','fiendFire','feed','reaper','damageRandom','secondWind')
                        and f'{{effects.{i}.value}}' in (overlay['textTemplate'] if key == 'combatText' else overlay.get('upgradeTextTemplate', overlay['textTemplate']))]
                if not live:
                    self.assertNotIn(key, card)
                    continue
                text = card[key]
                # Only live tokens remain, and filling them with source values gives the printed text.
                self.assertEqual(set(re.findall(r'\{([^{}]+)\}', text)), {f'effects.{i}.value' for i in live})
                for i in live:
                    text = text.replace(f'{{effects.{i}.value}}', str(data['effects'][i]['value']))
                self.assertEqual(text, printed)
        self.assertEqual({c['id'] for c in cards if 'combatText' in c}, {
            'strike', 'defend', 'bash', 'cleave', 'clothesline', 'iron_wave', 'anger', 'clash', 'true_grit',
            'twin_strike', 'pommel_strike', 'shrug_it_off', 'thunderclap', 'uppercut', 'carnage', 'dropkick',
            'ghostly_armor', 'hemokinesis', 'rampage', 'whirlwind', 'impervious', 'bludgeon', 'reaper',
            'armaments','headbutt','heavy_blade','perfected_strike','sword_boomerang','wild_strike',
            'blood_for_blood','flame_barrier','power_through','pummel','reckless_charge','searing_blow',
            'second_wind','sentinel','sever_soul','feed','fiend_fire','immolate'})
        self.assertEqual(len(cards), 90)
        bell = next(card for card in cards if card['id'] == 'curse_of_the_bell')
        self.assertEqual(bell['text'], '无法打出。无法从牌组中移除。')
        self.assertEqual(bell['upgradeText'], bell['text'])
        self.assertNotIn('combatText', bell)
        self.assertNotIn('upgradeCombatText', bell)
        self.assertEqual(sum(card['type'] == 'curse' for card in self.source['cards']), 11)
        self.assertEqual(sum(card['type'] == 'curse' and card['id'] != 'curse_of_the_bell'
                             for card in self.source['cards']), 10)
        self.assertEqual(sum(card['type'] == 'status' for card in self.source['cards']), 4)
        self.assertEqual(sum(card['type'] not in ('status', 'curse') for card in self.source['cards']), 75)
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
