import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('merchant keeps complete class identities and RNG when an implementation is absent',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/shop_complete_source.lua');
 assert.equal(result.status,0,result.stderr||result.stdout);
 assert.match(result.stdout,/SHOP_COMPLETE_SOURCE_PASS 8/);
});
