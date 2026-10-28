import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
for(const [file,marker] of [['mushrooms_event','MUSHROOMS_HEAL_PASS'],['mushrooms_combat','MUSHROOMS_COMBAT_PASS'],['mushrooms_rollback','MUSHROOMS_ROLLBACK_PASS'],['mushrooms_ui','MUSHROOMS_UI_PASS']])test(`Mushrooms production ${file} preserves source boundaries`,()=>{
 const r=runLua(`tests/lua/${file}.lua`);assert.equal(r.status,0,r.stdout+r.stderr);assert.ok(r.stdout.includes(marker));
});
import {readFileSync} from 'node:fs';
test('Mushrooms pinned source keeps original screen, reward, and Vulnerable contracts',()=>{
 const lock=JSON.parse(readFileSync('tests/fixtures/mushrooms-source.json','utf8'));
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.sources['events/exordium/Mushrooms.java'],'0cd9d3b4b9b17a69daada1aba5b5d6e4c60ccf8937673d10c395db4ebfd0f31b');
 assert.deepEqual(lock.contracts.formation,[['fungi_beast',-450,30],['fungi_beast',-145,20],['fungi_beast',180,15]]);
 assert.deepEqual(lock.contracts.gold,[20,30]);assert.equal(lock.contracts.constructAt,'first_fight_choice');assert.equal(lock.contracts.rewardAt,'second_fight_choice');
 assert.deepEqual(lock.contracts.vulnerable,{player:1.25,enemy:1.5,type:'NORMAL'});
});
test('Mushrooms is selectable by actual unfiltered campaign source draw after floor six',()=>{
 const r=runLua('tests/lua/mushrooms_natural.lua');assert.equal(r.status,0,r.stdout+r.stderr);assert.ok(r.stdout.includes('MUSHROOMS_NATURAL_ROOM_PASS seed35'));
});
