import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=path=>JSON.parse(readFileSync(path,'utf8'));
const lock=read('tests/fixtures/guardian-sharp-hide-source.json');
test('Guardian Sharp Hide source chain is independently fixed without altering the original Rod lock',()=>{
 const rod=read('tests/fixtures/tungsten-rod-source.json');
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.zipSha256,rod.zipSha256);assert.equal(Object.keys(lock.files).length,11);
 const additional={
  'powers/SharpHidePower.java':'a7cf449a907ca34569059aca1310619deb597d32cdd84201815d024614ff576a',
  'actions/common/DamageAction.java':'c5649fc04cbcadffa617e5c52f1a6f879f88cb1a90a543d5a0a05ebf950578ec',
  'actions/AbstractGameAction.java':'cf0e5dbdfdf3f0c567c3527b839070718e19d836bb62364e8fa5f973b5ecdccb',
  'actions/GameActionManager.java':'a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3',
  'monsters/exordium/TheGuardian.java':'40571fa4c941d70c1814b0c0ff5cffa7d8933e24b49d95f2b531a3dc05598d56',
  'powers/IntangiblePlayerPower.java':'62ca9eecfd78e5b5a018ef069147d36bd58463b9754c8359d5dfb710bb6c52c8',
 };
 for(const [name,row]of Object.entries(lock.files)){
  assert.equal(row.member,`sts-${lock.sourceCommit}/${name}`);
  assert.equal(row.sha256,additional[name]??rod.files[name]?.sha256,name);
 }
 assert.deepEqual(lock.contracts,{sharpHideAmountA0:3,onUseCardType:'ATTACK',damageType:'THORNS',
  deadOwnerCancels:false,postCombatRetainedActionType:'DAMAGE',eventStatus:'sharp_hide',
  intangibleBeforeBlock:true,bufferBeforeRod:true,sameFourArgumentRetaliateStatus:'thorns'});
});
