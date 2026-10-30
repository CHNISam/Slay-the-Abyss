import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
const root='art/monster-benchmarks/genshin-v1/';
const read=p=>readFileSync(new URL('../'+p,import.meta.url));
const json=p=>JSON.parse(read(p));
const hash=b=>createHash('sha256').update(b).digest('hex');
const expected={
 'pyro-abyss-mage':[null,'ef900cac2d1ae09874b07d9928d94259c258fb3f18686eb9150827df121aaa64'],
 'stonehide-lawachurl':['gremlin_leader','2dfbc8b20b37bc3f9cc2942fd967f9a730629fa35fbfbc257ccd20c990d8fe40'],
 'geovishap-hatchling':['jaw_worm','2dcf77d1f530847c964c98c5b591c91ca76b72af6c7e730e86aa5b7c482db1d6'],
 'dendro-slime':['acid_slime_m','f6ed0bc296c82912fb8720b7e2b8827b6e217f70ae1119d3138937c5f77442ba'],
};

test('exact four immutable Genshin direction benchmarks, never runtime approval or blanket mapping',()=>{
 const catalog=json(root+'catalog.json'),legal=json('docs/legal/assets.json');
 assert.deepEqual(Object.keys(catalog.benchmarks).sort(),Object.keys(expected).sort());
 assert.equal(catalog.all42MappingApproved,false);assert.equal(catalog.runtimeBinding,'none');
 for(const [slug,[id,sha]] of Object.entries(expected)){
  const base=root+slug+'/',asset=json(base+'asset.json'),owner=json(base+'owner-direction.json');
  assert.equal(catalog.benchmarks[slug],slug+'/asset.json');
  assert.equal(asset.directionEnemyId,id);assert.equal(asset.files['source.png'].sha256,sha);
  assert.deepEqual(asset.approvals,{ownerSourceDirection:true,native:false,runtime:false,device:false});
  assert.equal(asset.runtimeBinding,'none');assert.equal(owner.status,'owner-accepted-source-direction-only');
  assert.equal(owner.sourceSha256,sha);
  for(const gate of ['native','runtime','device'])assert.equal(owner[gate],false);
  assert.match(asset.performance,/unmeasured/);
  assert.deepEqual(readdirSync(new URL('../'+base,import.meta.url)).sort(),[...Object.keys(asset.files),'asset.json'].sort());
  for(const [name,file] of Object.entries(asset.files)){
   const raw=read(base+name),entry=legal.files[base+name];
   if(name==='source.png'&&raw.toString().startsWith('version https://git-lfs.github.com/spec/v1\n')){
    assert.equal(raw.toString(),`version https://git-lfs.github.com/spec/v1\noid sha256:${file.sha256}\nsize ${file.bytes}\n`);
    assert.equal(entry.lfsBytes,file.bytes);
   }else{
    const bytes=/\.(json|txt)$/.test(name)?Buffer.from(raw.toString().replaceAll('\r\n','\n')):raw;
    assert.equal(hash(bytes),file.sha256,base+name);assert.equal(bytes.length,file.bytes);
   }
   if(entry)assert.equal(entry.sha256,file.sha256);
   if(name.endsWith('.png')&&name!=='source.png')assert.deepEqual([raw.readUInt32BE(16),raw.readUInt32BE(20)],[Number(name.match(/(106|127)/)[1]),Number(name.match(/(106|127)/)[1])]);
  }
  const provenance=json(base+'generation-provenance.json');
  assert.equal(provenance.rawPreserved,true);assert.equal(provenance.sourceSha256,sha);
  assert.equal(provenance.exactPrompt,'prompt.txt');assert.ok(provenance.references.length);
  assert.match(provenance.rights,/NOT included/);
  for(const ref of provenance.references){assert.match(ref.pageUrl??ref.page_url,/^https:\/\/(wiki.hoyolab.com|www.hoyolab.com)\//);assert.match(ref.sha256,/^[a-f0-9]{64}$/);assert.equal(ref.path,undefined);}
  const attrs=read('.gitattributes').toString();assert.ok(attrs.split(/\r?\n/).includes(base+'source.png filter=lfs diff=lfs merge=lfs -text'));
  assert.doesNotMatch(JSON.stringify([asset,owner,provenance]),/\/workspace\/|\/home\/|Sentinel_|libfile_/);
 }
});

test('historical originals stay intact but identity direction is superseded, with anatomy correction',()=>{
 const old=json('art/monsters/catalog.json');
 assert.equal(old.identityDirection.status,'superseded-requires-redesign');
 assert.equal(Object.keys(old.candidates).length,41);assert.equal(old.approvals.owner,false);
 assert.match(json(root+'geovishap-hatchling/asset.json').anatomy,/Biped/);
 for(const slug of ['geovishap-hatchling','dendro-slime']){
  const historical=json(root+slug+'/historical-source-review.json');
  assert.equal(historical.owner_approved,false);assert.equal(historical.runtime_enabled,false);
  assert.equal(historical.status,'offline-source-candidate-awaiting-owner-review');
 }
});
