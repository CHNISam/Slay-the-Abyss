import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('renderer', ROOT / 'tools/render_traveler_cards.py')
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)


def pair(value=3):
    return [dict(op='applyStatusAll', status=status, value=value, targetGroup='weak_then_vulnerable')
            for status in ('weak', 'vulnerable')]


class ShockwavePresentationTests(unittest.TestCase):
    def test_real_variants_keep_original_text_cost_name_and_indices(self):
        source = r.load_json(ROOT / 'data/cards.json')
        overlay = r.load_json(ROOT / 'data/presentation/traveler.zh-CN.json')
        before = copy.deepcopy((source, overlay))
        rendered = r.render_cards(source, overlay)
        result = next(c for c in rendered['cards'] if c['id'] == 'shockwave')
        self.assertEqual(result, dict(id='shockwave', name='Shockwave', cost='2', upgradeCost='2',
            text='为每个敌人施加 3 回合虚弱和 3 回合易伤。打出后消耗本牌。',
            upgradeText='为每个敌人施加 5 回合虚弱和 5 回合易伤。打出后消耗本牌。'))
        for card in source['cards']:
            for effects in (card['effects'], card.get('upgrade', {}).get('effects', [])):
                for effect in effects:
                    effect.pop('targetGroup', None)
        self.assertEqual(r.render_cards(source, overlay), rendered)
        self.assertEqual(overlay, before[1])

    def test_bounded_pair_and_surrounding_ordinary_effects(self):
        for amount in (1, 3, 3.0, 5, 2147483647):
            with self.subTest(amount=amount):
                effects = [dict(op='energy', value=1)] + pair(amount) + [dict(op='block', value=7)]
                before = copy.deepcopy(effects)
                r.validate_effects(effects)
                self.assertEqual(effects, before)

    def test_malformed_pair_is_not_silently_rendered(self):
        cases = []
        p = pair(); p.pop(); cases.append(p)
        for member in (0, 1):
            p = pair(); del p[member]['targetGroup']; cases.append(p)
        p = pair(); p.insert(1, dict(op='energy', value=1)); cases.append(p)
        cases += [pair() + [pair()[0]], pair() + pair(), list(reversed(pair()))]
        for key, value in (('op', 'gainStatus'), ('status', 'frail'), ('status', 'vulnerable'),
                           ('value', 5), ('target', 'all'), ('times', 1), ('then', []), ('if', 'x'), ('extra', False)):
            p = pair(); p[0][key] = value; cases.append(p)
        for marker in (False, 0, '', 'other', {}, [], None, True):
            p = pair()
            for e in p: e['targetGroup'] = marker
            cases.append(p)
        for amount in (-1, 0, 0.5, float('nan'), float('inf'), -float('inf'), '3', 2147483648, True):
            cases.append(pair(amount))
        for i, effects in enumerate(cases):
            with self.subTest(case=i, effects=effects):
                with self.assertRaises(r.PresentationError): r.validate_effects(effects)

    def test_nested_group_rejected_even_in_unreachable_condition(self):
        with self.assertRaises(r.PresentationError):
            r.validate_effects([dict(op='conditional', **{'if': 'target_vulnerable', 'then': pair()})])

    def test_unmarked_contract_and_unknown_fields_are_unchanged(self):
        r.validate_effects([])
        r.validate_effects([dict(op='applyStatusAll',status='weak',value=0)])
        r.validate_effects([dict(op='conditional', **{'if':'legacy','then':[dict(op='gainStatus',value=-2)]})])
        with self.assertRaises(r.PresentationError): r.validate_effects([dict(op='block',value=3,mystery=True)])
        with self.assertRaises(r.PresentationError): r.validate_effects([dict(op='block',value=True)])


if __name__ == '__main__':
    unittest.main()
