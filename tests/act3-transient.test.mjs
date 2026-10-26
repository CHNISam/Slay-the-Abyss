import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
test('Transient preserves its public source entry and audited actions',()=>{
 const result=runLua('tests/lua/act3_transient.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/ACT3_TRANSIENT 19 groups; 0 failed/);
});
test('Transient fixed source and independent arithmetic vectors stay explicit',()=>{
 const lock=JSON.parse(readFileSync('tests/fixtures/act3-transient-source-lock.json','utf8'));
 const hash=path=>createHash('sha256').update(readFileSync(path,'utf8').replace(/\r\n/g,'\n')).digest('hex');
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(new Set(lock.files.map(file=>file.path)).size,21);
 assert.equal(hash(lock.independentModel.generator),lock.independentModel.generatorSha256LF);
 assert.equal(hash(lock.independentModel.fixture),lock.independentModel.sha256LF);
 assert.deepEqual(lock.contracts.attacks,[30,40,50,60,70]);
 assert.equal(lock.contracts.hpDraws,0);assert.equal(lock.contracts.laterAiDraws,0);
});
