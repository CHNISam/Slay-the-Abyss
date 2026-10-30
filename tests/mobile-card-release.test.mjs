import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('mobile drag release clears invalid selections and preserves desktop target carry',()=>{
 const result=runLua('tests/lua/mobile_card_release.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/MOBILE_CARD_RELEASE 7 passed; 0 failed/);
});
