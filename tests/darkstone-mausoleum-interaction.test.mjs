import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';
test('dependency-only Darkstone/Mausoleum and actual public victory-Proceed cleanup across explicit Act2 staging seam',()=>{
 const result=runLua('tests/lua/darkstone_mausoleum_interaction.lua');assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/DARKSTONE_MAUSOLEUM_INTERACTION 4 passed/);
});
