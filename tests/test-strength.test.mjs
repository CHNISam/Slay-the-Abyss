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

test('mutation dispatcher selects the same explicit case for baseline and mutant',async()=>{
  const {readFileSync}=await import('node:fs');
  const {runMutation}=await import('../scripts/check-test-strength.mjs');
  const op=JSON.parse(readFileSync('config/critical-mutations.json','utf8'))[0];
  const calls=[];
  const result=runMutation({...op,caseName:'selected original regression'}, {
    runner:(script,cwd,options)=>{calls.push(options);return {status:0,stdout:'',stderr:''};}
  });
  assert.equal(result.status,'survived');
  assert.equal(calls.length,2);
  for(const options of calls){
    assert.equal(options.caseName,'selected original regression');
    assert(options.timeout<=15000,'retain the existing per-invocation budget');
  }
});

test('Lua runner explicitly supplies a selected case without changing ordinary invocations',async t=>{
  const {mkdtempSync,writeFileSync,rmSync}=await import('node:fs');
  const {tmpdir}=await import('node:os');
  const {join}=await import('node:path');
  const {runLua}=await import('../scripts/test-lua.mjs');
  const dir=mkdtempSync(join(tmpdir(),'abyss-case-selection-'));
  t.after(()=>rmSync(dir,{recursive:true,force:true}));
  const script=join(dir,'selection.lua');
  writeFileSync(script,`local selected=rawget(_G,'ABYSS_MUTATION_CASE')
local count=0
for _,name in ipairs({'first','second'}) do
 if selected==nil or selected==name then count=count+1;print('CASE '..name) end
end
assert(selected==nil or count==1,'unknown mutation case')
print('COUNT '..count)
`);
  const selected=runLua(script,{caseName:'second',timeout:15000});
  assert.equal(selected.status,0,selected.stderr);
  assert.match(selected.stdout,/COUNT 1/);
  assert.doesNotMatch(selected.stdout,/CASE first/);
  const ordinary=runLua(script,{timeout:15000});
  assert.equal(ordinary.status,0,ordinary.stderr);
  assert.match(ordinary.stdout,/COUNT 2/);
  const missing=runLua(script,{caseName:'missing',timeout:15000});
  assert.notEqual(missing.status,0,'unknown case must fail instead of running zero tests');
});

test('slow mutation baselines name their original regression cases',async()=>{
  const {readFileSync}=await import('node:fs');
  const operators=JSON.parse(readFileSync('config/critical-mutations.json','utf8'));
  assert.equal(operators.find(x=>x.id==='M3').caseName,
    'shop and camp views are detached even for nested offers, card instances and navigation');
  assert.equal(operators.find(x=>x.id==='M4').caseName,
    'potion finalization failure preserves complete state and original references');
});

test('registered Lua regressions reject a missing selected case',async()=>{
  const {runLua}=await import('../scripts/test-lua.mjs');
  for(const script of ['tests/lua/inventory.lua','tests/lua/node_transactions.lua']){
    const result=runLua(script,{caseName:'nonexistent mutation regression',timeout:15000});
    assert.notEqual(result.status,0,`${script} must reject zero executed cases`);
    assert.match(result.stderr,/unknown or duplicate .* mutation case/);
  }
});
