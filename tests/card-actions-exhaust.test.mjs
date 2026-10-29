import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {runLua} from '../scripts/test-lua.mjs';
import {luaString} from '../scripts/build-lua-data.mjs';

test('real card action exhaustion preserves queue, RNG, identity and native rollback',()=>{
  const result=runLua('tests/lua/card_actions_exhaust.lua');
  assert.equal(result.status,0,result.stderr||result.stdout);
  assert.match(result.stdout,/LUA_CARD_ACTIONS_EXHAUST_PASS 6/);
});

test('real exhaustion mutations fail the behavioral assertions',()=>{
  const source=readFileSync('src/lua/abyss_card_actions.lua','utf8');
  const mutations=[
    ['singleton RNG', 'not item.effect.alwaysRandom','true'],
    ['hand count snapshot','local count=#state.hand','local count=math.max(0,#state.hand-1)'],
    ['nonattack selection','combat.cardDefinition(state,v).type~="attack"','combat.cardDefinition(state,v).type=="attack"'],
    ['TOP queue order','{op="exhaustRandom",alwaysRandom=true},item.source,nil,nil,true)',
      '{op="exhaustRandom",alwaysRandom=true},item.source,nil,nil,false)'],
    ['specific UID','remove(state.hand,item.effect.uid)','remove(state.hand,-1)'],
  ];
  const dir=mkdtempSync(join(tmpdir(),'abyss-exhaust-mutants-'));
  try{
    for(const [name,before,after] of mutations){
      assert.equal(source.split(before).length-1,1,`${name}: unique live mutation`);
      const mutant=join(dir,'mutant.lua'),driver=join(dir,'driver.lua');
      writeFileSync(mutant,source.replace(before,after));
      writeFileSync(driver,`package.loaded.abyss_card_actions=dofile(${luaString(mutant.replaceAll('\\','/'))});dofile(${luaString(resolve('tests/lua/card_actions_exhaust.lua').replaceAll('\\','/'))})`);
      const result=runLua(driver);
      assert.notEqual(result.status,0,`${name}: mutant survived`);
      assert.match(result.stderr+result.stdout,/\[EXHAUST_CONTRACT\]/,`${name}: must fail the real behavior assertion`);
    }
  }finally{rmSync(dir,{recursive:true,force:true});}
});
