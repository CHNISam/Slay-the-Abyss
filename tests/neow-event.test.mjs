import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
test('Neow evidence binds the independent oracle and twelve pinned call-chain files',()=>{
 const source=JSON.parse(readFileSync('tests/fixtures/neow-source-contract.json','utf8'));
 assert.equal(source.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(source.sources.length,12);assert.equal(source.oracle.vectorCount,128);
 assert.equal(createHash('sha256').update(readFileSync(source.oracle.path)).digest('hex'),source.oracle.sha256);
 for(const file of source.sources){assert.match(file.gitBlobSha,/^[a-f0-9]{40}$/);assert.match(file.sha256,/^[a-f0-9]{64}$/);assert.ok(file.size>0);}
});
for(const [file,marker,count]of [['neow_offers.lua','NEOW_OFFERS',5],['neow_rewards.lua','NEOW_REWARDS',11]]){
 test(`Neow source offers and execution: ${file}`,()=>{
  const result=runLua(`tests/lua/${file}`);
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,new RegExp(`${marker} ${count} passed`));
 });
}
