import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {toLua} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
const vectors=JSON.parse(readFileSync('tests/fixtures/sts1-colorless-potion-vectors.json'));
function body(bark=false){return `dofile('tests/lua/support/colorless_potion_source.lua')(${toLua(vectors)},${bark})`;}
test('ColorlessPotion source candidates, repeated-use RNG, zero-cost overflow and Bark copies match independent expectations',()=>{
 execFileSync('python',['tools/oracles/sts1_colorless_potion.py','--check']);
 const directory=mkdtempSync(join(tmpdir(),'colorless-potion-source-'));
 try{
  for(const bark of [false,true]){
   const path=join(directory,`bark-${bark}.lua`);writeFileSync(path,body(bark));
   const result=runLua(path);assert.equal(result.status,0,result.stdout+result.stderr);
   assert.ok(result.stdout.includes(`COLORLESS_POTION_SOURCE_PASS bark=${bark} wrappers=14`));
  }
 }finally{rmSync(directory,{recursive:true,force:true});}
});
test('ColorlessPotion witness detects omission of unused Discovery retrieval sampling',()=>{
 const directory=mkdtempSync(join(tmpdir(),'colorless-potion-source-mutation-'));
 try{
  const source=readFileSync('src/lua/abyss_potion_discovery.lua','utf8');const target=' generate(combat,state,p.effect)';
  assert.equal(source.split(target).length,2);
  const module=join(directory,'abyss_potion_discovery.lua');writeFileSync(module,source.replace(target,' -- mutation: omit retrieval sampling'));
  const path=join(directory,'case.lua');writeFileSync(path,`package.loaded.abyss_potion_discovery=dofile(${JSON.stringify(module)});${body()}`);
  const result=runLua(path);assert.notEqual(result.status,0,result.stdout+result.stderr);
  assert.match(result.stderr,/colorless retrieval stream 1/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
