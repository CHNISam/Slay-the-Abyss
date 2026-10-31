import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {luaString} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
test('source healing manifest authenticates original eligibility, values and Flower/Bloom modifiers',()=>{
 const bytes=readFileSync('tests/fixtures/smoke-victory-healing-source.json');
 assert.equal(createHash('sha256').update(bytes).digest('hex'),'628960ae54d2f57ae4b893c3d5ca1d64fdefb9d4d2486854373b37f59407de78');
 const source=JSON.parse(bytes);assert.equal(source.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');assert.equal(Object.keys(source.sources).length,9);
});
for(const mutation of [
 {name:'missing normal Smoke healing',before:'local healed=pcall(combatEndHealing,candidate)',after:'local healed=true -- mutation omits Smoke victory healing',method:'matrix',marker:/source Smoke victory healing/},
 {name:'duplicate event Smoke healing',before:'return EventCombat.escape(candidate)',after:'combatEndHealing(candidate);return EventCombat.escape(candidate)',method:'eventAndOrder',marker:/event Smoke must not double heal/},
])test(`real public Smoke rejects ${mutation.name}`,()=>{
 const directory=mkdtempSync(join(tmpdir(),'smoke-healing-mutant-'));
 try{
  const source=readFileSync('src/lua/abyss_run_potions.lua','utf8');assert.equal(source.split(mutation.before).length,2,'one precise source site');
  const path=join(directory,'case.lua');writeFileSync(path,`package.preload['abyss_run_potions']=function()return assert(load(${luaString(source.replace(mutation.before,mutation.after))}))()end\ndofile('tests/lua/support/smoke_victory_healing.lua').${mutation.method}()`);
  const result=runLua(path);assert.notEqual(result.status,0,result.stdout+result.stderr);assert.match(result.stderr,mutation.marker);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
