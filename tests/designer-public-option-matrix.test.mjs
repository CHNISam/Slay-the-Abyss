import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Designer source options and negative transactions execute through public Nodes commands',()=>{
 const result=runLua('tests/lua/designer_public_option_matrix.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/DESIGNER_PUBLIC_OPTION_MATRIX 4 passed/);
});
