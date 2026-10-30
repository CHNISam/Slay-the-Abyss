import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {runLua} from '../scripts/test-lua.mjs';
import {luaString} from '../scripts/build-lua-data.mjs';

test('hand mutation actions preserve constructors, RNG, upgrades and capacity',()=>{
  const result=runLua('tests/lua/card_actions_hand_mutation.lua');
  assert.equal(result.status,0,result.stderr||result.stdout);
  assert.match(result.stdout,/LUA_HAND_MUTATION_PASS 16/);
});

test('real hand mutation faults fail behavioral assertions',()=>{
  const source=readFileSync('src/lua/abyss_card_actions.lua','utf8');
  const mutations=[
    ['duplicate creation hook', "if op=='makeTempCardInHand' then M.created(combat,state,v)end",''],
    ['draw insertion range','combat.cardRandom(state,#state.draw+1)','combat.cardRandom(state,#state.draw)'],
    ['attack pool rarity order',"{'common','uncommon','rare'}","{'rare','uncommon','common'}"],
    ['negative cost guard','if cost>=0 then','if cost>=-2 then'],
    ['upgrade eligibility','if combat.canUpgrade(state,v) then combat.upgrade(state,v)','if false then combat.upgrade(state,v)'],
  ];
  const dir=mkdtempSync(join(tmpdir(),'abyss-hand-mutations-'));
  try{
    for(const [name,before,after] of mutations){
      assert.equal(source.split(before).length-1,1,`${name}: unique live mutation`);
      const mutant=join(dir,'mutant.lua'),driver=join(dir,'driver.lua');
      writeFileSync(mutant,source.replace(before,after));
      writeFileSync(driver,`package.loaded.abyss_card_actions=dofile(${luaString(mutant.replaceAll('\\','/'))});dofile(${luaString(resolve('tests/lua/card_actions_hand_mutation.lua').replaceAll('\\','/'))})`);
      const result=runLua(driver);
      assert.notEqual(result.status,0,`${name}: mutant survived`);
      assert.match(result.stderr+result.stdout,/\[HAND_MUTATION_CONTRACT\]/,`${name}: behavioral failure required`);
    }
  }finally{rmSync(dir,{recursive:true,force:true});}
});
