import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync}from'node:fs';
import {createHash}from'node:crypto';
import {maxHpAcceptedInverse as proof,preMaxHpSource}from'./helpers/max-hp-accepted-source-inverse.mjs';
import {preRetirementSource}from'./helpers/presentation-announcement-retirement.mjs';
import {preAcceptedPresentation}from'./helpers/p0-presentation-inverse.mjs';
const hash=source=>createHash('sha256').update(source).digest('hex');
const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
test('only the three reviewed Max HP additions reverse to the complete accepted data identities',()=>{
 assert.equal(proof.acceptedBase,'432eebb1d51a7ad37cfbc19f0e846bc00f1f4ba7');
 assert.equal(proof.originalSlice,'0391ea7301894f39b05a64e1e9bfa4d436925ed4');
 assert.deepEqual(Object.keys(proof.files),['data/presentation/ui_theme.json','data/relics.json']);
 for(const[path,binding]of Object.entries(proof.files)){
  const current=read(path),before=preMaxHpSource(path,current);
  assert.equal(hash(current),binding.afterSha256);assert.equal(hash(before),binding.beforeSha256);
  assert.equal(preMaxHpSource(path,current.replaceAll('\n','\r\n')),before);
  assert.equal(preMaxHpSource(path,before),before);
  let restored=before;for(const edit of binding.edits)restored=restored.replace(edit.before,edit.after);
  assert.equal(restored,current,'raw identity restoration retains every accepted byte and position');
  assert.equal(preRetirementSource(path,current),preRetirementSource(path,before),'historical replay is unchanged');
  if(path.endsWith('ui_theme.json'))
   assert.equal(preAcceptedPresentation(path,current),preAcceptedPresentation(path,before),'accepted UI/Node inverse composition remains intact');
 }
 const old=JSON.parse(preMaxHpSource('data/relics.json',read('data/relics.json'))).relics;
 const current=JSON.parse(read('data/relics.json')).relics;
 assert.equal(old.length,56);assert.equal(current.length,59);assert.deepEqual(current.slice(0,old.length),old);
 assert.deepEqual(current.slice(old.length).map(row=>row.id),['pear','mango','lees_waffle']);
});
test('partial duplicate renamed reordered and unrelated Max HP source drift is never projected away',()=>{
 for(const[path,binding]of Object.entries(proof.files)){
  const current=read(path),edit=binding.edits[0],mutants=[
   current.replace('"mango"','"unreviewed_mango"'),current.replace(edit.after,edit.after+edit.after),
   current.replace('"pear"','"unreviewed_pear"'),current+'\n',
  ];
  const reordered=JSON.parse(current),partial=JSON.parse(current),unrelated=JSON.parse(current);
  if(path.endsWith('relics.json')){
   reordered.relics.reverse();partial.relics=partial.relics.filter(row=>row.id!=='pear');
   unrelated.relics[0].description+=' unreviewed';
  }else{
   const glyph=reordered.icon.relic.pear;delete reordered.icon.relic.pear;reordered.icon.relic={pear:glyph,...reordered.icon.relic};
   delete partial.icon.relic.pear;unrelated.font.body++;
  }
  mutants.push(...[reordered,partial,unrelated].map(object=>JSON.stringify(object,null,2)+'\n'));
  for(const mutant of mutants){
   assert.notEqual(mutant,current);assert.equal(preMaxHpSource(path,mutant),mutant);
   assert.throws(()=>preRetirementSource(path,mutant),/unreviewed integrated retirement source drift/);
  }
 }
});
