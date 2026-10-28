import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('real UI mock factories share public argument contracts and preserve scene isolation',()=>{
  const result=runLua('tests/fixtures/js-owned/tests/lua/ui_mock_contract.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/UI_MOCK_CONTRACT_PASS 6/);
});
