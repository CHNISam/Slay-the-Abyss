import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preTask76OwnerSource,task76OwnerPaths} from './helpers/task76-owner-composition.mjs';
import {preBattleRefactorSource} from './helpers/battle-refactor-projection.mjs';
import {postApprovedCardDragClickSource} from './helpers/task76-drag-click-inverse.mjs';
const root='src/lua/abyss_battle_ui.lua';
const read=file=>readFileSync(file,'utf8').replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const layer=JSON.parse(read('tests/fixtures/task76-owner-composition.json'));
const frozen=JSON.parse(read('tests/fixtures/battle-ui-approved-responsibility-layer.json'));
const current=Object.fromEntries(task76OwnerPaths.map(file=>[file,read(file)]));

test('complete sixteen-owner inverse restores every frozen311 identity and exact315 approved monolith',()=>{
 assert.deepEqual(task76OwnerPaths,Object.keys(frozen.modules));
 assert.equal(layer.sourceHead,'e80fe3579cb657662ab110450ac30754216c773d');
 for(const path of task76OwnerPaths){
  assert.equal(layer.modules[path].beforeSha256,frozen.modules[path]);
  assert.equal(hash(current[path]),layer.modules[path].afterSha256);
  const before=preTask76OwnerSource(path,current[path]);
  assert.equal(hash(before),frozen.modules[path]);
  assert.equal(preTask76OwnerSource(path,before),before,'historical inverse is idempotent');
 }
 const original=preBattleRefactorSource(root,current[root]);
 assert.equal(hash(original),'a1d68a1fcba74fff54fb22cb4641cd400e4c76e2d3a7e22d69e352efeb8e7d91');
 assert.equal(hash(postApprovedCardDragClickSource(original)),'067b6761d5f02477ec2aeb848b2a00eb2b4191517d30096f7cb8dc84e3f0b382');
 const crlf=Object.fromEntries(Object.entries(current).map(([file,s])=>[file,s.replaceAll('\n','\r\n')]));
 assert.equal(preTask76OwnerSource(root,crlf[root],crlf),preTask76OwnerSource(root,current[root]));
});

test('whole-owner validation rejects drift and missing files across all sixteen before projection',()=>{
 for(const path of task76OwnerPaths){
  if(path===root){
   assert.throws(()=>preBattleRefactorSource(root,current[root]+'\n-- drift\n'),/unreviewed integrated/);
   const changed=task76OwnerPaths.find(file=>file!==root&&layer.modules[file].edits.length);
   assert.throws(()=>preTask76OwnerSource(changed,current[changed],{[root]:null}),/missing TASK-76/);
  }else{
   assert.throws(()=>preTask76OwnerSource(root,current[root],{[path]:current[path]+'\n-- drift\n'}),/unreviewed integrated/);
   assert.throws(()=>preTask76OwnerSource(root,current[root],{[path]:null}),/missing TASK-76/);
  }
 }
 assert.throws(()=>preTask76OwnerSource(root,current[root],{'src/lua/unknown.lua':'return {}'}),/unknown TASK-76/);
});

test('partial, missing and duplicate port hunks cannot satisfy the original complete source guards',()=>{
 for(const path of task76OwnerPaths){
  for(const edit of layer.modules[path].edits){
   assert.equal(current[path].split(edit.after).length,edit.count+1);
   for(const mutant of [current[path].replace(edit.after,edit.before),current[path].replace(edit.after,''),current[path].replace(edit.after,edit.after+edit.after)]){
    assert.notEqual(mutant,current[path]);
    if(path===root)assert.throws(()=>preBattleRefactorSource(root,mutant),/unreviewed integrated/);
    else assert.throws(()=>preTask76OwnerSource(root,current[root],{[path]:mutant}),/unreviewed integrated/);
   }
  }
 }
 assert.throws(()=>postApprovedCardDragClickSource(preBattleRefactorSource(root,current[root])+'\n-- drift\n'),/only the complete approved/);
});
