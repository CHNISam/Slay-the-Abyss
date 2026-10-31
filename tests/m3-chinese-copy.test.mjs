import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('competition copy keeps effect bodies concise and rejects removed help entrypoints',()=>{
 const r=runLua('tests/lua/m3_chinese_copy.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/M3_CHINESE_COPY_PASS/);
});
