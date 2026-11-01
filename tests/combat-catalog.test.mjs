import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('Combat and encounter preparation preserve private catalog ownership and constructor output',()=>{
 const result=runLua('tests/lua/combat_catalog.lua');
 assert.equal(result.status,0,result.stderr || result.stdout);
 assert.match(result.stdout,/COMBAT_CATALOG_PASS/);
});
