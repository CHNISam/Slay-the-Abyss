import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runtimeRecognitionLengths} from './helpers/runtime-recognition-lengths.mjs';
import {artifactRuntimeProof,preArtifactRuntimeSource} from './helpers/artifact-runtime-source.mjs';
import {deckVisibilitySourceProof,preDeckVisibilitySource} from './helpers/deck-visibility-source.mjs';
import {deathAudioSourceProof,preDeathAudioSource} from './helpers/death-audio-source.mjs';
import {preFinalUiSource} from './helpers/final-ui-source.mjs';
import {prePhaseFourRunnerSource} from './helpers/phase-four-runner-source.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const read=p=>readFileSync(p,'utf8');
const definitions=[
 ['artifact-runtime',artifactRuntimeProof.files,(p,s)=>prePhaseFourRunnerSource(p,preFinalUiSource(p,s)),preArtifactRuntimeSource],
 ['deck-visibility',deckVisibilitySourceProof.files,(p,s)=>s,preDeckVisibilitySource],
 ['death-audio',deathAudioSourceProof.files,(p,s)=>s,preDeathAudioSource],
];
function sourcesFor(bindings,prepare){
 const sources=new Map(Object.keys(bindings).map(p=>[p,normalize(prepare(p,read(p)))]));
 return {sources,readSource:p=>sources.has(p)?sources.get(p):read(p)};
}
test('all six runtime recognition lengths bind full fixed SHA and Git blob, CRLF and latest sources',()=>{
 let count=0,unicode=0;
 for(const [group,bindings,prepare,project]of definitions){
  const {sources,readSource}=sourcesFor(bindings,prepare);
  for(const [p,b]of Object.entries(bindings)){
   const s=sources.get(p),record=runtimeRecognitionLengths.groups[group].files[p];
   assert.equal(hash(s),b.afterSha256);assert.equal(blob(s),b.afterGitBlob);assert.equal(s.length,record.utf16Length);
   assert.equal(record.afterSha256,b.afterSha256);assert.equal(record.afterGitBlob,b.afterGitBlob);
   const previous=project(p,s,{readSource});assert.equal(hash(previous),b.beforeSha256);
   assert.equal(project(p,s.replaceAll('\n','\r\n'),{readSource}),previous);
   assert.equal(project(p,read(p)),previous,'latest sources still execute the full outer and owner checks');
   count++;if(Buffer.byteLength(s)!==s.length)unicode++;
  }
 }
 assert.equal(count,6);assert.ok(unicode>0);assert.ok(Object.isFrozen(runtimeRecognitionLengths));
});
test('unknown and unequal-length sources or same-length ASCII and Unicode mutants cannot borrow runtime permissions',()=>{
 let count=0;
 for(const [,bindings,prepare,project]of definitions){
  const {sources,readSource}=sourcesFor(bindings,prepare);
  for(const [p,s]of sources)for(const bad of ['-- unknown\n',s+'\n',s.slice(1),(s[0]==='X'?'Y':'X')+s.slice(1),'界'+s.slice(1),'🙂'+s.slice(2)]){
   assert.notEqual(bad,s);assert.equal(project(p,bad,{readSource}),bad,p);count++;
  }
 }
 assert.equal(count,36);
});
test('warm runtime recognition rereads caller owners and still rejects same-length drift or missing owners',()=>{
 let rejected=0;
 for(const [,bindings,prepare,project]of definitions){
  const {sources,readSource}=sourcesFor(bindings,prepare);
  for(const [p,s]of sources){
   project(p,s,{readSource});
   for(const linked of sources.keys()){
    assert.throws(()=>project(p,s,{readSource:q=>q===linked?'界'+readSource(q).slice(1):readSource(q)}));
    assert.throws(()=>project(p,s,{readSource:q=>{if(q===linked)throw Error('missing linked source');return readSource(q);}}));
    rejected+=2;
   }
  }
 }
 assert.equal(rejected,36);
});
