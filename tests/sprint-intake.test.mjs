import test from 'node:test';
import assert from 'node:assert/strict';
import {evaluateIntake,localToday} from '../scripts/check-task-intake.mjs';
const policy={sprint:{id:'2026-11-03',start:'2026-11-03',end:'2026-11-09',primaryMilestone:'m-7'},
  milestoneOrder:['m-7','m-8','m-9'],parallelTaskIds:['TASK-4.18'],blockedUntilOwnerApproval:['TASK-85','TASK-96']};
const check=(id,milestone,status='To Do',today='2026-11-03')=>evaluateIntake({id,task:{id,milestone,status},policy,today});
test('engineering task is eligible when genuinely unclaimed',()=>assert.equal(check('TASK-74','m-7').decision,'ALLOW'));
test('TASK-85/96 never auto-claim in current sprint',()=>{for(const id of ['TASK-85','TASK-96'])assert.equal(check(id,'m-8').decision,'HOLD')});
test('all other M8 and M9 default to hold',()=>{assert.equal(check('TASK-25','m-8').decision,'HOLD');assert.equal(check('TASK-97','m-9').decision,'HOLD')});
test('explicit parallel M8 fix may start but not duplicate',()=>{assert.equal(check('TASK-4.18','m-8').decision,'ALLOW');assert.equal(check('TASK-4.18','m-8','In Progress').decision,'HOLD')});
test('in-progress engineering never duplicates',()=>assert.equal(check('TASK-74','m-7','In Progress').decision,'HOLD'));
test('calendar expiry does not move the phase automatically',()=>{assert.equal(check('TASK-74','m-7','To Do','2026-11-10').decision,'HOLD');assert.equal(check('TASK-97','m-9','To Do','2026-11-10').decision,'HOLD')});
test('unknown task and invalid identity remain blocked',()=>{assert.equal(evaluateIntake({id:'TASK-74',task:null,policy,today:'2026-11-03'}).decision,'HOLD');assert.equal(check('TASK-xyz','m-7').decision,'HOLD')});
test('Beijing date is YYYY-MM-DD in canonical order',()=>assert.equal(localToday('Asia/Shanghai',new Date('2026-11-03T00:00:00Z')),'2026-11-03'));

const attempt=patch=>evaluateIntake({id:'TASK-74',task:{id:'TASK-74',milestone:'m-7',status:'To Do'},policy:{...policy,...patch},today:'2026-11-03'});
test('missing and malformed date windows fail closed',()=>{
  for(const date of [undefined,null,'','2026-2-03','2026-02-30','garbage',20261103]) {
    for(const key of ['start','end']) assert.equal(attempt({sprint:{...policy.sprint,[key]:date}}).decision,'HOLD',key+': '+date);
  }
  assert.equal(attempt({sprint:{...policy.sprint,start:'2026-11-10',end:'2026-11-01'}}).decision,'HOLD');
});
test('invalid policy shapes return HOLD without throwing',()=>{
  for(const candidate of [null,{}, {sprint:{}}, {...policy,milestoneOrder:[]}, {...policy,milestoneOrder:['m-9','m-8','m-7']}, {...policy,sprint:{...policy.sprint,primaryMilestone:'m-42'}}, {...policy,parallelTaskIds:'TASK-74'}, {...policy,blockedUntilOwnerApproval:'TASK-85'}]) {
    assert.equal(evaluateIntake({id:'TASK-74',task:{id:'TASK-74',milestone:'m-7',status:'To Do'},policy:candidate,today:'2026-11-03'}).decision,'HOLD');
  }
});
test('invalid current date cannot bypass a valid window',()=>{
  for(const today of ['','2026-11-3','2026-02-30']) assert.equal(check('TASK-74','m-7','To Do',today).decision,'HOLD');
});

test('historical M5 experience work is reachable only after explicit M8 refresh',()=>{
  const historical={...policy,historicalM8TaskIds:['TASK-4.9','TASK-4.10']};
  const evaluate=(id,status='To Do',milestone='m-5',p=historical)=>evaluateIntake({id,task:{id,milestone,status},policy:p,today:'2026-11-03'});
  assert.equal(evaluate('TASK-4.9').decision,'HOLD');
  const next={...historical,sprint:{...policy.sprint,primaryMilestone:'m-8'}};
  assert.equal(evaluate('TASK-4.9','To Do','m-5',next).decision,'ALLOW');
  assert.equal(evaluate('TASK-4.10','In Progress','m-5',next).decision,'HOLD');
  assert.equal(evaluate('TASK-999','To Do','m-5',next).decision,'HOLD');
  assert.equal(evaluate('TASK-4.9','To Do','m-6',next).decision,'HOLD');
  assert.equal(attempt({historicalM8TaskIds:'TASK-74'}).decision,'HOLD');
});

test('missing explicit approval policy cannot silently unlock guarded work',()=>{
  const {blockedUntilOwnerApproval,...incomplete}=policy;
  const result=evaluateIntake({id:'TASK-85',task:{id:'TASK-85',milestone:'m-8',status:'To Do'},policy:{...incomplete,sprint:{...policy.sprint,primaryMilestone:'m-8'}},today:'2026-11-03'});
  assert.equal(result.decision,'HOLD');
});
