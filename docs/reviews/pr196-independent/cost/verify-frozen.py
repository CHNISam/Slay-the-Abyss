import hashlib,json,re
from pathlib import Path
root=Path(__file__).resolve().parent; head=root/'head'; candidate=root/'candidate'
rows=json.loads((root/'ui-tree.json').read_text())+json.loads((root/'runtime-verified.json').read_text())+json.loads((root/'selected-tree.json').read_text())['tree']
meta={r['path']:r for r in rows}
required={r['path'] for r in rows if r['path'].startswith('src/lua/') or r['path'].startswith('data/presentation/')}
required|={r['path'] for r in json.loads((root/'runtime-verified.json').read_text())}
required|={'tools/render_traveler_cards.py','tests/lua/support/game_ui_fixture.lua','tests/lua/warrior75_choice_ui.lua','tests/lua/warrior75_edges.lua'}
seen=set()
def imports(path):
 if path in seen:return
 seen.add(path);required.add(path)
 for name in re.findall(r"from ['\"](\.[^'\"]+)['\"]",(head/path).read_text()):
  imports(str((Path(path).parent/name)).replace('scripts/./','scripts/'))
imports('scripts/build-ui.mjs');imports('scripts/build-lua-data.mjs')
verified=[]
for path in sorted(required):
 b=(head/path).read_bytes();h=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest();assert h==meta[path]['sha'],path
 verified.append({'path':path,'gitBlob':h,'sha256':hashlib.sha256(b).hexdigest()})
(root/'verified-source.json').write_text(json.dumps({'head':'529c8af1c2fd0bc6d501260824b04eb6f18821ee','files':verified},indent=2)+'\n')
changes=[path for path in sorted(required) if (candidate/path).read_bytes()!=(head/path).read_bytes()]
assert changes==['src/lua/abyss_card_actions.lua'],changes
facts=json.loads((head/'docs/evidence/warrior75/sources.json').read_text())
refs=[]
for p in sorted((root/'reference').rglob('*.java')):
 b=p.read_bytes();h=hashlib.sha256(b).hexdigest();rel=p.relative_to(root/'reference').as_posix();original=next((s for s in facts['sources'] if s['path']==rel),None)
 if original and 'sha256' in original:assert h==original['sha256'],rel
 refs.append({'path':rel,'sha256':h,'gitBlob':hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest(),'matchesRepositorySourceManifest':bool(original and 'sha256' in original)})
(root/'reference/provenance.json').write_text(json.dumps({'sourceCommit':facts['commit'],'evidenceClass':facts['evidenceClass'],'originalGameObserved':False,'files':refs,'abstractCard':'Downloaded exact fc379c8 source matched copied local bytes in six bounded chunks; sources.json originally had 403 instead of a hash.'},indent=2)+'\n')
print('Verified',len(verified),'frozen source files; candidate changes exactly:',changes)
