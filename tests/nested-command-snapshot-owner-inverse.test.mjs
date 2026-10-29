import {projectEventSnapshotSource} from './helpers/event-snapshot-composition.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {nestedSnapshotOwnerProof as proof,preNestedSnapshotOwnerSource as prior} from './helpers/nested-command-snapshot-owner-inverse.mjs';
import {requirePr323Source,preAcceptedPr323Source,preOriginalPr323Source} from './helpers/pr323-accepted-source-inverse.mjs';
const hash=source=>createHash('sha256').update(source).digest('hex');
const read=path=>projectEventSnapshotSource(path,readFileSync(path,'utf8'),'snapshot').replaceAll('\r\n','\n');
test('only the complete two-file owner delta recovers accepted full runtime identities',()=>{
 assert.deepEqual(Object.keys(proof.files),['src/lua/abyss_combat.lua','src/lua/abyss_run.lua']);
 for(const [path,binding]of Object.entries(proof.files)){
  const current=read(path),original=prior(path,current);
  assert.equal(hash(current),binding.afterSha256);
  assert.equal(hash(original),binding.beforeSha256);
  assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(original)+'\0').update(original).digest('hex'),binding.beforeGitBlob);
  assert.equal(prior(path,original),original);
  assert.equal(prior(path,current.replaceAll('\n','\r\n')),original);
 }
 requirePr323Source('src/lua/abyss_combat.lua',read('src/lua/abyss_combat.lua'));
 assert.equal(hash(read('tests/lua/silent_natural_build.lua')),'979708a7554d9d6467c34646e089f70dccdaee648f09893366ac5b7eccecf3e5');
});
test('partial changes, added drift and wrong paths never acquire historical composition permission',()=>{
 for(const [path,binding]of Object.entries(proof.files)){
  const current=read(path);
  for(const changed of [current+'\n-- unrelated drift\n',current.slice(1),...binding.changes.map(change=>current.replace(change.after,change.before))]){
   assert.notEqual(changed,current);
   assert.equal(prior(path,changed),changed);
   if(path==='src/lua/abyss_combat.lua')assert.throws(()=>requirePr323Source(path,changed),/unreviewed integrated/);
  }
  assert.equal(prior('unregistered.lua',current),current);
  assert.equal(prior(path,null),null);
 }
 const path='src/lua/abyss_combat.lua',current=read(path);
 for(const text of ['snapshot.ownedRestore(rollbackOwner,state)','snapshot.release(owner)','run.combat,owner']){
  const sourcePath=text==='snapshot.ownedRestore(rollbackOwner,state)'?path:'src/lua/abyss_run.lua';
  const source=read(sourcePath);assert.ok(source.includes(text));
  const changed=source.replace(text,'nil');assert.equal(prior(sourcePath,changed),changed);
 }
 assert.equal(prior('src/lua/abyss_run.lua',current),current,'cross-file runtime cannot project');
 const run=read('src/lua/abyss_run.lua');
 for(const project of [preAcceptedPr323Source,preOriginalPr323Source])
  assert.equal(project('src/lua/abyss_run.lua',run),run,'PR323 keeps unregistered Run source visible');
});
