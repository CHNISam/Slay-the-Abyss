import {preNodeUiRefactorSource}from'./helpers/node-ui-refactor-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {p0Presentation,preAcceptedPresentation} from './helpers/p0-presentation-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
test('historical replay inverses bind every current source and exactly recover the accepted formal presentation',()=>{
 assert.equal(p0Presentation.historicalHead,'300a96a8c1e2b2cec3b1b3d9b25518a3b94abf70');
 for(const [path,binding]of Object.entries(p0Presentation.files)){
  const current=readFileSync(path,'utf8').replaceAll('\r\n','\n');
  const projected=preNodeUiRefactorSource(path,current);
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
