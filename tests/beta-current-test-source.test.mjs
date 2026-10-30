import {preFixtureConstructionSource} from './helpers/fixture-construction-source.mjs';
import {preFinalUiSource} from './helpers/final-ui-source.mjs';
import {preP0UiSource} from './helpers/p0-ui-source.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,copyFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {betaCurrentTestProof,preBetaCurrentTestSource} from './helpers/beta-current-test-source.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
test('all 33 reviewed current fixtures recover complete develop98 bytes bidirectionally without editing live tests',()=>{
 assert.equal(Object.keys(betaCurrentTestProof.files).length,33);
 for(const [path,b]of Object.entries(betaCurrentTestProof.files)){
  const raw=readFileSync(path,'utf8').replaceAll('\r\n','\n');
  const live=preP0UiSource(path,preFinalUiSource(path,preFixtureConstructionSource(path,raw)));
  assert.equal(hash(live),b.afterSha256,path);assert.equal(blob(live),b.afterGitBlob,path);
  const prior=preBetaCurrentTestSource(path,live);
  assert.equal(hash(prior),b.beforeSha256,path);assert.equal(blob(prior),b.beforeGitBlob,path);
  assert.equal(preBetaCurrentTestSource(path,live.replaceAll('\n','\r\n')),prior);
  assert.equal(preBetaCurrentTestSource(path,prior),prior,'old witness stays untouched');
  assert.equal(readFileSync(path,'utf8').replaceAll('\r\n','\n'),raw,'current test bytes remain current');
 }
});
test('missing, unknown, partial, appended, same-length and cross-path inputs cannot borrow a fixture projection',()=>{
 const paths=Object.keys(betaCurrentTestProof.files);
 for(const [i,path]of paths.entries()){
  const live=preP0UiSource(path,preFinalUiSource(path,preFixtureConstructionSource(path,readFileSync(path,'utf8').replaceAll('\r\n','\n')))),b=betaCurrentTestProof.files[path];
  const h=b.hunks.find(h=>h.after.length);const lines=live.split('\n');
  if(h)lines.splice(h.at,h.after.length);else lines.push('unknown');
  for(const bad of [null,undefined,'',live.slice(1),live+'\n', (live[0]==='!'?'?':'!')+live.slice(1),lines.join('\n')]){
   assert.notEqual(bad,live);assert.equal(preBetaCurrentTestSource(path,bad),bad,path);
  }
  for(const badPath of [paths[(i+1)%paths.length],'src/lua/abyss_battle_ui.lua','tests/lua/../'+path,'unregistered.lua'])assert.equal(preBetaCurrentTestSource(badPath,live),live,'path-bound full identities only');
 }
});
test('fixture proof is immutable and excludes independently owned current-entry and feedback inverses',()=>{
 assert(Object.isFrozen(betaCurrentTestProof.files));
 for(const path of ['tests/lua/game_ui.lua','tests/lua/support/current_entry_fixture.lua','tests/lua/support/native_monster_engine.lua','tests/lua/feedback_continuous_cards.lua'])assert.equal(betaCurrentTestProof.files[path],undefined);
 for(const row of Object.values(betaCurrentTestProof.files)){assert(Object.isFrozen(row.hunks));assert(row.archives.length>0);}
});

test('CRLF archive spelling retains canonical identity and changed archive bytes are rejected',async()=>{
 const directory=mkdtempSync(join(tmpdir(),'beta-test-proof-crlf-'));
 try{
  mkdirSync(join(directory,'helpers'));mkdirSync(join(directory,'fixtures'));
  for(const file of ['beta-current-test-source.mjs','pure-source-projection-cache.mjs','fixture-construction-source.mjs','fixture-grid-source.mjs'])copyFileSync(new URL('./helpers/'+file,import.meta.url),join(directory,'helpers',file));
  for(const file of ['fixture-construction-source.json','fixture-grid-source.json'])copyFileSync(new URL('./fixtures/'+file,import.meta.url),join(directory,'fixtures',file));
  const archive=readFileSync(new URL('./fixtures/beta-current-test-source.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
  const target=join(directory,'fixtures/beta-current-test-source.json');writeFileSync(target,archive.replaceAll('\n','\r\n'));
  const moduleUrl=pathToFileURL(join(directory,'helpers/beta-current-test-source.mjs')).href;
  const loaded=await import(moduleUrl+'?valid');assert.deepEqual(loaded.betaCurrentTestProof,betaCurrentTestProof);
  writeFileSync(target,archive.replace('98fef95d','08fef95d').replaceAll('\n','\r\n'));
  await assert.rejects(import(moduleUrl+'?changed'),/complete reviewed current-test migration archive/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
