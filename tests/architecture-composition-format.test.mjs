import {historicalTest as test} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {pr323AcceptedSourceInverse as proof,requirePr323Source,preAcceptedPr323Source,preOriginalPr323Source,normalizePr323CompositionSource} from './helpers/pr323-accepted-source-inverse.mjs';

const path='config/architecture.json';
const source=readFileSync(path,'utf8').replaceAll('\r\n','\n');
const hash=text=>createHash('sha256').update(text).digest('hex');

test('architecture layout whitespace projects to the same immutable complete historical bytes',()=>{
 assert.equal(hash(normalizePr323CompositionSource(path,source)),proof.files[path].afterSha256);
 for(const variant of [JSON.stringify(JSON.parse(source)),JSON.stringify(JSON.parse(source),null,'\t'),source+'\n\t ',source.replaceAll('\n','\r\n')]){
  assert.deepEqual(JSON.parse(variant),JSON.parse(source),'production JSON.parse receives the same policy');
  requirePr323Source(path,variant);
  for(const [project,target]of [[preAcceptedPr323Source,'accepted'],[preOriginalPr323Source,'original']]){
   const historical=project(path,variant);
   assert.equal(historical,proof.files[path][target+'Source']);
   assert.equal(hash(historical),proof.files[path][target+'Sha256']);
  }
 }
});

test('whitespace permission never hides changed tokens, duplicate keys, array order or string content',()=>{
 const policy=JSON.parse(source),key=Object.keys(policy.layers)[0];
 const changed=structuredClone(policy);changed.layers[key]=policy.layers[key]==='ui'?'core':'ui';
 const unknown=structuredClone(policy);unknown.unreviewed=true;
 const reordered=structuredClone(policy);
 assert.ok(reordered.deferredImports.length>1,'array order negative control has distinct actual entries');
 reordered.deferredImports.reverse();
 const first=JSON.stringify(key),value=JSON.stringify(policy.layers[key]);
 const compact=JSON.stringify(policy);
 const variants=[JSON.stringify(changed),JSON.stringify(unknown),JSON.stringify(reordered),
  compact.replace(first+':'+value,first+':'+value+','+first+':'+value),
  compact.replace(first,JSON.stringify(key+' ')),
  compact.replace(first,first.replace('a','\\u0061')),
  compact+' invalid',compact.replace('{','{/*comment*/')];
 for(const variant of variants){
  assert.notEqual(variant,compact,'negative control changes the input');
  assert.throws(()=>requirePr323Source(path,variant),/unreviewed integrated/);
  assert.equal(preAcceptedPr323Source(path,variant),variant,'unrecognized bytes remain exposed');
  assert.equal(preOriginalPr323Source(path,variant),variant);
 }
 assert.throws(()=>requirePr323Source('data/presentation/ui_theme.json',' '+readFileSync('data/presentation/ui_theme.json','utf8')),/unreviewed integrated/,'permission stays on architecture only');
});
