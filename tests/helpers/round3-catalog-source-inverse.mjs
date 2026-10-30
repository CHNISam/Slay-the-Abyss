// Exact outer replay of the reviewed catalog boundary. Historical bytes stay frozen.
import assert from 'node:assert/strict';
import {preRelicRound3CompositionSource} from './relic-round3-composition.mjs';
import {readFileSync,existsSync,rmSync,realpathSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/round3-catalog-source-inverse.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'f50e2544d9cefb702cc6dac3d7e64fd4d26bba43d5d0dd801c3e13b5e24ea1b6');
export const round3CatalogProof=JSON.parse(bytes);
assert.equal(round3CatalogProof.schemaVersion,1);
assert.equal(round3CatalogProof.baseCommit,'1bfca6261044b92f8065bb83668c358b0a2627da');
const added='src/lua/abyss_combat_catalog.lua';
assert.deepEqual(Object.keys(round3CatalogProof.files),['config/architecture.json','src/lua/abyss_combat.lua',added]);
for(const [path,binding]of Object.entries(round3CatalogProof.files)){
 assert.match(binding.afterSha256,/^[a-f0-9]{64}$/);
 assert.equal(binding.beforeSha256===null,path===added);
 assert.ok(Array.isArray(binding.hunks));
 if(path===added)assert.deepEqual(binding.hunks,[]);
 else assert.match(binding.beforeSha256,/^[a-f0-9]{64}$/);
}
export function preRound3CatalogSource(path,source,{readSource=path=>readFileSync(path,'utf8')}={}){
 source=preRelicRound3CompositionSource(path,source,'round3');
 const binding=round3CatalogProof.files[path];
 if(!binding||typeof source!=='string')return source;
 const normalized=normalize(source);
 // Partial, duplicate and unreviewed edits retain their bytes for strict guards.
 if(hash(normalized)!==binding.afterSha256)return source;
 let linked;
 try{linked=readSource(added);}catch{assert.fail('catalog linked module missing: '+added);}
 assert.equal(typeof linked,'string','catalog linked module must exist');
 assert.equal(hash(normalize(linked)),round3CatalogProof.files[added].afterSha256,'catalog linked module identity');
 if(path===added)return null;
 const lines=normalized.split('\n');
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact catalog inverse hunk: '+path);
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const previous=lines.join('\n');
 assert.equal(hash(previous),binding.beforeSha256,'complete pre-catalog source identity: '+path);
 return previous;
}
// Only the established historical materializer calls this deferred cleanup.
export function prepareRound3CatalogModuleRetirement(directory,{sourceRoot=process.cwd()}={}){
 assert.notEqual(resolve(directory),resolve(sourceRoot),'catalog retirement requires a separate historical destination');
 const target=join(directory,added);
 if(!existsSync(target))return ()=>{};
 const realTarget=realpathSync(target),liveModule=join(sourceRoot,added);
 assert.notEqual(realTarget,realpathSync(liveModule),'catalog retirement requires a separate historical module');
 assert.equal(hash(normalize(readFileSync(target,'utf8'))),round3CatalogProof.files[added].afterSha256,
  'unreviewed catalog module destination');
 return ()=>{
  assert.equal(realpathSync(target),realTarget,'catalog module destination changed after preparation');
  assert.notEqual(realTarget,realpathSync(liveModule),'catalog retirement requires a separate historical module');
  assert.equal(hash(normalize(readFileSync(target,'utf8'))),round3CatalogProof.files[added].afterSha256,
   'unreviewed catalog module destination');
  rmSync(target);
 };
}
