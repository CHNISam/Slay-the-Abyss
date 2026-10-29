import {preFormalEntrySource} from './support/formal-entry-source-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
const seed70Bytes=readFileSync('tests/fixtures/max-hp-seed70-inventory-inverse.json');
assert.equal(hash(seed70Bytes),'a3186dad9c7997535d9ea4f7e8572237296800870c994a458d840ec63f134b80');
const seed70=JSON.parse(seed70Bytes);
// Exact test-only inverse for the authorized Pear-availability repair, before
// the unchanged PR238 whole-body proof. Never filter cases or replace hashes.
function preSeed70Source(path,source){
 source=source.replaceAll('\r\n','\n');
 const binding=seed70.binding;
 if(path!==binding.path || hash(source)===binding.beforeSha256)return source;
 assert.equal(hash(source),binding.afterSha256,'unreviewed integrated seed70 inventory source drift');
 for(const edit of binding.edits){
  assert.equal(source.split(edit.after).length,2,'one exact authorized seed70 inventory hunk');
  source=source.replace(edit.after,edit.before);
 }
 assert.equal(hash(source),binding.beforeSha256,'complete original pre-seed70-repair inventory recovered');
 return source;
}
const read=p=>preSeed70Source(p,preFormalEntrySource(p,readFileSync(p,'utf8')));
const budget=JSON.parse(read('tests/fixtures/pr238-remaining-budget.json'));
test('remaining PR238 budgets retain complete bodies and exact case coverage',()=>{
 assert.equal(budget.base,'7593e8272b363f06d3cdaa62f29967756b3c1102');assert.equal(budget.timeoutMilliseconds,30000);
 assert.deepEqual(budget.fixtures.map(f=>[f.entry,f.total]),[['tests/lua/sneaky_gremlin.lua',8],['tests/lua/growing_attack.lua',36],['tests/lua/inventory.lua',12],['tests/lua/vulnerable_combo.lua',52],['tests/lua/character_presentation.lua',16],['tests/lua/game_ui_phase_four.lua',26],['tests/lua/nodes.lua',21],['tests/lua/gremlin_gang.lua',19]]);
 assert.deepEqual(budget.fixtures.filter(f=>f.seedCoverage).map(f=>[f.entry,f.seedCoverage]),[['tests/lua/sneaky_gremlin.lua',{case:8,first:0,last:127,originalLast:127,firstQualifyingReward:null}],['tests/lua/growing_attack.lua',{case:36,first:1,last:49,originalLast:128,firstQualifyingReward:49}],['tests/lua/vulnerable_combo.lua',{case:52,first:1,last:26,originalLast:128,firstQualifyingReward:26}]]);
 for(const f of budget.fixtures){let s=read(f.entry);assert(s.endsWith(f.footer));if(f.footer)s=s.slice(0,-f.footer.length);
  for(const e of [...f.edits].reverse()){assert.equal(s.split(e.after).length,2);s=s.replace(e.after,e.before);}
  if(f.entry==='tests/lua/game_ui_phase_four.lua'){
   // The strict native fixture rejects CursorArea.interactable. Invert only
   // this reviewed click-helper field check; freeze every original assertion,
   // case, seed and fixture deadline against the same original body hash.
   const current=" assert(c.raycastTarget~=false and (c.kind~='presetButton' or c.interactable~=false),'disabled click '..path)\n";
   const original=" assert(c.interactable~=false,'disabled click '..path)\n";
   assert.equal(s.split(current).length,2,'one precise native click-contract change');
   s=s.replace(current,original);
  }
  assert.equal(createHash('sha256').update(s).digest('hex'),f.originalSha256LF,f.entry);
  if(f.helper){let h=read(f.helper.path);for(const e of [...f.helper.edits].reverse()){assert.equal(h.split(e.after).length,2);h=h.replace(e.after,e.before);}assert.equal(createHash('sha256').update(h).digest('hex'),f.helper.originalSha256LF);}
  const seen=[],seeds=[];
  for(const [i,p]of f.slices.entries()){
   if(i)assert.equal(read('tests/lua/'+p.file),`assert(loadfile('${f.entry}'))(${[p.first,p.last,...(p.seedRange??[])].join(',')})\n`);
   else{assert.equal('tests/lua/'+p.file,f.entry);assert(read(f.entry).includes(`sliceFirst,sliceLast=sliceFirst or ${p.first},sliceLast or ${p.last}`));}
   if(p.seedRange){assert.equal(p.first,f.seedCoverage.case);assert.equal(p.last,p.first);
    const [a,b]=p.seedRange;for(let n=a;n<=b;n++)seeds.push(n);if(a===f.seedCoverage.first)seen.push(p.first);
   }else for(let n=p.first;n<=p.last;n++)seen.push(n);
  }
  assert.deepEqual(seen,Array.from({length:f.total},(_,i)=>i+1));
  if(f.seedCoverage)assert.deepEqual(seeds,Array.from({length:f.seedCoverage.last-f.seedCoverage.first+1},(_,i)=>i+f.seedCoverage.first));
  else assert.deepEqual(seeds,[]);
 }
});
test('authorized seed70 inverse restores exact original inventory bytes and commutes with existing source layers',()=>{
 assert.equal(seed70.authorizedSourceRepair,'c9d189c6561039c7a62a506c9cefab87733738f4');
 const {path,beforeSha256,afterSha256,edits}=seed70.binding;
 assert.equal(path,'tests/lua/inventory.lua');assert.equal(edits.length,3);
 const current=readFileSync(path,'utf8').replaceAll('\r\n','\n'),before=preSeed70Source(path,current);
 assert.equal(hash(current),afterSha256);assert.equal(hash(before),beforeSha256);
 assert.equal(preSeed70Source(path,current.replaceAll('\n','\r\n')),before);
 assert.equal(preSeed70Source(path,before),before);
 let restored=before;for(const edit of edits){assert.equal(restored.split(edit.before).length,2);restored=restored.replace(edit.before,edit.after);}
 assert.equal(restored,current,'raw forward roundtrip preserves all current seed70 control and original cases');
 assert.equal(preFormalEntrySource(path,before),preSeed70Source(path,preFormalEntrySource(path,current)));
});
test('seed70 inverse rejects incomplete duplicated reordered or unrelated fixture edits',()=>{
 const {path,edits}=seed70.binding,current=readFileSync(path,'utf8').replaceAll('\r\n','\n');
 const mutants=[current+'\n',current.replace('assert(acquired and visitedEvent and boughtCard)','assert(acquired and visitedEvent)'),
  current.replace('assert(sliceRegistered==12','assert(sliceRegistered==11')];
 for(const edit of edits){mutants.push(current.replace(edit.after,edit.before),current.replace(edit.after,edit.after+edit.after));}
 const moved=current.replace(edits[2].after,'')+edits[2].after;mutants.push(moved);
 for(const mutant of mutants){
  assert.notEqual(mutant,current,'negative control changes real inventory source');
  assert.throws(()=>preSeed70Source(path,mutant),/unreviewed integrated seed70 inventory source drift/);
 }
});
