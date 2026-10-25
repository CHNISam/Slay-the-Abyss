import test from 'node:test';
import assert from 'node:assert/strict';

test('mutation classification requires registered assertion origin, not generic nonzero or product text',async()=>{
  const {classifyMutation}=await import('../scripts/check-test-strength.mjs');
  const proof={file:'tests/lua/check.lua',line:8,marker:'[ABYSS_ASSERT M4:atomic]'};
  assert.equal(classifyMutation({status:1,stderr:'tests/lua/check.lua:8: [ABYSS_ASSERT M4:atomic]',stdout:''},proof),'killed_by_assertion');
  assert.equal(classifyMutation({status:0,stderr:'',stdout:''},proof),'survived');
  assert.equal(classifyMutation({status:1,stderr:'src/lua/product.lua:8: assertion failed [ABYSS_ASSERT M4:atomic]',stdout:''},proof),'inconclusive');
  assert.equal(classifyMutation({status:null,error:{code:'ENOENT'}},proof),'infrastructure_error');
  assert.equal(classifyMutation({status:null,error:{code:'ETIMEDOUT'}},proof),'timeout');
});

test('dispatcher preserves distinct baseline, survivor, syntax and missing-tool outcomes',async()=>{
  const {readFileSync}=await import('node:fs');
  const {runMutation}=await import('../scripts/check-test-strength.mjs');
  const op=JSON.parse(readFileSync('config/critical-mutations.json','utf8'))[0];
  const pass=()=>({status:0,stdout:'fixture',stderr:''});
  assert.equal(runMutation({...op,after:op.before+'\n-- neutral fixture'},{runner:pass}).status,'survived');
  assert.equal(runMutation({...op,after:'local ='},{runner:pass}).status,'invalid_mutant');
  assert.equal(runMutation(op,{runner:()=>({status:1,stdout:'',stderr:'baseline failure'})}).status,'inconclusive');
  let calls=0;
  assert.equal(runMutation(op,{runner:()=>++calls===1?pass():{status:null,error:{code:'ENOENT'}}}).status,'infrastructure_error');
  calls=0;
  assert.equal(runMutation(op,{runner:()=>++calls===1?pass():{status:null,error:{code:'ETIMEDOUT'}}}).status,'timeout');
});
