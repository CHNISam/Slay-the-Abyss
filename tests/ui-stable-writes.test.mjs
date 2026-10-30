import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('settled UI avoids repeated native writes while entrance, vista and shake recovery remain active',()=>{
  const result=runLua('tests/lua/ui_stable_writes.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/LUA_UI_STABLE_WRITES_PASS/);
});
