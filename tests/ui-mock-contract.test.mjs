import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {readFileSync,writeFileSync,unlinkSync} from 'node:fs';
import {luaString} from '../scripts/build-lua-data.mjs';
import {randomUUID} from 'node:crypto';

test('real UI mock factories share public argument contracts and preserve scene isolation',()=>{
  const result=runLua('tests/lua/ui_mock_contract.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/UI_MOCK_CONTRACT_PASS 6/);
});

test('native grid destruction invalidates handles and deck consumers survive refresh and viewport churn',()=>{
  const result=runLua('tests/lua/grid_lifecycle_contract.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/GRID_LIFECYCLE_CONTRACT_PASS 3/);
});

test('native lifecycle gate detects removal of the production dead-item guard',()=>{
 const source=readFileSync('src/lua/abyss_deck_ui.lua','utf8');
 const anchor='if control.alive==false then self.bindings[control]=nil';
 assert.equal(source.split(anchor).length,2,'one production lifetime boundary');
 const mutant=source.replace(anchor,'if false then self.bindings[control]=nil');
 const entry=`build/deck-lifecycle-mutant-${randomUUID()}.lua`;
 writeFileSync(entry,`ABYSS_DECK_LIFECYCLE_MUTANT=${luaString(mutant)}\ndofile('tests/lua/deck_item_lifecycle.lua')\n`);
 try{
  const result=runLua(entry);
  assert.notEqual(result.status,0,'removed ownership guard must fail');
  assert.match(result.stdout+result.stderr,/GetChild.*invalid object/);
 }finally{unlinkSync(entry);}
});
