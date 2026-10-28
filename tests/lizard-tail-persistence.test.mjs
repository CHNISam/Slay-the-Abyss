import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {runLua} from '../scripts/test-lua.mjs';
import {loadContent} from '../scripts/validate-data.mjs';
import {toLua,luaString} from '../scripts/build-lua-data.mjs';
test('Tail source draw and persistent spent owner survive chapter/map boundaries without rearming',()=>{
 const oracle=JSON.parse(readFileSync('tests/fixtures/sts1-relic-pool-vectors.json','utf8'));
 assert.equal(oracle.cases.find(c=>c.seed==='65536'&&c.profile==='all-unlocked').queues.rare[0],'Lizard Tail');
 const r=runLua('tests/fixtures/js-owned/tests/lua/lizard_tail_persistence.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/LIZARD_TAIL_PERSISTENCE_PASS 3 groups; controlled\/offline only/);
});

test('launch runtime rejects a counterfeit supplied Tail identity or rare source without using generated data',()=>{
 const manifest=JSON.parse(readFileSync('data/release/launch-content.json','utf8'));
 for(const kind of ['source','effects','rare-catalog']){
  const data=loadContent('data');
  const tail=data.relics.relics.find(r=>r.id==='lizard_tail');
  if(kind==='source')tail.sourceId='Fake Tail';
  if(kind==='effects')tail.effects=[{op:'heal',amount:1}];
  if(kind==='rare-catalog'){
   const at=data.relicSource.queues.rare.indexOf('Lizard Tail');assert.ok(at>=0);
   data.relicSource.queues.rare[at]='Fake Tail'; // Same sourceCommit, sizes and all other IDs.
  }
  const dir=mkdtempSync(join(tmpdir(),'tail-actual-data-'));
  try{
   const path=join(dir,'verify.lua');
   writeFileSync(path,`LAUNCH_DATA=${toLua(data)}\nLAUNCH_MANIFEST=${toLua(manifest)}\ndofile(${luaString(resolve('scripts/verify-launch-content.lua'))})\n`);
   const result=runLua(path);
   assert.notEqual(result.status,0,kind);
   assert.match(result.stderr,kind==='source'?/Lizard Tail fixed source\/rarity mismatch/:kind==='effects'?/Lizard Tail requires empty hook effects/:/Fake Tail ~= Lizard Tail/);
  }finally{rmSync(dir,{recursive:true,force:true});}
 }
});
