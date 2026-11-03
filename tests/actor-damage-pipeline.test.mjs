import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {runStatic} from '../scripts/check-lua-static.mjs';
import {discoverSources,measureSources} from '../scripts/lua-quality-metrics.mjs';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {luaString} from '../scripts/build-lua-data.mjs';

test('Actor damage pipeline retains modifiers, reaction order and original object rollback',()=>{
  const result=runLua('tests/lua/actor_damage_pipeline.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/ACTOR_DAMAGE_PIPELINE_PASS 5/);
});
test('Actor damage and all extracted pipeline responsibilities have complete CC15 measurements',()=>{
  const measurements=measureSources(discoverSources(),runStatic(['--max-cyclomatic-complexity','0','--only','561']).diagnostics);
  assert.deepEqual(measurements.errors,[]);
  const actor=measurements.modules.find(m=>m.file==='src/lua/abyss_actor.lua');
  const names=['damageAmount','consumeAttackBlock','modifyIncomingAttack','applyAttackHpLoss','queueHitPowers','queueAttackedPowers','M.damage'];
  for(const name of names){
    const functions=actor.functions.filter(f=>f.name===name);
    assert.equal(functions.length,1,`${name}: complete measurement`);
    assert(functions[0].complexity<=15,`${name}: ${functions[0].complexity} exceeds 15`);
  }
  const start=actor.functions.find(f=>f.name==='damageAmount').line,end=actor.functions.find(f=>f.name==='M.blockFloat').line;
  for(const f of actor.functions.filter(f=>f.kind==='function'&&f.line>=start&&f.line<end))assert(f.complexity<=15,`${f.name}: nested/helper budget`);
});
test('damage modifiers, snapshot bounds and retaliation-order mutations fail actual behavior',()=>{
  const source=readFileSync('src/lua/abyss_actor.lua','utf8').replaceAll('\r\n','\n');
  const rare="    if target==state.player then unblocked=require('abyss_rare_relics').onAttacked(state,source,fixed and 'thorns'or 'normal',unblocked)end";
  const last="    if target==state.player then unblocked=require('abyss_relic_hooks').onLoseHpLast(state,unblocked)end";
  const mutations=[
    ['fixed Boot','source==state.player and not fixed and unblocked>0','source==state.player and unblocked>0'],
    ['snapshot integer bound','normalAmount<=9007199254740991','normalAmount<=9007199254740992'],
    ['last HP-loss stage',rare+'\n'+last,last+'\n'+rare],
    ['TOP reaction direction','for i = #reactions, 1, -1 do','for i = 1, #reactions do'],
  ];
  const directory=mkdtempSync(join(tmpdir(),'actor-damage-mutants-'));
  try{
    for(const [label,before,after] of mutations){
      assert.equal(source.split(before).length-1,1,`${label}: unique current mutation`);
      const mutant=join(directory,'actor.lua'),driver=join(directory,'driver.lua');
      writeFileSync(mutant,source.replace(before,after));
      writeFileSync(driver,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path;package.loaded.abyss_actor=dofile(${luaString(mutant.replaceAll('\\','/'))});dofile(${luaString(resolve('tests/lua/actor_damage_pipeline.lua').replaceAll('\\','/'))})`);
      const result=runLua(driver);
      assert.notEqual(result.status,0,`${label}: mutant survived`);
      assert.match(result.stdout+result.stderr,/\[ACTOR_DAMAGE\]/,`${label}: behavioral assertion required`);
    }
  }finally{rmSync(directory,{recursive:true,force:true});}
});
