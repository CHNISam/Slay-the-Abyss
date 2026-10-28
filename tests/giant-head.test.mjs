import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {runLua} from '../scripts/test-lua.mjs';

for(const [fixture,marker] of [['giant_head_ai','GIANT_HEAD_AI 7'],['giant_head_slow','GIANT_HEAD_SLOW 24']]) {
 test(`${fixture}: fixed-source actions, power timing and transactions`,()=>{
  const result=runLua(`tests/fixtures/js-owned/tests/lua/${fixture}.lua`);
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.ok(result.stdout.includes(`${marker} groups; 0 failed`),result.stdout);
 });
}
test('Giant Head source identity and independently regenerated numeric vectors stay locked',()=>{
 const lock=JSON.parse(readFileSync('tests/fixtures/giant-head-source-lock.json','utf8'));
 const canonical=path=>readFileSync(path,'utf8').replace(/\r\n/g,'\n');
 const hash=path=>createHash('sha256').update(canonical(path)).digest('hex');
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.files.length,18);assert.equal(new Set(lock.files.map(file=>file.path)).size,18);
 for(const file of lock.files) {
  assert.match(file.gitBlob,/^[a-f0-9]{40}$/);assert.match(file.sha256,/^[a-f0-9]{64}$/);
  assert.ok(file.bytes>0);assert.ok(file.url.includes(`/${lock.sourceCommit}/${file.path}`));
 }
 assert.equal(lock.contracts.slowHook,'onAfterUseCard');
 assert.equal(lock.contracts.slowEnqueue,'BOTTOM ApplyPowerAction');
 assert.equal(lock.contracts.slowDamageType,'NORMAL');
 assert.equal(lock.contracts.openingActions,4);assert.equal(lock.contracts.hpDraws,1);
 assert.deepEqual(lock.contracts.ramp,[30,35,40,45,50,55,60]);
 assert.equal(hash(lock.independentModel.generator),lock.independentModel.generatorSha256LF);
 assert.equal(hash(lock.independentModel.fixture),lock.independentModel.sha256LF);
 for(const dependency of lock.independentModel.dependencies) assert.equal(hash(dependency.path),dependency.sha256LF);
 const generated=spawnSync('python',[lock.independentModel.generator,'--lua'],{encoding:'utf8',timeout:5000});
 assert.equal(generated.status,0,generated.stderr);
 assert.equal(generated.stdout.replace(/\r\n/g,'\n'),canonical(lock.independentModel.fixture));
});
