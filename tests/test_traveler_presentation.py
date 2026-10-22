import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'tools/render_traveler_cards.py'

class PresentationTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(SCRIPT.exists(), 'renderer has not been implemented')
        spec = importlib.util.spec_from_file_location('renderer', SCRIPT)
        self.m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.m)
        self.source = {'cards': [{'id': 'guard', 'name': '原名称', 'sts_name': 'Internal', 'cost': 1, 'effects': [{'op': 'block', 'value': 7}, {'op': 'exhaustRandom', 'value': 1}], 'upgrade': {'effects': [{'op': 'block', 'value': 9}, {'op': 'exhaustChoose', 'value': 1}]}}]}
        self.overlay = {'locale': 'zh-CN', 'cards': {'guard': {'name': '踏沙守心', 'textTemplate': '获得{effects.0.value}格挡，随机消耗{effects.1.value}张牌。', 'upgradeTextTemplate': '获得{effects.0.value}格挡，选择消耗{effects.1.value}张牌。'}}}

    def test_base_upgrade_and_inputs_unchanged(self):
        before = copy.deepcopy((self.source, self.overlay))
        result = self.m.render_cards(self.source, self.overlay)
        c = result['cards'][0]
        self.assertEqual(c, {'id': 'guard', 'name': '踏沙守心', 'cost': '1', 'text': '获得7格挡，随机消耗1张牌。', 'upgradeCost': '1', 'upgradeText': '获得9格挡，选择消耗1张牌。'})
        self.assertEqual(before, (self.source, self.overlay))
        self.assertNotIn('Internal', json.dumps(result))

    def test_cost_upgrade_inherits_effects(self):
        self.source['cards'][0]['upgrade'] = {'cost': 0}
        del self.overlay['cards']['guard']['upgradeTextTemplate']
        c = self.m.render_cards(self.source, self.overlay)['cards'][0]
        self.assertEqual(c['upgradeCost'], '0')
        self.assertEqual(c['text'], c['upgradeText'])

    def test_semantics_change_needs_explicit_upgrade_template(self):
        del self.overlay['cards']['guard']['upgradeTextTemplate']
        with self.assertRaises(self.m.PresentationError):
            self.m.render_cards(self.source, self.overlay)

    def test_x_cost(self):
        self.source['cards'][0]['costMode'] = 'all_energy'
        self.source['cards'][0]['cost'] = 0
        self.overlay['cards']['guard']['textTemplate'] = '消耗{cost}能量。'
        c = self.m.render_cards(self.source, self.overlay)['cards'][0]
        self.assertEqual(c['cost'], 'X')
        self.assertEqual(c['upgradeCost'], 'X')
        self.assertEqual(c['text'], '消耗X能量。')

    def test_nested_numeric_and_negative_values(self):
        self.source['cards'][0]['effects'] = [{'op': 'conditional', 'if': 'test', 'then': [{'op': 'gainStatus', 'value': -2}]}]
        self.source['cards'][0]['upgrade'] = {'cost': 0}
        self.overlay['cards']['guard']['textTemplate'] = '{effects.0.then.0.value}'
        del self.overlay['cards']['guard']['upgradeTextTemplate']
        self.assertEqual(self.m.render_cards(self.source, self.overlay)['cards'][0]['text'], '-2')

    def test_invalid_templates(self):
        for template in ('{effects.99.value}', '{effects.-1.value}', '{__class__}', '{name}', '{effects.0.op}', '{cost!r}', '{cost:02}', '{cost', 'cost}', '{{cost}}', '造成99伤害', '{effects.0.value.foo}'):
            with self.subTest(template=template):
                self.overlay['cards']['guard']['textTemplate'] = template
                with self.assertRaises(self.m.PresentationError):
                    self.m.render_cards(self.source, self.overlay)

    def test_missing_unknown_duplicate_and_bad_fields(self):
        for mutate in (
            lambda s,o: o['cards'].clear(),
            lambda s,o: o['cards'].update(extra=o['cards']['guard']),
            lambda s,o: s['cards'].append(copy.deepcopy(s['cards'][0])),
            lambda s,o: o['cards']['guard'].update(name=3),
            lambda s,o: o['cards']['guard'].update(cost=99),
            lambda s,o: o.update(unknown=1),
            lambda s,o: s['cards'][0]['upgrade'].update(id='different'),
            lambda s,o: s['cards'][0].update(costMode='mystery'),
        ):
            s,o = copy.deepcopy((self.source,self.overlay)); mutate(s,o)
            with self.assertRaises(self.m.PresentationError): self.m.render_cards(s,o)

    def test_unknown_effect_contract_and_invalid_numeric_rejected(self):
        for effect in ({'op': 'newUnknownOperation'}, {'op': 'block', 'value': True}, {'op': 'block', 'value': float('nan')}, {'op': 'block', 'value': 3, 'mystery': 1}, {'op': 'conditional', 'then': 'bad'}):
            self.source['cards'][0]['effects'] = [effect]
            self.overlay['cards']['guard']['textTemplate'] = '护住旅途。'
            with self.assertRaises(self.m.PresentationError):
                self.m.render_cards(self.source, self.overlay)

    def test_repository_37_card_integration(self):
        source = Path(os.environ.get('TRAVELER_SOURCE', ROOT / 'data/cards.json'))
        overlay = Path(os.environ.get('TRAVELER_OVERLAY', ROOT / 'data/presentation/traveler.zh-CN.json'))
        if not source.exists() and not overlay.exists() and not any(
                key in os.environ for key in ('TRAVELER_SOURCE', 'TRAVELER_OVERLAY')):
            self.skipTest('standalone checkout has no data; use TRAVELER_SOURCE and TRAVELER_OVERLAY')
        self.assertTrue(source.is_file(), f'integration source missing: {source}')
        self.assertTrue(overlay.is_file(), f'integration overlay missing: {overlay}')
        before = source.read_bytes(), overlay.read_bytes()
        source_data = self.m.load_json(source)
        data = self.m.render_cards(source_data, self.m.load_json(overlay))
        cards = {card['id']: card for card in data['cards']}
        self.assertEqual(len(cards), 37)
        self.assertEqual(len({c['name'] for c in cards.values()}), 37)
        self.assertEqual(cards['whirlwind']['cost'], 'X')
        self.assertEqual(cards['whirlwind']['upgradeCost'], 'X')
        self.assertIn('随机', cards['true_grit']['text'])
        self.assertIn('选择', cards['true_grit']['upgradeText'])
        self.assertNotIn('随机', cards['true_grit']['upgradeText'])
        source_cards = {card['id']: card for card in source_data['cards']}
        disarm = source_cards['disarm']
        upgraded_disarm = {**disarm, **disarm.get('upgrade', {})}
        self.assertIn(str(disarm['effects'][0]['value']), cards['disarm']['text'])
        self.assertIn(str(upgraded_disarm['effects'][0]['value']), cards['disarm']['upgradeText'])
        self.assertIn('本牌的一张复制', cards['anger']['text'])
        self.assertIn('本牌的一张复制', cards['anger']['upgradeText'])
        self.assertNotIn('sts_name', json.dumps(data))
        self.assertTrue(all('{' not in c['text'] + c['upgradeText'] for c in cards.values()))
        self.assertEqual(before, (source.read_bytes(), overlay.read_bytes()))

    def test_cli_stdout_errors_and_no_input_overwrite(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp); source=p/'source.json'; overlay=p/'overlay.json'
            source.write_text(json.dumps(self.source)); overlay.write_text(json.dumps(self.overlay))
            args=[sys.executable,str(SCRIPT),str(source),str(overlay)]
            run=lambda *extra: subprocess.run(args+list(extra),capture_output=True,encoding='utf-8')
            self.assertEqual(run().returncode,0)
            ascii_pipe = subprocess.run(args, capture_output=True, encoding='utf-8',
                                        env={**os.environ, 'PYTHONIOENCODING': 'ascii'})
            self.assertEqual(ascii_pipe.returncode, 0, ascii_pipe.stderr)
            self.assertEqual(json.loads(ascii_pipe.stdout)['locale'], 'zh-CN')
            self.assertEqual(set(p.iterdir()),{source,overlay})
            aliases=[source,overlay,p/'hardlink.json']
            os.link(overlay,aliases[2])
            before=(source.read_bytes(),overlay.read_bytes())
            for alias in aliases:
                r=run('--output',str(alias)); self.assertNotEqual(r.returncode,0); self.assertIn('error:',r.stderr)
            self.assertEqual(before,(source.read_bytes(),overlay.read_bytes()))
            overlay.write_text('{"locale":"zh-CN","cards":{},"cards":{}}')
            self.assertNotEqual(run().returncode,0)
            overlay.write_text('{')
            self.assertNotEqual(run().returncode,0)

    def test_cli_rejects_symlink_output_alias_when_supported(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp); source=p/'source.json'; overlay=p/'overlay.json'; alias=p/'symlink.json'
            source.write_text(json.dumps(self.source)); overlay.write_text(json.dumps(self.overlay))
            try:
                alias.symlink_to(source)
            except OSError as exc:
                if getattr(exc, 'winerror', None) == 1314:
                    self.skipTest('Windows account lacks symlink privilege; hardlink alias is tested separately')
                raise
            result=subprocess.run([sys.executable,str(SCRIPT),str(source),str(overlay),'--output',str(alias)],
                                  capture_output=True,encoding='utf-8')
            self.assertNotEqual(result.returncode,0)
            self.assertIn('error:',result.stderr)

if __name__ == '__main__': unittest.main()
