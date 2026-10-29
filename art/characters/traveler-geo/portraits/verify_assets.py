"""Integrity of the V2 developer handoff, not platform or visual acceptance."""
from pathlib import Path
from PIL import Image
import json,hashlib
ROOT=Path(__file__).resolve().parent
read=lambda p:json.loads(p.read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def verify():
 c=read(ROOT/'catalog.json');cap=read(ROOT/'capacity-experiment.json')
 assert c['runtimeStatus']=='unbound' and len(c['mapping'])==1
 assert c['mapping'][0]['characterId']=='traveler' and c['mapping'][0]['elementProfile']=='ironclad'
 assert not c['ui']['modified'] and not c['batch']['expand'] and c['batch']['count']==2
 assert c['batch']['nativeApproved']==0 and c['batch']['stableBatches']==0
 assert cap['B0']['status']==cap['B1']['status']=='not_run' and cap['B1']['onlyAsset']=='avatar96'
 assert not cap['productionEnabled'] and not cap['twentyMBGuarantee']
 for key,n,count,size in [('avatar96',96,4822,(1254,1254)),('battle133',133,4315,(1024,1536))]:
  p=ROOT/key;m=read(p/'asset.json');r=read(p/'export-report.json');v=read(p/'vm-report.json')
  for name,b in m['files'].items():
   f=p/name;assert f.is_file() and f.stat().st_size==b['bytes'] and sha(f)==b['sha256'],name
  assert Image.open(p/'source.png').size==size and Image.open(p/'source.png').mode=='RGBA'
  for f in ['preview-source-1x.png','preview-native-1x.png']:
   assert Image.open(p/f).size==(n,n)
  assert r['counts']['contentImages']==count and r['counts']['extraMasks']==0
  assert r['checks']['literalGeometryRGBAOrder'] and r['checks']['runtimeNoSnapshotExactCodeDataPrefix']
  assert v['contentImages']==count and v['geometryRGBAOrder']=='pass' and v['liveAfterOnDestroy']==0
  assert r['officialCompile']==r['officialImport']==r['nativeB0B1']=='not_run'
  assert m['approval']['nativeVisual']=='not approved' and 'FAILED' in m['previewStatus']['canonicalPng']
  raw=(p/'native-art.lua').read_bytes();runtime=(p/'runtime-no-snapshot.lua').read_bytes()
  assert raw.startswith(runtime) and runtime.endswith(b'\n') and not runtime.endswith(b'\n\n')
  assert b'local IMAGE_PREFAB_ID = 0' in runtime
  assert (p/'alpha-verification.json').is_file() and (p/'svg-preview-diagnostic.json').is_file()
 print('PORTRAIT_V2_HANDOFF_INTEGRITY_PASS; canonical PNG alpha diagnostics remain FAILED; no native approval')
if __name__=='__main__':verify()
