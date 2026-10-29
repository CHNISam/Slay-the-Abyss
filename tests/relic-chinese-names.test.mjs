import test from 'node:test';
import assert from 'node:assert/strict';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {buildUI} from '../scripts/build-ui.mjs';
import {runLua} from '../scripts/test-lua.mjs';
import {readFileSync} from 'node:fs';
test('all source relic catalogs have project Chinese display names without changing rules or availability',()=>{
 buildLuaData();buildUI();const r=runLua('tests/lua/relic_chinese_names.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/RELIC_CHINESE_NAMES_PASS 156/);
});
test('every authored Boss relic keeps a nonempty Chinese effect description in the real NodeUI',()=>{
 const expected=JSON.parse(readFileSync('data/relics.json','utf8')).relics.filter(row=>row.rarity==='boss').length;
 assert.ok(expected>0);
 const r=runLua('tests/lua/relic_defined_boss_descriptions.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,new RegExp(`RELIC_DEFINED_BOSS_DESCRIPTION_PASS ${expected}(?:\\s|$)`));
});
