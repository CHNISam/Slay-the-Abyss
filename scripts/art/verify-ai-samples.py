"""Inspect exported drawing records, not editor metadata; does not run the game."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--editor', type=Path, required=True)
args = parser.parse_args()
sys.path.insert(0, str(args.editor.resolve() / 'backend'))
from app import lua_scene
from vendor.primitive_shape import gia_lua

out = ROOT / 'art/processed/ai-samples'
template = gia_lua.parse_material_gia((args.editor.resolve() / 'backend/vendor/gia/image_template.gia').read_bytes(),ignore_mask=True)
records = []
for asset, route, stem in [('lumine','A','asset'),('lumine','B','asset'),('lumine','B2','asset'),
                            ('starfall','A','asset'),('starfall','B','asset'),('starfall','B','card')]:
    directory = out / asset / route
    scene = json.loads((directory / (stem+'.json')).read_text(encoding='utf-8'))
    source = (directory / (stem+'.lua')).read_text(encoding='utf-8')
    drawing = lua_scene.read_drawing(source)
    actual = lua_scene.drawing_to_scene(drawing)['elements']
    expected = sorted(scene['elements'], key=lambda e:(not e['isBackground'],e['zIndex']))
    assert len(actual) == len(expected)
    for a,b in zip(actual,expected):
        for key in ['x','y','width','height','rotation']:
            assert abs(a[key]-b[key]) < .002, (asset,route,key,a[key],b[key])
        if b['luaMask']:
            for key in ['width','height','offsetX','offsetY']:
                assert abs(a['luaMask'][key]-b['luaMask'][key]) < .002
    mask_count = sum(bool(e.get('luaMask') and e['luaMask']['enabled']) for e in expected)
    item = dict(asset=asset,route=route,stem=stem,contentControls=len(actual),maskControls=mask_count,
                runtimeControls=len(actual)+mask_count,literalLuaGeometry=True)
    gia = directory / (stem+'.gia')
    if gia.exists():
        parsed = gia_lua.parse_material_gia(gia.read_bytes(),ignore_mask=True)
        assert len(parsed['records']) == len(actual)
        assert parsed['ignored_mask'] == (route == 'B')
        # Upstream's released image_template already contains these deleted children.
        # Do not silently certify them as absent or rewrite the vendor converter.
        assert parsed['missing_refs'] == template['missing_refs']
        item['giaBinaryRoundtrip'] = True
        item['inheritedTemplateMissingRefs'] = len(parsed['missing_refs'])
        item['giaMode'] = 'overlimit'
    records.append(item)
manifest = []
for p in sorted(out.rglob('*')):
    if p.is_file() and p.name != 'verification.json':
        manifest.append(dict(path=str(p.relative_to(ROOT)).replace('\\','/'),bytes=p.stat().st_size,
                             sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
report = {'checks':records,'files':manifest,'officialImport':'pending','inGame':'pending',
          'note':'Literal drawing and binary inspection cannot establish game display or performance.'}
(out/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(records,ensure_ascii=False))
