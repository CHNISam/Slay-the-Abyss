import {execFileSync} from 'node:child_process';
import {writeFileSync,unlinkSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import assert from 'node:assert/strict';
import {runLua} from '../../../scripts/test-lua.mjs';
import {luaString} from '../../../scripts/build-lua-data.mjs';
const base='aa4d56f57c15727668ef8675e626b44e67a5aaa5';
for(const [name,modules,fixture,failure]of [
 ['duplicate',['abyss_game_ui','abyss_battle_actions'],'runtime_ui_hotpaths','GameUI refresh rendered battle twice'],
 ['hand',['abyss_battle_card_view'],'runtime_ui_hotpaths','settled card geometry resubmitted'],
 ['potion',['abyss_battle_potion_bindings'],'potion_drag_hotpath','drag preflight simulated unrelated potion slots'],
]){
 const entry=join(tmpdir(),`runtime-red-${randomUUID()}.lua`);
 const prelude=modules.map(module=>{
  const source=execFileSync('git',['show',`${base}:src/lua/${module}.lua`],{encoding:'utf8'});
  return `package.preload[${luaString(module)}]=assert(load(${luaString(source)},'@${module}-${base}'))`;
 }).join('\n');
 writeFileSync(entry,`${prelude}\ndofile('tests/lua/${fixture}.lua')\n`);
 try{
  const result=runLua(entry),output=result.stdout+result.stderr;
  assert.notEqual(result.status,0);assert.ok(output.includes(failure),output);
  writeFileSync(`docs/evidence/m9-runtime-20261103/red-${name}.txt`,output);
  console.log(`Historical source RED confirmed: ${name}`);
 }finally{unlinkSync(entry);}
}
