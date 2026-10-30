import {preArtFeatureSource} from './helpers/art-feature-source-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preBetaSource,betaSources} from './helpers/beta-integration-source.mjs';
import {preBetaHostSource} from './helpers/beta-delivery-host-source.mjs';
import {preMultiHistoricalUiTest,multiHistoricalUiTests} from './helpers/multi-historical-ui-tests.mjs';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n'),hash=s=>createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
test('all archived beta hosts and both destinations bind current delivery without changing frozen witnesses',()=>{
 for(const[p,b]of Object.entries(betaSources)){
  assert.equal(hash(preBetaHostSource(p,read(p))),b.sha256,p);
  for(const[t,d]of Object.entries(b.targets)){
   const value=preBetaSource(p,read(p),t);
   assert.equal(value===null?null:hash(value),d.absent?null:d.sha256,p+':'+t);
   const mutant=read(p)+'\n-- foreign\n';assert.equal(preBetaSource(p,mutant,t),mutant);
  }
 }
 for(const[p,sha]of Object.entries({
 'art-feature-source-layer-pre379.json':'33ad4cabfe6a3b678a7054f39975bca56e122ecc5ca2c3ad945392eb77b22afc',
 'art-feature-source-layer.json':'b2bef34f482a5eca07b74a10d5ca31f04a5256a6b3a3d249ff8597a7b5962a30',
 'beta-integration-sources.json':'ce3402eb178847948c88f90d785fc89cd72bb3a87f136e8be56b8c1dc36223a3'
 }))assert.equal(hash(readFileSync(new URL('./fixtures/'+p,import.meta.url),'utf8')),sha);
});
test('warm beta projections still re-read linked owners and reject unknown or missing bytes',()=>{
 const p='scripts/build-ui.mjs',s=read(p);
 preBetaSource(p,s,'feature379');
 for(const[q,b]of Object.entries(betaSources).filter(([,b])=>b.targets.history.absent)){
  for(const changed of [undefined,read(q)+'\n-- foreign\n']){
   assert.throws(()=>preBetaSource(p,s,'feature379',{readSource:r=>r===q?changed:read(r)}),undefined,q);
  }
 }
});
test('dynamic-monster historical UI tests retreat only exact reviewed whole sources',()=>{
 for(const[p,b]of Object.entries(multiHistoricalUiTests.files)){
  const s=read(p),before=preMultiHistoricalUiTest(p,s);
  assert.equal(hash(s),b.afterSha256);assert.equal(hash(before),b.beforeSha256);
  assert.equal(preMultiHistoricalUiTest(p,before),before);
  assert.equal(preMultiHistoricalUiTest(p,s.replaceAll('\n','\r\n')),before);
  const mutant=s+'\n-- unknown\n';assert.equal(preMultiHistoricalUiTest(p,mutant),mutant);
  assert.equal(preMultiHistoricalUiTest('wrong/path',s),s);
 }
});

test('public feature projections validate caller-owned beta sources in both target modes after warming',()=>{
 const path='scripts/build-ui.mjs',source=read(path);
 for(const history of [false,true]){
  preArtFeatureSource(path,source,{history});
  for(const [owner,binding]of Object.entries(betaSources).filter(([,b])=>b.targets.history.absent)){
   for(const changed of [undefined,read(owner)+'\n-- unreviewed caller owner\n']){
    const readSource=p=>p===owner?changed:read(p);
    assert.throws(()=>preArtFeatureSource(path,source,{history,readSource}),undefined,owner+' '+history);
   }
  }
 }
});
