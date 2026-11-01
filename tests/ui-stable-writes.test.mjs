import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('settled UI skips hidden vista writes while explicit vista, entrance and shake recovery remain active',()=>{
  const result=runLua('tests/lua/ui_stable_writes.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/LUA_UI_STABLE_WRITES_PASS/);
  assert.match(result.stdout,/UI_STABLE_MENU_WRITES frames=60 calls=0 glow=60 mote=0/);
  assert.match(result.stdout,/UI_STABLE_VISIBLE_VISTA_WRITES frames=60 glow=60 mote=60/);
});
