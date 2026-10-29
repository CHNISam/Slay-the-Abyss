import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('retained deck consumers survive native control destruction without broad error suppression',()=>{
 const result=runLua('tests/lua/pr323_deck_lifecycle.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/PR323_DECK_LIFECYCLE_PASS 3/);
});

test('removing the native alive boundary reproduces the original destroyed-control error',async()=>{
 const {readFileSync,writeFileSync,unlinkSync}=await import('node:fs');
 const {luaString}=await import('../scripts/build-lua-data.mjs');
 const {randomUUID}=await import('node:crypto');
 const source=readFileSync('src/lua/abyss_deck_ui.lua','utf8');
 const anchor='if control.alive==false then self.bindings[control]=nil';
 assert.equal(source.split(anchor).length,2);
 const mutant=source.replace(anchor,'if false then self.bindings[control]=nil');
 const entry=`build/pr323-lifetime-mutant-${randomUUID()}.lua`;
 writeFileSync(entry,`ABYSS_DECK_LIFECYCLE_MUTANT=${luaString(mutant)}\ndofile('tests/lua/pr323_deck_lifecycle.lua')\n`);
 try{
  const result=runLua(entry);assert.notEqual(result.status,0,'missing lifetime boundary must fail');
  assert.match(result.stdout+result.stderr,/GetChild.*invalid object/);
 }finally{unlinkSync(entry);}
});
