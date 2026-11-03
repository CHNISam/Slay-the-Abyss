import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,rmSync} from 'node:fs';
import {withHistoricalBaseline} from './helpers/historical-baseline-inputs.mjs';
import {deckDeliveryProof,deckDeliveryPaths,preDeckDeliverySource} from './helpers/deck-delivery-source-composition.mjs';
import {deliverySourceProof,preDeliveryTargetSource} from './helpers/delivery-source-composition.mjs';

const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
test('warm deck projections observe actual linked edits, deletion, recovery and a new historical cwd',()=>{
  const host=deckDeliveryPaths[0],linked=deckDeliveryPaths[1];let expected,firstRoot;
  withHistoricalBaseline(()=>{
    firstRoot=process.cwd();const input=read(host),original=read(linked);
    expected=preDeckDeliverySource(host,input);
    writeFileSync(linked,original+'\n-- linked drift\n');
    assert.throws(()=>preDeckDeliverySource(host,input),/linked source identity/);
    rmSync(linked);assert.throws(()=>preDeckDeliverySource(host,input),/linked source missing/);
    writeFileSync(linked,original);assert.equal(preDeckDeliverySource(host,input),expected);
  });
  withHistoricalBaseline(()=>{
    assert.notEqual(process.cwd(),firstRoot);const input=read(host);
    assert.equal(preDeckDeliverySource(host,input),expected);
    rmSync(linked);assert.throws(()=>preDeckDeliverySource(host,input),/linked source missing/);
  });
});
test('warm delivery projections reread callback owners and do not remember rejected inputs',()=>withHistoricalBaseline(()=>{
  const target='developEvents',files=deliverySourceProof.targets[target].files;
  const host=Object.keys(files).find(path=>files[path].beforeSha256!==null);
  const linked=Object.keys(files).find(path=>files[path].beforeSha256===null);
  assert.ok(host&&linked);
  const source=path=>preDeckDeliverySource(path,read(path));
  const input=source(host);let calls=0,bad=false;
  const readSource=path=>{if(path===linked){calls++;if(bad)throw Error('injected owner failure');}return source(path);};
  const expected=preDeliveryTargetSource(host,input,target,{readSource});const before=calls;
  bad=true;assert.throws(()=>preDeliveryTargetSource(host,input,target,{readSource}),/linked source missing/);
  assert.ok(calls>before);bad=false;
  assert.equal(preDeliveryTargetSource(host,input,target,{readSource}),expected);
  const raw=read(linked);writeFileSync(linked,raw+'\n-- actual drift\n');
  assert.throws(()=>preDeliveryTargetSource(host,input,target,{readSource}),/linked source identity/);
}));
test('both delivery projection policies and hunk witnesses remain deeply immutable',()=>{
  const frozen=value=>{if(value===null||typeof value!=='object')return;assert.ok(Object.isFrozen(value));for(const child of Object.values(value))frozen(child);};
  for(const proof of [deckDeliveryProof,deliverySourceProof]){
    frozen(proof);const binding=Object.values(Object.values(proof.targets)[0].files).find(binding=>binding.hunks.length);
    assert.throws(()=>binding.hunks[0].after.push('unreviewed'),TypeError);
  }
});
