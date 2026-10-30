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

// Exact co-located native candidate bytes accepted in the merged catalog.
const nativeCandidateHashes={
 "pyro-abyss-mage": {
  "PROVENANCE.json": "7f1570a1e508c33fd6624c662a49c8823ee9ab1058e2ebf3b4d691b610ca500a",
  "README.md": "479030540c0fd193c0dac2599658474dd2b0a971d54a426e3034f2ff825b03c0",
  "native-art.json": "f8611f996a048db8f7ebabffa749f5e5918ffac39f8fb8bc054d02e1fe444575",
  "native-art.lua": "3baeb774f291de1061e38512c527bd0419dbcec160cdc8972edac816826c7bee",
  "native-verification.json": "ffa087c6aeb5c16c0be5b5364620e7c9700044ec57cea5c9b5c577b6b7b29327"
 },
 "stonehide-lawachurl": {
  "PROVENANCE.json": "66c3e4b546a7108b81daa7e617366d5184b46cb8a16f9cfb31f4538b788d392d",
  "README.md": "d92cdd30db3fb886bd7c348c0e7024fe6ed254e703f971cd614abdd225bd4686",
  "native-art.json": "813a86d887020e3987eadda32081ec8ea6fa91e4594cd4028646162b603acdef",
  "native-art.lua": "e7146753d3290245947c86e35dff4bf3829cc67ebcc86a1c8d368df8bcedacb8",
  "native-verification.json": "697b1779a35e1cbcb367683337d36e1cbeede2c7b6d77217377ad255892ec9cb"
 },
 "geovishap-hatchling": {
  "PROVENANCE.json": "98bf5cd228257d589790605deb368104a2632932cc624e0ef7b90086ac91d32d",
  "README.md": "f8241ad910c2279295abccd59da230e4bfcb5489e5508dc69641babfaad07f58",
  "native-art.json": "69e184ebbfbc8f0273a3f3bdd76a1901bcf589c259476bd503eefe2b04de709f",
  "native-art.lua": "3c637fcf1750d0a6dcd7173cf94240e677008dbeb59f9e009b21289ae0730572",
  "native-verification.json": "64fdfd7911bc5fea319f7d471bbff646847de07466d8263e1ebe0debec7acdb8"
 }
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
  // Three reviewed native candidates were added alongside, not over, the
  // immutable direction witness. Enumerate exactly; never ignore arbitrary files.
  const nativeFiles=slug==='dendro-slime'?[]:['PROVENANCE.json','README.md','native-art.json','native-art.lua','native-verification.json'];
  assert.deepEqual(readdirSync(new URL('../'+base,import.meta.url)).sort(),[...Object.keys(asset.files),'asset.json',...nativeFiles].sort());
  if(nativeFiles.length){
   for(const name of nativeFiles){
    const raw=read(base+name);
    // Native payloads are -text; metadata follows Git's platform text endings.
    const bytes=name.startsWith('native-art.')?raw:Buffer.from(raw.toString().replaceAll('\r\n','\n'));
    assert.equal(hash(bytes),nativeCandidateHashes[slug][name],base+name);
   }
   const native=json(base+'PROVENANCE.json');
   assert.equal(native.identity,slug);assert.equal(native.source.sha256,sha);
   assert.equal(native.source.bytesUnmodified,true);assert.equal(native.nativeOwnerAcceptance,false);
   for(const name of ['native-art.json','native-art.lua']){
    const bytes=read(base+name);assert.equal(hash(bytes),native.native[name].sha256,base+name);
    assert.equal(bytes.length,native.native[name].bytes);
   }
  }
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
