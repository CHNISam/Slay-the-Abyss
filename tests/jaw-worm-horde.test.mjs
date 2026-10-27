import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
test('Jaw Worm Horde preserves its hard-mode source entry and actions',()=>{
 const result=runLua('tests/lua/jaw_worm_horde.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/JAW_WORM_HORDE 18 groups; 0 failed/);
});
test('Horde source identities and independent four-seed vectors remain locked',()=>{
 const lock=JSON.parse(readFileSync('tests/fixtures/jaw-worm-horde-source-lock.json','utf8'));
 const hash=path=>createHash('sha256').update(readFileSync(path,'utf8').replace(/\r\n/g,'\n')).digest('hex');
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(new Set(lock.files.map(file=>file.path)).size,15);
 assert.equal(hash(lock.independentModel.generator),lock.independentModel.generatorSha256LF);
 assert.equal(hash(lock.independentModel.fixture),lock.independentModel.fixtureSha256LF);
 assert.deepEqual(lock.contracts.hpRange,[40,44]);assert.equal(lock.contracts.hpDraws,3);
 assert.equal(lock.contracts.openingAiDraws,3);assert.equal(lock.contracts.miscDraws,0);
 assert.equal(lock.contracts.openingForcedChomp,false);
});
