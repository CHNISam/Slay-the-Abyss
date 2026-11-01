import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('route preview is nonrecursive and returns directly to battle or shop with stale input rejected',()=>{
 const r=runLua('tests/lua/route_preview_return.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/ROUTE_PREVIEW_RETURN 3 passed; 0 failed/);
});
