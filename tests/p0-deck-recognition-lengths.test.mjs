import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {p0DeckRecognitionLengths} from './helpers/p0-deck-recognition-lengths.mjs';
import {p0UiSourceProof,preP0UiSource} from './helpers/p0-ui-source.mjs';
import {deckDeliveryProof,preDeckDeliverySource} from './helpers/deck-delivery-source-composition.mjs';
import {preFinalUiSource} from './helpers/final-ui-source.mjs';
import {preDeckVisibilitySource} from './helpers/deck-visibility-source.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const read=p=>readFileSync(p,'utf8');
const definitions=[
 ['p0',p0UiSourceProof.files,(p,s)=>preFinalUiSource(p,s),preP0UiSource],
 ['deck',deckDeliveryProof.targets.delivery.files,(p,s)=>preDeckVisibilitySource(p,preP0UiSource(p,s)),(p,s,o)=>preDeckDeliverySource(p,s,'delivery',o)],
];
function sourcesFor(bindings,prepare){
 const sources=new Map(Object.keys(bindings).map(p=>[p,normalize(prepare(p,read(p)))]));
 return {sources,readSource:p=>sources.has(p)?sources.get(p):read(p)};
}
test('all 14 P0/deck recognition lengths bind complete fixed SHA and Git blob, including CRLF and latest sources',()=>{
 let count=0,unicode=0;
 for(const [group,bindings,prepare,project]of definitions){
  const {sources,readSource}=sourcesFor(bindings,prepare);
  for(const [p,b]of Object.entries(bindings)){
   const s=sources.get(p),record=p0DeckRecognitionLengths.groups[group].files[p];
   assert.equal(hash(s),b.afterSha256);assert.equal(blob(s),b.afterGitBlob);assert.equal(s.length,record.utf16Length);
   assert.equal(record.afterSha256,b.afterSha256);assert.equal(record.afterGitBlob,b.afterGitBlob);
   const previous=project(p,s,{readSource});assert.equal(hash(previous),b.beforeSha256);
   assert.equal(project(p,s.replaceAll('\n','\r\n'),{readSource}),previous);
   assert.equal(project(p,read(p)),previous,'the newest live source still passes its full outer and linked checks');
   count++;if(Buffer.byteLength(s)!==s.length)unicode++;
  }
 }
 assert.equal(count,14);assert.ok(unicode>0);assert.ok(Object.isFrozen(p0DeckRecognitionLengths));
});
test('unknown, unequal-length, same-length ASCII and Unicode bytes cannot borrow a recognition length',()=>{
 let count=0;
 for(const [,bindings,prepare,project]of definitions){
  const {sources,readSource}=sourcesFor(bindings,prepare);
  for(const [p,s]of sources){
   for(const bad of ['-- unknown\n',s+'\n',s.slice(1),(s[0]==='X'?'Y':'X')+s.slice(1),'界'+s.slice(1),'🙂'+s.slice(2)]){
    assert.notEqual(bad,s);assert.equal(project(p,bad,{readSource}),bad,p);count++;
   }
  }
 }
 assert.equal(count,84);
});
test('successful warm projections still reread caller owners and reject drift or missing sources; deck subset retains the same identity',()=>{
 let rejected=0;
 for(const [,bindings,prepare,project]of definitions){
  const {sources,readSource}=sourcesFor(bindings,prepare);
  for(const [p,s]of sources){
   project(p,s,{readSource});const linked=[...sources.keys()].find(q=>q!==p);
   assert.throws(()=>project(p,s,{readSource:q=>q===linked?'界'+readSource(q).slice(1):readSource(q)}));
   assert.throws(()=>project(p,s,{readSource:q=>{if(q===linked)throw Error('missing linked source');return readSource(q);}}));
   rejected+=2;
  }
 }
 assert.equal(rejected,28);
 const [,bindings,prepare]=definitions[1],{sources,readSource}=sourcesFor(bindings,prepare);
 for(const [p,b]of Object.entries(deckDeliveryProof.targets.deck.files)){
  assert.equal(b.afterSha256,bindings[p].afterSha256);assert.equal(b.afterGitBlob,bindings[p].afterGitBlob);
  assert.equal(hash(preDeckDeliverySource(p,sources.get(p),'deck',{readSource})),b.beforeSha256);
 }
});
