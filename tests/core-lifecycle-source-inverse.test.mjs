import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,mkdirSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
import {preDeckDeliverySource} from './helpers/deck-delivery-source-composition.mjs';
import * as core from './helpers/core-lifecycle-source-inverse.mjs';
import {preRelicQuerySource} from './helpers/relic-query-source-inverse.mjs';
const prior=core.preCoreLifecycleSource,proof=core.coreLifecycleSourceProof;
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(normalize(s)).digest('hex');
const actor='src/lua/abyss_actor.lua',combat='src/lua/abyss_combat.lua';
const leaf='src/lua/abyss_actor_power_rules.lua',config='config/architecture.json';
const paths=[actor,combat,config],owners=[actor,combat,leaf,config];
const oldHashes={
 [actor]:'3ca585adaf351ef9fde31575e121c69186d2f2dfdd451a8ca32bf4ba0855ac94',
 [combat]:'6929906a274bc84dd2914083ae3d0019ef7ad5d89659f357ff979a89ee9e7805',
 [config]:'fcaff296e24d74abe704b4d3e7c420f6492986ec2ffe9e440cfe5b6b65768380',
};
// This existing contract owns the complete pre-query epoch; the new eight-owner
// source test separately authenticates all current production files.
const read=p=>preRelicQuerySource(p,normalize(readFileSync(p,'utf8')));
function before(p){
 if(p===actor)return read('tests/helpers/actor-lifecycle-before.lua');
 if(p===combat)return normalize(gunzipSync(Buffer.from(JSON.parse(read('tests/helpers/combat-lifecycle-before.json')).gzipBase64,'base64')).toString('utf8'));
 if(p===config)return prior(config,read(config));
}
const fourOwners=()=>assert.deepEqual(Object.keys(proof.files),owners,'the retired two-owner epoch cannot authorize the final four-owner extraction');
const publicPrior=(path,source,options)=>preDeckDeliverySource(path,source,'delivery',options);

test('only the complete final four-owner epoch restores frozen Actor/Combat and exact dedb architecture through the public boundary',()=>{
 fourOwners();
 for(const path of paths){
  const source=read(path),old=before(path);
  assert.equal(hash(old),oldHashes[path],'independently locked complete original: '+path);
  assert.ok(source!==old,'new epoch must differ from its frozen original');
  assert.equal(hash(source),proof.files[path].afterSha256);
  assert.equal(hash(prior(path,source)),oldHashes[path]);
  assert.equal(prior(path,source.replaceAll('\n','\r\n')),old);
  assert.equal(publicPrior(path,source),publicPrior(path,old),'the existing chain still traverses all older exact proofs');
 }
 const oldConfig=before(config);
 for(const source of [JSON.stringify(JSON.parse(read(config))),JSON.stringify(JSON.parse(read(config)),null,'\t'),read(config)+'\n\t '])
  assert.equal(prior(config,source),oldConfig,'only the established layout permission crosses the outer epoch');
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(oldConfig)+'\0').update(oldConfig).digest('hex'),'5c769902739efb7cad09df444bb2421ea5ed46cf');
 assert.equal(Object.hasOwn(proof.files[leaf],'beforeSource'),false,'a new witness has no invented historical source');
 assert.equal(Object.hasOwn(proof.files[leaf],'beforeSha256'),false);
 assert.equal(prior(leaf,read(leaf),{readSource(){assert.fail('witness-only input must not read linked owners');}}),read(leaf));
});

test('the outer inverse rejects unknown and old epochs without linked reads and never grants the retired two-owner Actor epoch permission',()=>{
 fourOwners();let reads=0;const options={readSource(){reads++;throw Error('must not read');}};
 for(const consume of [prior,publicPrior])for(const path of paths){
  const source=read(path),lines=source.split('\n');[lines[0],lines[1]]=[lines[1],lines[0]];
  const inputs=[null,false,12,{},'',source+(path===config?'\n-- foreign\n':'\n'),source.slice(1),source+source,lines.join('\n')];
  if(path===config)inputs.push(source.replace('"abyss_actor_power_rules":','"abyss_actor_power_rules": "core", "abyss_actor_power_rules":'),source.replace('"abyss_actor_power_rules"','"abyss_actor_power_rul\\u0065s"'));
  // Old config remains registered with older GameUI guards. Its zero-I/O
  // rejection belongs to this outer boundary; keep the older guards intact.
  if(consume===prior||path!==config)inputs.push(before(path));
  for(const input of inputs)assert.equal(consume(path,input,options),input);
  assert.equal(consume('foreign/'+path,source,options),source);
  const foreign=read(paths.find(p=>p!==path));assert.equal(consume(path,foreign,options),foreign);
 }
 assert.equal(reads,0);
 assert.notEqual(proof.files[actor].afterSha256,'ebadd46190effb52d67a8cb0802f269204bc35f081bd8f8e4792510bf3796092');
});

test('every recognized direct or public call freshly validates all four owners and nested readers retain the raw source closure',()=>{
 fourOwners();assert.equal(typeof core.coreLifecycleReader,'function');
 const old=Object.fromEntries(paths.map(path=>[path,before(path)]));
 for(const consume of [prior,publicPrior])for(const host of paths)for(const linked of owners){
  const source=read(host),expected=consume(host,source);let mode='good',reads=[];
  const readSource=p=>{reads.push(p);if(p===linked){if(mode==='throw')throw Error('reader failed');if(mode==='missing')return undefined;if(mode==='drift')return read(p)+'\n';if(mode==='old')return old[p];}return read(p);};
  assert.equal(consume(host,source,{readSource}),expected);assert.deepEqual(reads.slice(0,4),owners);
  for(mode of ['throw','missing','drift','old']){
   reads=[];assert.throws(()=>consume(host,source,{readSource}),/lifecycle linked/);
   assert.ok(reads.includes(linked),'a warm result cannot bypass the supplied fresh reader');
  }
  mode='good';reads=[];assert.equal(consume(host,source,{readSource}),expected);assert.deepEqual(reads.slice(0,4),owners);
  const nested=core.coreLifecycleReader(core.coreLifecycleReader(readSource));
  assert.equal(prior(host,source,{readSource:nested}),old[host]);
  mode='drift';assert.throws(()=>prior(host,source,{readSource:nested}),/lifecycle linked/);
 }
 assert.throws(()=>prior(actor,read(actor),{readSource:null}),/linked reader/);
});

test('default linked reads follow the isolated four-owner filesystem and reject warm edits and deletions',()=>{
 fourOwners();
 const original=Object.fromEntries(owners.map(path=>[path,read(path)]));
 const expected=Object.fromEntries(paths.map(path=>[path,before(path)]));
 const cwd=process.cwd(),directory=mkdtempSync(join(tmpdir(),'core-lifecycle-source-'));
 try{
  for(const path of owners){const target=join(directory,path);mkdirSync(dirname(target),{recursive:true});writeFileSync(target,original[path]);}
  process.chdir(directory);
  for(const host of paths)for(const linked of owners){
   assert.equal(prior(host,original[host]),expected[host]);
   writeFileSync(linked,original[linked]+'\n');assert.throws(()=>prior(host,original[host]),/lifecycle linked/);
   writeFileSync(linked,original[linked]);assert.equal(prior(host,original[host]),expected[host]);
   rmSync(linked);assert.throws(()=>prior(host,original[host]),/lifecycle linked/);
   writeFileSync(linked,original[linked]);assert.equal(prior(host,original[host]),expected[host]);
  }
 }finally{process.chdir(cwd);rmSync(directory,{recursive:true,force:true});}
});
