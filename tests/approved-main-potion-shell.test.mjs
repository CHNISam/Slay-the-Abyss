import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Main physical potion shells follow real inventory and retire selected style with the exact interaction owner',()=>{
 const r=runLua('tests/lua/approved_main_potion_shell.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/APPROVED_MAIN_POTION_SHELL_PASS/);
});
