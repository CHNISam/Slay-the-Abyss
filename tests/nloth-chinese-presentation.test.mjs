import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('Nloth native event controls use the existing Chinese relic identity',()=>{
  const result=runLua('tests/lua/nloth_chinese_presentation.lua');
  assert.equal(result.status,0,result.stderr||result.stdout);
  assert.match(result.stdout,/LUA_NLOTH_CHINESE_PRESENTATION_PASS/);
});
