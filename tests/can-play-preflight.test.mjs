import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {runLua} from '../scripts/test-lua.mjs';
import {luaString} from '../scripts/build-lua-data.mjs';

test('canPlay preserves refusal priority and all targeted operations',()=>{
  const r=runLua('tests/lua/can_play_preflight.lua');
  assert.equal(r.status,0,r.stderr||r.stdout);
  assert.match(r.stdout,/LUA_CAN_PLAY_CONTRACT_PASS 93/);
});
test('canPlay real preflight mutations fail behavior assertions',()=>{
  const source=readFileSync('src/lua/abyss_combat.lua','utf8').replaceAll('\r\n','\n');
  const mutations=[
    ['target vocabulary','damageEqualToBlock=true,',''],
    ['priority of energy and target','ok,reason=playEnergy(state,card)\n    if not ok then return false,reason end\n    ok,reason=playEffectTarget(state,card,targetIndex)',
      'ok,reason=playEffectTarget(state,card,targetIndex)\n    if not ok then return false,reason end\n    ok,reason=playEnergy(state,card)'],
    ['pending choice refusal',"local function playWindow(state)\n    if state.pendingChoice or state.cardActions then return false,'card_choice_pending' end","local function playWindow(state)\n    if state.pendingChoice or state.cardActions then return false,'selection_pending' end"],
    ['Slimed strict shape','and not card.ethereal and not card.costMode and not card.condition','and not card.ethereal and not card.costMode'],
    ['X energy integer','state.energy%1~=0','false'],
  ];
  const dir=mkdtempSync(join(tmpdir(),'abyss-preflight-mutants-'));
  try{
    for(const [name,before,after] of mutations){
      assert.equal(source.split(before).length-1,1,`${name}: unique live mutation`);
      const mutant=join(dir,'mutant.lua'),driver=join(dir,'driver.lua');
      writeFileSync(mutant,source.replace(before,after));
      writeFileSync(driver,`package.loaded.abyss_combat=dofile(${luaString(mutant.replaceAll('\\','/'))});dofile(${luaString(resolve('tests/lua/can_play_preflight.lua').replaceAll('\\','/'))})`);
      const r=runLua(driver);
      assert.notEqual(r.status,0,`${name}: mutant survived`);
      assert.match(r.stderr+r.stdout,/\[CAN_PLAY_CONTRACT\]/,`${name}: behavioral failure required`);
    }
  }finally{rmSync(dir,{recursive:true,force:true});}
});
