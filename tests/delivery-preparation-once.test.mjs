import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {historicalTest} from './helpers/historical-baseline-inputs.mjs';
import {preDeckDeliverySource,deckDeliveryPaths} from './helpers/deck-delivery-source-composition.mjs';
import {preDeliveryTargetSource,tryDeliverySource,deliverySourceProof} from './helpers/delivery-source-composition.mjs';

// Instrument the real imported preparer, not a replacement oracle. The private
// implementation remains private; only this test module exposes the count.
const helper=new URL('./helpers/delivery-source-composition.mjs',import.meta.url);
const original=readFileSync(helper,'utf8');
const anchor="import {preDeckDeliverySource,deckDeliveryPaths} from './deck-delivery-source-composition.mjs';";
assert.equal(original.split(anchor).length,2);
const instrumented=original.replace(anchor,"import {preDeckDeliverySource as prepare,deckDeliveryPaths} from './deck-delivery-source-composition.mjs';\nlet preparationCalls=0;\nfunction preDeckDeliverySource(...args){preparationCalls++;return prepare(...args);}\nexport const preparationCount=()=>preparationCalls;")
 .replace(/from '(\.\/[^']+)'/g,(_,path)=>`from '${new URL(path,helper).href}'`)
 .replaceAll('import.meta.url',JSON.stringify(helper.href));
const measured=await import('data:text/javascript;base64,'+Buffer.from(instrumented).toString('base64'));

test('delivery wrapper and direct try each prepare the input exactly once',()=>{
 for(const entry of ['preDeliveryTargetSource','tryDeliverySource']){
  const before=measured.preparationCount();
  measured[entry]('src/lua/abyss_game_ui.lua','unknown source','develop');
  assert.equal(measured.preparationCount()-before,1,entry+' repeats deck input preparation');
 }
});

function priorWrapper(path,source,target,options){
 source=preDeckDeliverySource(path,source,'delivery',options);
 const prior=tryDeliverySource(path,source,target,options);
 return prior===undefined?source:prior;
}
function observe(project,path,source,target,read){
 const events=[];
 const options={get readSource(){events.push('get reader');return p=>{events.push(p);return read(p,events);};}};
 try{return {value:project(path,source,target,options),events};}
 catch(error){return {error:{name:error.name,message:error.message,code:error.code},events};}
}

historicalTest('one preparation preserves exact sources, options access, errors and linked read order',()=>{
 const read=p=>readFileSync(p,'utf8');
 for(const path of deckDeliveryPaths){
  const live=read(path).replaceAll('\r\n','\n');
  const prior=preDeckDeliverySource(path,live);
  for(const target of [...Object.keys(deliverySourceProof.targets),'unknown-target']){
   for(const source of [live,live.replaceAll('\n','\r\n'),prior,live+'\n',live.slice(1),null,undefined]){
    assert.deepEqual(observe(preDeliveryTargetSource,path,source,target,read),observe(priorWrapper,path,source,target,read));
   }
  }
 }
 for(const source of ['foreign',null])assert.deepEqual(observe(preDeliveryTargetSource,'foreign/path',source,'develop',read),observe(priorWrapper,'foreign/path',source,'develop',read));
 for(const options of [null]){
  assert.throws(()=>preDeliveryTargetSource('foreign','raw','develop',options),TypeError);
  assert.throws(()=>priorWrapper('foreign','raw','develop',options),TypeError);
 }
});

historicalTest('every public call still checks each live owner after success and getter failures propagate',()=>{
 const read=p=>readFileSync(p,'utf8');
 const path=deckDeliveryPaths[0],source=read(path);
 for(const project of [preDeliveryTargetSource,tryDeliverySource]){
  for(const linked of deckDeliveryPaths){
   let invalid=false;const reader=p=>p===linked&&invalid?read(p)+'\n':read(p);
   project(path,source,'develop',{readSource:reader});invalid=true;
   for(let i=0;i<2;i++)assert.throws(()=>project(path,source,'develop',{readSource:reader}),/linked source/);
   assert.throws(()=>project(path,source,'develop',{readSource:p=>{if(p===linked)throw Error('missing');return read(p);}}),/linked source missing/);
  }
 }
 for(const at of [1,2]){
  const observeGetter=project=>{let calls=0;const failure=new Error('getter '+at);try{project(path,source,'develop',{get readSource(){if(++calls===at)throw failure;return read;}});assert.fail('getter exception swallowed');}catch(error){assert.equal(error,failure);return calls;}};
  assert.equal(observeGetter(preDeliveryTargetSource),observeGetter(priorWrapper));
 }
 // A stateful reader can change at any read. Compare exact old/new errors and
 // complete read traces rather than assuming a snapshot across owner checks.
 for(let at=1;at<=deckDeliveryPaths.length*2;at++){
  const changing=()=>{let count=0;return p=>++count>=at?read(p)+'\n':read(p);};
  assert.deepEqual(observe(preDeliveryTargetSource,path,source,'develop',changing()),observe(priorWrapper,path,source,'develop',changing()));
 }
});
