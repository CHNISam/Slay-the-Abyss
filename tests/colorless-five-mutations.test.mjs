import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {luaString} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
for(const [name,owner,from,to,marker] of [
 ['deep_breath','abyss_colorless_cards',"function actionHandlers.deepBreath(_,state)\n    if #state.discard>0 then","function actionHandlers.deepBreath(_,state)\n    if false then",'Deep Breath merged draw pile'],
 ['impatience','abyss_colorless_cards',"for _,c in ipairs(state.hand)do if state.catalog.cards[c.cardId].type=='attack'then return end end",'-- omitted conditional draw restriction','Impatience conditional draw'],
 ['metamorphosis','abyss_colorless_catalog',"{e('generateDraw',3,{cardType='attack'})}","{e('generateDraw',2,{cardType='attack'})}",'Metamorphosis count'],
 ['secret_technique','abyss_colorless_catalog',"{e('secret',1,{cardType='skill'})}","{e('secret',1,{cardType='attack'})}",'move selected object without cloning'],
 ['violence','abyss_colorless_catalog',"{e('violence',3)}","{e('violence',2)}",'Violence hand'],
])test(`exact ${name} behavior rejects its targeted production mutation`,()=>{
 const source=readFileSync('src/lua/'+owner+'.lua','utf8').replaceAll('\r\n','\n');
 assert.equal(source.split(from).length,2,'mutation must have exactly one source anchor');
 const directory=mkdtempSync(join(tmpdir(),'colorless-five-mutant-'));
 try{
  const path=join(directory,'mutant.lua');
  writeFileSync(path,`package.preload[${luaString(owner)}]=function() return assert(load(${luaString(source.replace(from,to))},'colorless-five-mutant'))() end\nlocal M=dofile('tests/lua/support/colorless_five_effects.lua');M.${name}()`);
  const r=runLua(path);assert.notEqual(r.status,0,'targeted defect must fail');
  assert.ok((r.stdout+r.stderr).includes(marker),r.stdout+r.stderr);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
