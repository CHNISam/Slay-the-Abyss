import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
for(const [suffix,cases] of [['',[1,2,3]],['_slice_2',[4,5,6]],['_slice_3',[7,8,9]]])test(`new potion drag path preserves complete pointer owner cases ${cases.join(',')}`,()=>{
 const result=runLua(`tests/lua/potion_drag_click_composition${suffix}.lua`,{timeout:30000});
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/POTION_DRAG_CLICK_COMPOSITION_PASS 3/);
 assert.deepEqual([...result.stdout.matchAll(/^POTION_DRAG_CLICK_COMPOSITION_CASE (\d+)$/gm)].map(m=>Number(m[1])),cases);
});
test('actual controller Confirm and Cancel preserve potion origin after their consumed frame and permit fresh commands',()=>{
 const result=runLua('tests/lua/potion_controller_cancel_composition.lua',{timeout:30000});
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/POTION_CONTROLLER_CANCEL_PASS 4/);
 assert.deepEqual([...result.stdout.matchAll(/^POTION_CONTROLLER_CANCEL_CASE (\d+)$/gm)].map(m=>Number(m[1])),[1,2,3,4]);
});
