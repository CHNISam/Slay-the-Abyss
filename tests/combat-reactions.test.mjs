import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {runLua} from '../scripts/test-lua.mjs';
import {candidateScriptFiles} from '../scripts/native-candidate-scripts.mjs';

test('reaction facade preserves both nil restorations and ordinary writes',()=>{
 const result=runLua('tests/lua/combat_reactions_independence.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/COMBAT_REACTIONS_INDEPENDENCE_PASS/);
});
test('candidate script inventory includes combat reaction admission exactly once',()=>{
 assert.equal(candidateScriptFiles('src/lua','build/lua',[]).filter(row=>row.name==='abyss_combat_reactions').length,1);
});

test('Combat Reactions preserves pinned admission oracle and dynamic facade',()=>{
 const result=runLua('tests/lua/combat_reactions.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/dynamic restoration PASS/);
});

test('admission regression checks kill queue ordering, ownership, identity and drain mutations',()=>{
 const source=readFileSync('src/lua/abyss_combat_reactions.lua','utf8');
 const mutants=[
  ['top/bottom',source.replaceAll('if top then','if not top then')],
  ['typed ownership',source.replace('if state.actionQueue then','if false then')],
  ['effect identity',source.replaceAll('effect=effect','effect={op=effect.op}')],
  ['accidental drain',source.replace('if state.actionQueue then',"if state.actionQueue then state.actionQueue.actions={} end\n    if state.actionQueue then")],
 ];
 const dir=mkdtempSync(join(tmpdir(),'combat-reactions-'));
 try{for(const [name,mutant]of mutants){
  assert.notEqual(mutant,source,name+' mutation applied');
  const module=join(dir,'mutant.lua'),fixture=join(dir,'fixture.lua');
  writeFileSync(module,mutant);writeFileSync(fixture,`ABYSS_REACTIONS_FILE=${JSON.stringify(module)};dofile(${JSON.stringify(resolve('tests/lua/combat_reactions.lua'))})`);
  const result=runLua(fixture);assert.notEqual(result.status,0,name+' must fail');
  assert.match(result.stderr,/~=|identity|typed|bottom return/,name+' must fail a behavioral assertion');
 }}finally{rmSync(dir,{recursive:true,force:true});}
});
