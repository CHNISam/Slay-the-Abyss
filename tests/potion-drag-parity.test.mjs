import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
for (const [path,count] of [['potion_drag_parity',2],['potion_drag_parity_cancel',2],['potion_drag_parity_owners',3]]) test(`approved single-target potion drag: ${path}`,()=>{
 const result=runLua(`tests/lua/${path}.lua`);
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.ok(result.stdout.includes(`POTION_DRAG_PARITY_PASS ${count}`));
});
