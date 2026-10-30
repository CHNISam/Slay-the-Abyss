import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {entryRecognitionLengths} from './helpers/entry-recognition-lengths.mjs';
import {postBetaRuntimeProof,prePostBetaRuntimeSource} from './helpers/post-beta-runtime-source.mjs';
import {phaseFourRunnerProof,prePhaseFourRunnerSource} from './helpers/phase-four-runner-source.mjs';
import {currentEntrySourceProof,preCurrentEntrySource} from './helpers/current-entry-source.mjs';
import {preArtifactRuntimeSource} from './helpers/artifact-runtime-source.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const read=p=>readFileSync(p,'utf8');
const definitions=[
 ['post-beta-runtime',postBetaRuntimeProof.files,(p,s)=>preArtifactRuntimeSource(p,s),prePostBetaRuntimeSource,Object.keys(postBetaRuntimeProof.files)],
 ['phase-four-runner',{[phaseFourRunnerProof.path]:phaseFourRunnerProof},(p,s)=>preCurrentEntrySource(p,s),prePhaseFourRunnerSource,Object.keys(phaseFourRunnerProof.linkedSources)],
 ['current-entry',currentEntrySourceProof.files,(p,s)=>s,preCurrentEntrySource,[...Object.keys(currentEntrySourceProof.files),...Object.keys(currentEntrySourceProof.linkedSources)]],
];
function sourcesFor(bindings,prepare){
 const sources=new Map(Object.keys(bindings).map(p=>[p,normalize(prepare(p,read(p)))]));
 return {sources,readSource:p=>sources.has(p)?sources.get(p):read(p)};
}
test('all five entry recognition lengths bind full fixed SHA and Git blob, CRLF and latest sources',()=>{
 let count=0,unicode=0;
 for(const [group,bindings,prepare,project]of definitions){
  const {sources,readSource}=sourcesFor(bindings,prepare);
  for(const [p,b]of Object.entries(bindings)){
   const s=sources.get(p),record=entryRecognitionLengths.groups[group].files[p];
   assert.equal(hash(s),b.afterSha256);assert.equal(blob(s),b.afterGitBlob);assert.equal(s.length,record.utf16Length);
   assert.equal(record.afterSha256,b.afterSha256);assert.equal(record.afterGitBlob,b.afterGitBlob);
   const previous=project(p,s,{readSource});assert.equal(hash(previous),b.beforeSha256);
   assert.equal(project(p,s.replaceAll('\n','\r\n'),{readSource}),previous);
   assert.equal(project(p,read(p)),previous,'latest sources still execute the full outer and owner checks');
   count++;if(Buffer.byteLength(s)!==s.length)unicode++;
  }
 }
 assert.equal(count,5);assert.ok(unicode>0);assert.ok(Object.isFrozen(entryRecognitionLengths));
});
test('unknown and unequal-length sources or same-length ASCII and Unicode mutants cannot borrow entry permissions',()=>{
 let count=0;
 for(const [,bindings,prepare,project]of definitions){
  const {sources,readSource}=sourcesFor(bindings,prepare);
  for(const [p,s]of sources)for(const bad of ['-- unknown\n',s+'\n',s.slice(1),(s[0]==='X'?'Y':'X')+s.slice(1),'界'+s.slice(1),'🙂'+s.slice(2)]){
   assert.notEqual(bad,s);assert.equal(project(p,bad,{readSource}),bad,p);count++;
  }
 }
 assert.equal(count,30);
});
test('warm entry recognition rereads caller owners and still rejects same-length drift or missing owners',()=>{
 let rejected=0;
 for(const [,bindings,prepare,project,owners]of definitions){
  const {sources,readSource}=sourcesFor(bindings,prepare);
  for(const [p,s]of sources){
   project(p,s,{readSource});
   for(const linked of owners){
    assert.throws(()=>project(p,s,{readSource:q=>q===linked?'界'+readSource(q).slice(1):readSource(q)}));
    assert.throws(()=>project(p,s,{readSource:q=>{if(q===linked)throw Error('missing linked source');return readSource(q);}}));
    rejected+=2;
   }
  }
 }
 assert.equal(rejected,36);
});
