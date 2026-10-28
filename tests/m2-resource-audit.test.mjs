import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
import { runLua } from '../scripts/test-lua.mjs';

let opening,nextRoom;
function audit() {
  if (opening) return opening;
  const result=runLua('tests/fixtures/js-owned/tests/lua/m2_resource_audit_rewards.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  const reports=result.stdout.split(/\r?\n/).filter(line=>line.startsWith('M2_EVIDENCE_JSON '))
    .map(line=>JSON.parse(line.slice('M2_EVIDENCE_JSON '.length)));
  assert.equal(reports.length,2,'opening and next-room audit reports');
  mkdirSync('build',{recursive:true});
  writeFileSync('build/m2-resource-audit-rewards.json',JSON.stringify(reports,null,2)+'\n');
  opening=reports[0].runs[0];nextRoom=reports[1].runs[0];
  return opening;
}

test('resource audit explicitly claims the first 15-gold offer once before leaving',()=>{
  const run=audit();
  const claim=run.rows.find(row=>row.action==='gold_reward');
  assert.ok(claim,'gold offer must be a recorded transaction');
  assert.equal(claim.before.gold,99);assert.equal(claim.before.rewards.gold,15);
  assert.equal(claim.before.rewards.goldClaimed,false);
  assert.equal(claim.after.gold,114);assert.equal(claim.after.rewards.goldClaimed,true);
  assert.ok(run.rejections.some(row=>row.action==='duplicate_gold_reward'));
  assert.equal(run.rows.find(row=>row.action==='leave_combat_rewards').after.gold,114);
});

test('resource audit observes parked reward identity and claimed state after Proceed',()=>{
  const leave=audit().rows.find(row=>row.action==='leave_combat_rewards');
  const pending=leave.after.pendingCombatRewards;
  assert.ok(pending,'parked rewards must be visible in snapshots');
  assert.ok(Number.isInteger(pending.identity));
  assert.equal(pending.rewardIdentity,leave.before.rewardIdentity);
  assert.equal(pending.combatIdentity,leave.before.combatIdentity);
  assert.equal(pending.flowIdentity,leave.before.flowIdentity);
  assert.equal(pending.rewards.goldClaimed,true);assert.equal(pending.rewards.cardResolved,true);
  assert.deepEqual(pending.rewards,leave.before.rewards);
  const final=audit().final.pendingCombatRewards;
  for(const key of ['identity','rewardIdentity','combatIdentity','flowIdentity'])assert.equal(final[key],pending[key]);
  assert.deepEqual(final.rewards,pending.rewards);
  assert.equal(pending.flow.complete,false,'earlier snapshot must stay detached');
  assert.equal(final.flow.complete,true,'room completion is a later observed change');
});

test('successful next-room entry records the parked reward disappearing rather than reviving',()=>{
  audit();const enter=nextRoom.rows.find(row=>row.action==='enter' && row.after.floor===2);
  assert.ok(enter.before.pendingCombatRewards,'the previous room has parked rewards before entry');
  assert.equal(enter.after.pendingCombatRewards,false,'successful entry must clear the parked owner');
  if(nextRoom.final.pendingCombatRewards) {
    assert.notEqual(nextRoom.final.pendingCombatRewards.identity,enter.before.pendingCombatRewards.identity);
    assert.notEqual(nextRoom.final.pendingCombatRewards.rewardIdentity,enter.before.pendingCombatRewards.rewardIdentity);
  }
});

test('new-run observation explicitly records that parked rewards and claims reset',()=>{
  const run=audit();assert.equal(run.resetVerified,true);
  assert.ok(run.final.pendingCombatRewards,'restart precondition has a parked reward');
  assert.equal(run.resetSnapshot.pendingCombatRewards,false);
  assert.equal(run.resetSnapshot.rewardIdentity,false);assert.equal(run.resetSnapshot.combatIdentity,false);
  assert.equal(run.resetSnapshot.gold,99);assert.equal(run.resetSnapshot.floor,1);
  assert.equal(run.resetSnapshot.phase,'map');assert.equal(run.resetSnapshot.victories,0);
});
