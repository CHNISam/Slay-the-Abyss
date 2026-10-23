"""Re-export stored sample JSON and exercise positions with a mocked Lua UI API."""
import argparse
import json
import math
from pathlib import Path
import subprocess
import sys

from reproduce import export_lua

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--vendor', required=True, type=Path)
parser.add_argument('--fengari', required=True, type=Path)
args = parser.parse_args()
sys.path.insert(0, str(args.vendor.resolve()))
import lua_export

out = Path(__file__).resolve().parent
build = Path('build/portrait-audit')
build.mkdir(parents=True, exist_ok=True)
audits = []
for count in (64, 256):
    stem = 'portrait-' + str(count)
    data = json.loads((out/(stem+'.json')).read_text())
    lua = export_lua(data, lua_export, 'TECHNICAL SAMPLE '+str(count))
    (out/(stem+'.lua')).write_text(lua, encoding='utf-8', newline='\n')
    bounds = []
    expected = []
    for e in data['elements']:
        cx, cy = e['center']['x'], -e['center']['y']
        rx, ry = e['size']['rx'], e['size']['ry']
        angle = math.radians(e['rotation']['z'])
        ex = math.hypot(rx*math.cos(angle), ry*math.sin(angle))
        ey = math.hypot(rx*math.sin(angle), ry*math.cos(angle))
        bounds.append((cx-ex, cy-ey, cx+ex, cy+ey))
        expected.append('{'+str(e['relative']['x'])+','+str(e['relative']['y'])+'}')
    # Expected positions come from raw JSON relative fields, not the adapter.
    fixture = '''
local expected = {EXPECTED}
local positions = {}
local destroyed = 0
Color={FromRGBA=function(...) return {...} end}
Enum={ImageSource={StaticReference=1},ImageType={Stretch=1}}
script={object={}}
game={GetUICanvasSize=function() return 1280,720 end,
DestroyClientUIControl=function() destroyed=destroyed+1 end,
InstantiateClientUIControl=function()
local c=setmetatable({}, {__index=function() return function() end end})
c.SetAnchoredPosition=function(_,x,y) table.insert(positions,{x,y}) end
return c end}
printerr=error
CHUNK
OnStart()
assert(#positions==#expected)
for i,p in ipairs(positions) do
assert(math.abs(p[1]-expected[i][1])<0.011, 'x '..i)
assert(math.abs(p[2]-expected[i][2])<0.011, 'y '..i)
end
OnStart()
assert(destroyed==#expected)
assert(#positions==2*#expected)
OnDestroy()
assert(destroyed==2*#expected)
print('all positions and repeated-start/destroy lifecycle passed')
'''.replace('EXPECTED', ','.join(expected)).replace('CHUNK', lua.replace('local IMAGE_PREFAB_ID = 0','local IMAGE_PREFAB_ID = 1'))
    path = build/(stem+'.lua')
    original = lua_export.build_lua_export_text(data, image_name='UNADAPTED')
    baseline = fixture.replace(lua.replace('local IMAGE_PREFAB_ID = 0','local IMAGE_PREFAB_ID = 1'), original.replace('local IMAGE_PREFAB_ID = 0','local IMAGE_PREFAB_ID = 1'))
    baseline_path = build/(stem+'-baseline.lua')
    baseline_path.write_text(baseline,encoding='utf-8',newline='\n')
    failed = subprocess.run(['node',str(args.fengari.resolve()),str(baseline_path)],capture_output=True,text=True)
    assert 'y 1' in failed.stderr and 'passed' not in failed.stdout, 'baseline must reproduce Y mismatch'
    print(stem+': unadapted upstream reproduces y 1 assertion failure')
    path.write_text(fixture, encoding='utf-8', newline='\n')
    subprocess.run(['node',str(args.fengari.resolve()),str(path)], check=True)
    audits.append({'primitives':count,'positions_checked':len(expected),
                   'out_of_canvas_ellipses':sum(x<0 or y<0 or r>128 or b>128 for x,y,r,b in bounds),
                   'uncropped_bounds_xy_down':[round(min(b[i] for b in bounds),3) if i<2 else round(max(b[i] for b in bounds),3) for i in range(4)],
                   'first_relative_xy':data['elements'][0]['relative'],
                   'lua_bytes_after_coordinate_adapter':len(lua.encode('utf-8'))})
(out/'export-review.json').write_text(json.dumps(audits,indent=2)+'\n',encoding='utf-8')
print(json.dumps(audits,indent=2))
