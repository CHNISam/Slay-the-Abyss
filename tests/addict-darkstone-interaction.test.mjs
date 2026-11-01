import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';
test('Separately composed Addict and exact Darkstone dependency preserve old/new source hook order and refusal rollback',()=>{
 const result=runLua('tests/lua/addict_darkstone_interaction.lua');
 assert.equal(result.status,0,result.stderr||result.stdout);assert.match(result.stdout,/ADDICT_DARKSTONE_INTERACTION 7 passed/);
});
