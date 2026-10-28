import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';

test('Darklings source formation AI linked deaths rebirth and public Run preserve existing queues',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/darklings.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/DARKLINGS 31 groups; 0 failed/);
});
test('real five-slot controls retain Chinese Regrow and Reincarnate without target leaks or immortal death feedback',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/darklings_ui.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/DARKLINGS_UI_PASS/);
});
test('Darklings pinned source and independent arithmetic vector identities stay locked',()=>{
 const lock=JSON.parse(readFileSync('tests/fixtures/darklings-source-lock.json','utf8'));
 const hash=path=>createHash('sha256').update(readFileSync(path,'utf8').replace(/\r\n/g,'\n')).digest('hex');
 assert.equal(lock.revision,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(hash(lock.independentModel.generator),lock.independentModel.generatorSha256LF);
 assert.equal(hash(lock.independentModel.fixture),lock.independentModel.fixtureSha256LF);
 for (const dependency of lock.independentModel.dependencies) assert.equal(hash(dependency.path),dependency.sha256LF);
 assert.equal(lock.contracts.hpDraws,6);assert.equal(lock.contracts.openingAiDraws,3);
 assert.deepEqual(lock.contracts.hpRange,[48,56]);assert.deepEqual(lock.contracts.nipRange,[7,11]);
 assert.equal(lock.contracts.reincarnateDivisor,2);assert.equal(lock.contracts.centerChomp,false);
 assert.equal(new Set(lock.files.map(file=>file.path)).size,lock.files.length);
});
