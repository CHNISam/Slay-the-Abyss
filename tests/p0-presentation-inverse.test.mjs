import {preAcceptedPr323Source} from './helpers/pr323-accepted-source-inverse.mjs';
import {preApprovedUiSource} from './helpers/approved-ui-inverse.mjs';
import {preNodeUiRefactorSource}from'./helpers/node-ui-refactor-inverse.mjs';
import {maxHpAcceptedInverse,preMaxHpSource}from'./helpers/max-hp-accepted-source-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {p0Presentation,preAcceptedPresentation,preP0OuterSource} from './helpers/p0-presentation-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
test('historical replay inverses bind every current source and exactly recover the accepted formal presentation',()=>{
 assert.equal(p0Presentation.historicalHead,'300a96a8c1e2b2cec3b1b3d9b25518a3b94abf70');
 for(const [path,binding]of Object.entries(p0Presentation.files)){
  const current=preApprovedUiSource(path,preP0OuterSource(path,readFileSync(path,'utf8').replaceAll('\r\n','\n')));
  const projected=preMaxHpSource(path,preNodeUiRefactorSource(path,current));
  assert.equal(preNodeUiRefactorSource(path,preMaxHpSource(path,current)),projected,'disjoint Max HP and Node UI inverse scopes commute');
  assert.equal(hash(projected),binding.afterSha256,path);
  const original=preAcceptedPresentation(path,current);
  assert.equal(hash(original),binding.beforeSha256,path);
  assert.equal(preAcceptedPresentation(path,current.replaceAll('\n','\r\n')),original);
  assert.throws(()=>preAcceptedPresentation(path,current+'\n-- unrelated drift\n'),/unreviewed integrated/);
  const edit=binding.edits[0];
  assert.throws(()=>preAcceptedPresentation(path,projected.replace(edit.after,edit.after+edit.after)),/unreviewed integrated/);
  assert.throws(()=>preAcceptedPresentation(path,projected.replace(edit.after,'')),/unreviewed integrated/);
 }
});
test('direct P0 theme identity rejects partial duplicated moved and unrelated Max HP source drift in either inverse order',()=>{
 const path='data/presentation/ui_theme.json',current=preAcceptedPr323Source(path,readFileSync(path,'utf8')).replaceAll('\r\n','\n');
 const binding=p0Presentation.files[path],edit=maxHpAcceptedInverse.files[path].edits[0];
 const moved=JSON.parse(current),glyph=moved.icon.relic.pear;
 delete moved.icon.relic.pear;moved.icon.relic={pear:glyph,...moved.icon.relic};
 const unrelated=JSON.parse(current);unrelated.font.body++;
 for(const mutant of [
  current.replace('      "pear": 102005,\n',''),
  current.replace(edit.after,edit.after+edit.after),
  current.replace('"pear"','"unreviewed_pear"'),
  JSON.stringify(moved,null,2)+'\n',JSON.stringify(unrelated,null,2)+'\n',current+'\n',
 ]){
  assert.notEqual(mutant,current,'negative control must change actual current source');
  const forward=preMaxHpSource(path,preNodeUiRefactorSource(path,mutant));
  const reverse=preNodeUiRefactorSource(path,preMaxHpSource(path,mutant));
  assert.equal(forward,mutant,'unknown identity is not filtered by either inverse');
  assert.equal(reverse,mutant);
  assert.notEqual(hash(forward),binding.afterSha256,'unchanged direct P0 identity rejects the mutant');
  assert.throws(()=>preAcceptedPresentation(path,mutant),/unreviewed integrated/);
 }
});
