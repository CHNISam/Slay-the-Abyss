import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';

test('Sphere component preserves stages, inclusive gold stream, deferred combat request and rejected inputs',()=>{
 const result=runLua('tests/lua/mysterious_sphere_event.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/MYSTERIOUS_SPHERE_COMPONENT 6 groups; 0 failed; bridge NOT_RUN/);
});
