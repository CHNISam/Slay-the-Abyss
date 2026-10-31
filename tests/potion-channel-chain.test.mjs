import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {toLua} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
const fixture=JSON.parse(readFileSync('tests/fixtures/sts1-potion-channel-chain.json','utf8'));
const identities=Object.fromEntries(JSON.parse(readFileSync('tests/fixtures/sts1-potion-production-channels.json','utf8')).drops.map(row=>[row.sourceId,row.id]));
for(const sample of fixture.cases)test(`source potion stream survives Courier/reward/Entropic/escape/shop/elite chain seed ${sample.seed}`,()=>{
 const dir=mkdtempSync(join(tmpdir(),'potion-channel-chain-'));
 try {
  const path=join(dir,'case.lua');
  writeFileSync(path,`SOURCE_POTION_IDS=${toLua(identities)};dofile('tests/lua/support/potion_channel_chain.lua')(${toLua(sample)})`);
  const result=runLua(path);assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/POTION_CHANNEL_CHAIN_PASS/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});

test('the composed chain detects a lost Entropic persistent potion-stream commit',()=>{
 const dir=mkdtempSync(join(tmpdir(),'potion-channel-chain-mutant-'));
 try {
  const source=readFileSync('src/lua/abyss_run_potions.lua','utf8');
  const before='candidate.shopRng.potion=EventRandom.cloneState(battle.potionRng or battle.potionRandomRng)';
  assert.equal(source.split(before).length,2,'mutation must target exactly one existing publication');
  const module=join(dir,'abyss_run_potions.lua');
  writeFileSync(module,source.replace(before,'candidate.shopRng.potion=EventRandom.cloneState(run.shopRng.potion)'));
  const path=join(dir,'case.lua');
  writeFileSync(path,`package.loaded.abyss_run_potions=dofile(${JSON.stringify(module)});SOURCE_POTION_IDS=${toLua(identities)};dofile('tests/lua/support/potion_channel_chain.lua')(${toLua(fixture.cases[1])})`);
  const result=runLua(path);assert.notEqual(result.status,0,result.stdout+result.stderr);
  assert.match(result.stderr,/in upvalue 'same'/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
