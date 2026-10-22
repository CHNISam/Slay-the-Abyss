"""Build static capacity fixtures using the pinned Image Editor exporters, offline only."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/spikes/card-capacity'
EDITOR_COMMIT = '103025f9095d8089e3f9bf097f4d0c5fe039d546'


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def sha(path):
    payload = path.read_text(encoding='utf-8').encode('utf-8') if path.suffix in ('.json', '.lua', '.py', '.ps1', '.txt', '.md') else path.read_bytes()
    return hashlib.sha256(payload).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--editor', type=Path, required=True)
    parser.add_argument('--validated-source', type=Path, required=True,
                        help='Validated text-height-compat/card.source.json (read-only input)')
    args = parser.parse_args()
    editor = args.editor.resolve()
    actual = subprocess.check_output(['git', '-C', str(editor), 'rev-parse', 'HEAD'], text=True).strip()
    if actual != EDITOR_COMMIT:
        parser.error(f'Expected editor {EDITOR_COMMIT}; found {actual}')
    sys.path.insert(0, str(editor / 'backend'))
    sys.path.insert(0, str(ROOT))
    from app import main as upstream
    from tools.render_traveler_cards import render_cards
    from PIL import Image, ImageDraw, ImageFont

    source_path = args.validated_source.resolve()
    upstream_lua = source_path.with_name('card.lua')
    validated_lua_bytes = upstream_lua.read_bytes()
    validated_lua = upstream_lua.read_text(encoding='utf-8')
    source = json.loads(source_path.read_text(encoding='utf-8'))
    assert source['canvas']['width'] == 180 and source['canvas']['height'] == 240
    elements = {e['id']: e for e in source['elements']}
    assert len(elements) == 15
    assert elements['card-title']['height'] == elements['card-type']['height'] == 40
    assert [elements['card-description'][k] for k in ('width', 'height')] == [132, 92]
    cards_path = ROOT / 'data/cards.json'
    overlay_path = ROOT / 'data/presentation/traveler.zh-CN.json'
    theme_path = ROOT / 'data/presentation/ui_theme.json'
    data = json.loads(cards_path.read_text(encoding='utf-8'))
    overlay = json.loads(overlay_path.read_text(encoding='utf-8'))
    theme = json.loads(theme_path.read_text(encoding='utf-8'))
    display = render_cards(data, overlay)['cards']
    # Stable tie-break: source order, base text before upgraded text.
    candidates = [(c, field) for c in display for field in ('text', 'upgradeText')]
    longest, field = max(candidates, key=lambda row: len(row[0][row[1]]))
    card = next(c for c in data['cards'] if c['id'] == longest['id'])
    longest_source = copy.deepcopy(source)
    by_id = {e['id']: e for e in longest_source['elements']}
    text_values = {'card-title': longest['name'], 'card-type': {'attack': '攻击', 'skill': '技能', 'power': '能力', 'status': '状态'}[card['type']],
                   'card-description': longest[field], 'card-cost': longest['upgradeCost' if field == 'upgradeText' else 'cost']}
    for key, value in text_values.items():
        by_id[key]['textBox']['text'] = str(value)
    # This fixture is an attack card; preserve all validated geometry and tint.
    assert card['type'] == 'attack'
    longest_source['meta']['sourceName'] = 'capacity-longest-zh-CN'
    OUT.mkdir(parents=True, exist_ok=True)
    exports = {}
    for name, fixture in [('reference', source), ('longest', longest_source)]:
        folder = OUT / name
        folder.mkdir(exist_ok=True)
        write_json(folder / 'card.source.json', fixture)
        scene = upstream.import_scene(upstream.ImportRequest(sourceType='json', content=json.dumps(fixture))).scene
        request = upstream.ExportRequest(scene=scene, giaGroupName='Abyss_Geo_Card_Spike' if name == 'reference' else 'Abyss_Capacity_Longest')
        for suffix, exporter in [('json', upstream.export_json), ('lua', upstream.export_lua), ('png', upstream.export_png)]:
            (folder / ('card.' + suffix)).write_bytes(exporter(request).body)
        parsed_json = upstream.parse_json_scene((folder / 'card.json').read_text(encoding='utf-8'))
        parsed_lua = upstream.parse_lua_scene((folder / 'card.lua').read_text(encoding='utf-8'))
        assert parsed_json.elements == parsed_lua.elements == scene.elements
        assert len(scene.elements) == 15
        # Entire exported function section remains byte-for-byte identical in both fixtures.
        exports[name] = (folder / 'card.lua').read_text(encoding='utf-8')
    start, end = 'local ALIGN_H =', '-- 编辑器回导数据'
    assert exports['reference'].split(start)[1].split(end)[0] == exports['longest'].split(start)[1].split(end)[0]
    assert exports['reference'] == validated_lua, 'Reference must exactly reuse validated export'
    # Retain the validated file's original line endings as well as its contents.
    (OUT / 'reference/card.lua').write_bytes(validated_lua_bytes)

    scenarios = []
    for name, count, fixture in [('baseline', 0, 'reference'), ('one', 1, 'reference'), ('five', 5, 'reference'), ('ten', 10, 'reference'), ('longest', 1, 'longest')]:
        slots = []
        for i in range(count):
            x = 0 if count == 1 else (i % 5 - 2) * 180
            y = 0 if count < 10 else (130 if i < 5 else -130)
            slots.append({'name': f'Card{i+1:02d}', 'kind': 'container', 'size': [180, 240],
                          'position': [x, y], 'script': f'ART_Capacity_{i+1:02d}'})
        controls = slots + [
            {'name': 'Status', 'kind': 'text', 'position': [0, 300], 'size': [1100, 40], 'text': {'content': f'容量验收 {name} / {count}卡 / {count * 15}动态控件 / 总数{16 * count + 6}', 'fontSize': theme['font']['heading'], 'backgroundOpacity': 0, 'colour': theme['color']['text'], 'align': 'centre'}},
            {'name': 'Plate', 'kind': 'image', 'position': [0, -285], 'size': [240, 40], 'image': 100001, 'colour': theme['color']['geoDeep']},
            {'name': 'Label', 'kind': 'text', 'position': [0, -285], 'size': [240, 40], 'text': {'content': '点击检查', 'fontSize': theme['font']['heading'], 'backgroundOpacity': 0, 'align': 'centre'}},
            {'name': 'Confirm', 'kind': 'cursorArea', 'position': [0, -285], 'size': [240, 40]},
            {'name': 'Metrics', 'kind': 'text', 'position': [0, -330], 'size': [1000, 40], 'text': {'content': '客户端帧间隔采样中（10秒）', 'fontSize': theme['font']['body'], 'backgroundOpacity': 0, 'colour': theme['color']['text'], 'align': 'centre'}},
        ]
        spec = {'name': 'ART_Capacity', 'script': 'ART_Capacity_Probe', 'showCursor': True,
                'outputName': 'abyss-capacity-' + name, 'controls': controls}
        write_json(OUT / (name + '-ui.json'), spec)
        # Check the entire transparent host bounds against 1280x720; no scaling or overlap.
        for control in controls:
            x, y = control['position']; w, h = control['size']
            assert abs(x) + w / 2 <= 640 and abs(y) + h / 2 <= 360
        for i, a in enumerate(slots):
            for b in slots[i + 1:]:
                assert abs(a['position'][0] - b['position'][0]) >= 180 or abs(a['position'][1] - b['position'][1]) >= 240
        scenarios.append({'id': name, 'fixture': fixture, 'ui': name + '-ui.json', 'cards': count,
                          'dynamicImages': 11 * count, 'dynamicTextboxes': 4 * count,
                          'cardHosts': count, 'diagnosticControls': 5, 'rootHosts': 1,
                          'activeControls': 16 * count + 6, 'storedTemplates': 2,
                          'slots': [{'name': s['name'], 'position': s['position'], 'script': s['script']} for s in slots]})
        # Pillow is an offline position/typography preview, not the game renderer.
        image = Image.new('RGBA', (1280, 720), theme['color']['backdrop'])
        card_png = Image.open(OUT / fixture / 'card.png').convert('RGBA')
        for slot in slots:
            x, y = slot['position']
            image.alpha_composite(card_png, (int(640 + x - 90), int(360 - y - 120)))
        draw = ImageDraw.Draw(image)
        font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 18)
        draw.text((640, 60), controls[count]['text']['content'], font=font, fill=theme['color']['text'], anchor='mm')
        draw.rectangle((520, 625, 760, 665), fill=theme['color']['geoDeep'])
        draw.text((640, 645), '点击检查', font=font, fill=theme['color']['text'], anchor='mm')
        draw.text((640, 690), '离线布局预览；客户端帧间隔待实测', font=font, fill=theme['color']['text'], anchor='mm')
        image.convert('RGB').save(OUT / (name + '-preview.png'))
    write_json(OUT / 'manifest.json', {
        'editorCommit': actual, 'referenceSource': 'validated text-height-compat/card.source.json',
        'hashConvention': 'SHA256; UTF-8 text normalized to LF, binary files unchanged',
        'referenceSourceSha256': sha(source_path), 'referenceLuaSha256': sha(upstream_lua),
        'sourceDataSha256': {'cards': sha(cards_path), 'presentation': sha(overlay_path), 'theme': sha(theme_path)},
        'longest': {'cardId': longest['id'], 'variant': field, 'characters': len(longest[field]), 'text': longest[field], 'displayName': longest['name'], 'candidates': len(candidates)},
        'canvas': [1280, 720], 'cardCanvas': [180, 240], 'cardFrame': [148, 208], 'scale': 1,
        'imageTemplateIndex': None, 'textTemplateIndex': None, 'scenarios': scenarios,
        'offlineChecks': ['Reference Lua byte-identical', 'Reference/longest JSON-Lua element round-trip', 'Exported functions identical', 'All host bounds within 1280x720', 'No card-host overlap', 'Longest of 74 rendered base/upgrade texts'],
        'platformCompile': None, 'saveImport': None, 'devicePlaytest': None, 'performance': None,
        'sha256': {p.relative_to(OUT).as_posix(): sha(p) for p in sorted(OUT.rglob('*')) if p.is_file() and p.name != 'manifest.json' and '__pycache__' not in p.parts}
    })
    # Fengari deliberately has no io.open; inject only these local fixtures into its VM.
    vm = ROOT / 'build/art-capacity/verify.lua'
    vm.parent.mkdir(parents=True, exist_ok=True)
    prelude = 'CAPACITY_SOURCES = {}\n'
    for relative in ('reference/card.lua', 'longest/card.lua', 'probe.lua'):
        content = (OUT / relative).read_text(encoding='utf-8')
        equals = '='
        while ']' + equals + ']' in content:
            equals += '='
        key = 'art/spikes/card-capacity/' + relative
        prelude += f'CAPACITY_SOURCES["{key}"] = [{equals}[{content}]{equals}]\n'
    vm.write_text(prelude + (OUT / 'verify.lua').read_text(encoding='utf-8'), encoding='utf-8')
    print(json.dumps({'longest': longest['id'], 'characters': len(longest[field]), 'scenarios': len(scenarios)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
