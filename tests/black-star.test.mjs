import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {spawnSync} from 'node:child_process';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {toLua,luaString} from '../scripts/build-lua-data.mjs';
import {loadContent,validateContent} from '../scripts/validate-data.mjs';

test('Black Star is an explicit supported hook; unknown hooks and generic effects remain rejected',()=>{
 const bundle=loadContent('data');assert.deepEqual(validateContent(bundle),[]);
 const entry=bundle.relics.relics.find(row=>row.id==='black_star');assert.ok(entry);
 entry.id='unknown_black_star_hook';assert.ok(validateContent(bundle).some(e=>e.includes('unsupported relic hook')));
 entry.id='black_star';entry.effects=[{op:'heal',amount:1}];
 assert.ok(validateContent(bundle).some(e=>e.includes('source hooks require empty generic effects')));
});

test('independent source interpretation retains the full source catalog and fixed seed vector',()=>{
 const result=spawnSync('python',['tests/fixtures/black-star-oracle.py'],{encoding:'utf8',timeout:30000});
 assert.equal(result.status,0,result.stderr);
 const vector=JSON.parse(result.stdout);
 assert.equal(vector.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(vector.catalogLfSha256,'bc7fd8c34ff0f85689ff9dee391b69a44d3b6c42860c85cc2ad9668c640126ae');
 assert.equal(vector.independentRandomLfSha256,'7c0c70dd7dbed02bc0107e5ec0efcdb7892bf14cdb61a5ddc3a127eaeb50c0a8');
 assert.deepEqual(vector.initialRng,{words:['d332029783617f60','2ca76ce675709681'],counter:5});
 assert.deepEqual(vector.afterEliteRng,{words:['b45492bcb6dec9cc','ebc969f27c5c6a98'],counter:7});
 assert.deepEqual(vector.bossOffers,['Astrolabe','Tiny House','Black Star']);
 assert.deepEqual(vector.tierRolls,[74,94]);assert.deepEqual(vector.rarePrefix.slice(0,2),['Peace Pipe','TungstenRod']);
 const lua=readFileSync('tests/fixtures/js-owned/tests/lua/black_star.lua','utf8');
 for(const state of [vector.initialRng,vector.afterEliteRng])for(const word of state.words)assert.ok(lua.includes(word));
});
test('Black Star production definition supports public Boss obtain and exact elite drops',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/black_star.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/BLACK_STAR_PASS/);
});

function inventoryRuntime(bundle){
 const manifest=JSON.parse(readFileSync('data/release/launch-content.json','utf8'));
 const directory=mkdtempSync(join(tmpdir(),'black-star-reject-'));
 try{
  const path=join(directory,'verify.lua');
  writeFileSync(path,`LAUNCH_DATA=${toLua(bundle)}\nLAUNCH_MANIFEST=${toLua(manifest)}\ndofile(${luaString(resolve('scripts/verify-launch-content.lua'))})\n`);
  return runLua(path);
 }finally{rmSync(directory,{recursive:true,force:true});}
}

test('inventory runtime binds elite acquisition to the actual supplied rare source catalog',()=>{
 const bundle=loadContent('data');
 const rare=bundle.relicSource.queues.rare;
 const index=rare.indexOf('TungstenRod');assert.ok(index>=0);
 rare[index]='FakeRare'; // Keep sourceCommit, all tier sizes and all 22 Boss IDs intact.
 const result=inventoryRuntime(bundle);
 assert.notEqual(result.status,0,'corrupt supplied rare catalog must not be validated against generated abyss_data instead');
 assert.match(result.stderr,/FakeRare ~= TungstenRod/);
});

test('inventory runtime still rejects wrong Black Star source mapping and an unregistered Boss',()=>{
 for(const mutation of ['wrong-source','unknown-boss']){
  const bundle=loadContent('data');
  const entry=bundle.relics.relics.find(row=>row.id==='black_star');
  if(mutation==='wrong-source')entry.sourceId='Fake Black Star';
  else bundle.relics.relics.push({id:'unregistered_boss',sourceId:'Fake Boss',rarity:'boss',trigger:'hooks',effects:[]});
  const result=inventoryRuntime(bundle);
  assert.notEqual(result.status,0);
  assert.match(result.stderr,mutation==='wrong-source'?/Black Star source ID mismatch/:/Unobtainable Boss relic: unregistered_boss/);
 }
});

test('inventory runtime requires Black Star to retain hooks with empty generic effects',()=>{
 for(const mutation of ['trigger','effects']){
  const bundle=loadContent('data');
  const entry=bundle.relics.relics.find(row=>row.id==='black_star');
  if(mutation==='trigger')entry.trigger='combat_end';
  else entry.effects=[{op:'heal',amount:1}];
  const result=inventoryRuntime(bundle);
  assert.notEqual(result.status,0);
  assert.match(result.stderr,/Black Star requires empty hook effects/);
 }
});
