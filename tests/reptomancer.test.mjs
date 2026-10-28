import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
for (const [path,marker] of [['reptomancer','REPTOMANCER 18 groups; 0 failed'],
 ['reptomancer_public','REPTOMANCER_PUBLIC'],['reptomancer_ui','REPTOMANCER_UI'],
 ['reptomancer_run_reward_rollback','REPTOMANCER_RUN_REWARD_ROLLBACK']]) {
 test(`source Reptomancer ${path} retains independent behavior and transactions`,()=>{
  const result=runLua(`tests/fixtures/js-owned/tests/lua/${path}.lua`);
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.ok(result.stdout.includes(marker),result.stdout);
 });
}
test('Reptomancer fixed-source and independent model identities are explicit',()=>{
 const lock=JSON.parse(readFileSync('tests/fixtures/reptomancer-source-lock.json','utf8'));
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 for(const [path,hash] of Object.entries(lock.independentModel.files)){
  assert.equal(createHash('sha256').update(readFileSync(path,'utf8').replace(/\r\n/g,'\n')).digest('hex'),hash,path);
 }
 assert.equal(new Set(lock.files.map(file=>file.path)).size,lock.files.length);
 assert.equal(lock.contracts.daggersPerSummon,1);
 assert.equal(lock.contracts.maxLivingDaggers,4);
});
