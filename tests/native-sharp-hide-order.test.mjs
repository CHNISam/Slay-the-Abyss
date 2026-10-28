import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runLua} from '../scripts/test-lua.mjs';
test('native Sharp Hide ordering keeps a separate fixed raw-source lock',()=>{
 const read=path=>JSON.parse(readFileSync(path,'utf8'));
 const lock=read('tests/fixtures/native-sharp-hide-order-source.json');
 const guardian=read('tests/fixtures/guardian-sharp-hide-source.json');
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.zipSha256,'3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458');
 const extra={
  'relics/CentennialPuzzle.java':'b1069310819ff2fdd812467a1d0f461d9d40cea376e244268dfdc270217dd56e',
  'actions/utility/UseCardAction.java':'90213939af6d7ec83dea01bb2feef4ba762a93400dc1535732e2eebcdb6cab0f',
  'actions/common/DrawCardAction.java':'67d02ba84c1d7e60fbb2a4a83f2b2d3ebbd81a84d29c16ccb98ecc9dd1a17e18',
  'cards/CardGroup.java':'03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8',
  'actions/common/EmptyDeckShuffleAction.java':'b4fc6be1df7caa1906705469500c40e81135a41614b54448346ddb0fec0bb2b2',
  'cards/red/SearingBlow.java':'93aed26c36c2bdfdac23b3d38da135332dcaefe8b43f66461bdbb69b85a1765b',
 };
 assert.equal(Object.keys(lock.files).length,10);
 for(const [name,row]of Object.entries(lock.files)){
  assert.equal(row.member,`sts-${lock.sourceCommit}/${name}`);
  assert.equal(row.sha256,extra[name]??guardian.files[name]?.sha256,name);
 }
 assert.deepEqual(lock.contracts,{onUseCardType:'ATTACK',damageType:'THORNS',sharpHideAmountA0:3,
  puzzleTopDraw:3,deadOwnerCancels:false,postCombatRetainedActionType:'DAMAGE',
  nativeCardDisposedAfterHpTriggeredTopDraw:true,emptyDrawAndDiscardCanDrawLimboCard:false});
});
test('native Sharp Hide HP-triggered TOP draw precedes physical card disposal',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/native_sharp_hide_top_draw.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/NATIVE_SHARP_HIDE_TOP_DRAW_PASS/);
});
test('native Sharp Hide preserves source death, metadata and public rollback boundaries',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/native_sharp_hide_queue_boundaries.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/NATIVE_SHARP_HIDE_QUEUE_BOUNDARIES 6 groups; 0 failed/);
});
