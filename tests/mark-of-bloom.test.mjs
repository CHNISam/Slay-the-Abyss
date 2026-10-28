import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';
test('Mark blocks shared player heal channels, retains maxHP and leaves enemies and no-Mark controls unchanged',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/mark_of_bloom_healing.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/MARK_BLOOM_HEALING_PASS 36/);
});
test('Mark real named obtain, outside health items and combat opening share the permanent owner',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/mark_of_bloom_obtain.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/MARK_BLOOM_OBTAIN_PASS 4/);
});
