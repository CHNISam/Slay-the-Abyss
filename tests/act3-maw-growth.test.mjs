import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
test('Maw and Spire Growth preserve source runtime actions and permanent room boundaries',()=>{
 const result=runLua('tests/lua/act3_maw_growth.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/ACT3_MAW_GROWTH 18 groups; 0 failed/);
});
test('fixed Maw/Growth source and independent vector evidence stay explicit',()=>{
 const lock=JSON.parse(readFileSync('tests/fixtures/act3-maw-growth-source-lock.json','utf8'));
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(new Set(lock.files.map(file=>file.path)).size,21);
 assert.equal(createHash('sha256').update(readFileSync(lock.independentModel.fixture,'utf8').replace(/\r\n/g,'\n')).digest('hex'),lock.independentModel.sha256);
 assert.equal(lock.contracts.sourceDeathRemovalHook,false);
 assert.equal(lock.contracts.growthSourceId,'Serpent');
});
