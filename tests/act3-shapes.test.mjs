import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
test('source Shapes use actual formation, enemy actions and public battle transactions',()=>{
 const result=runLua('tests/lua/act3_shapes.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/ACT3_SHAPES 17 groups; 0 failed/);
});
test('audited Shapes fixture remains the independently generated LF-normalized sequence',()=>{
 const lock=JSON.parse(readFileSync('tests/fixtures/act3-shapes-source-lock.json','utf8'));
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(createHash('sha256').update(readFileSync(lock.independentModel.fixture,'utf8').replace(/\r\n/g,'\n')).digest('hex'),lock.independentModel.sha256);
 assert.equal(new Set(lock.files.map(file=>file.path)).size,22);
});
