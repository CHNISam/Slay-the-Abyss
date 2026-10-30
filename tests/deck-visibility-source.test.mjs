import {preDeckDeliverySource} from './helpers/deck-delivery-source-composition.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preDeckVisibilitySource,deckVisibilitySourceProof} from './helpers/deck-visibility-source.mjs';
import {prePostBetaRuntimeSource} from './helpers/post-beta-runtime-source.mjs';
const path='src/lua/abyss_deck_ui.lua',raw=readFileSync(path,'utf8').replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
test('deck boolean boundary restores the exact historical source and rereads caller ownership',()=>{
 const b=deckVisibilitySourceProof.files[path];
 assert.equal(hash(raw),b.afterSha256);
 for(const project of [preDeckVisibilitySource,prePostBetaRuntimeSource]){
  const prior=project(path,raw,{readSource:p=>p===path?raw:undefined});
  assert.equal(hash(prior),b.beforeSha256);
  assert.equal(project(path,prior),prior);
  assert.equal(project(path,raw.replaceAll('\n','\r\n'),{readSource:()=>raw}),prior);
  for(const owner of [undefined,'',raw+'\n-- drift',raw.replace('self.visible == true','self.visible ~= true')])assert.throws(()=>project(path,raw,{readSource:()=>owner}),/deck-visibility linked/);
 }
 for(const unknown of [raw+'\n-- drift',raw.slice(1),raw.replace('self.visible == true','self.visible')])assert.equal(preDeckVisibilitySource(path,unknown),unknown);
 assert.equal(preDeckVisibilitySource('unregistered.lua',raw),raw);
});

test('both older deck targets reread caller-owned current Deck bytes after warm projection',()=>{
 const good=p=>readFileSync(p,'utf8');
 const sameLength=raw.replace('self.visible == true','self.visible ~= true');
 assert.equal(sameLength.length,raw.length);assert.notEqual(sameLength,raw);
 for(const target of ['delivery','deck']){
  const prior=preDeckVisibilitySource(path,raw,{readSource:good});
  for(const source of [raw,prior]){
   preDeckDeliverySource(path,source,target,{readSource:good});
   for(const bad of [undefined,'',sameLength,raw+'\n-- foreign']){
    const replacement=p=>p===path?bad:good(p);
    assert.throws(()=>preDeckDeliverySource(path,source,target,{readSource:replacement}),/linked source/);
   }
  }
 }
});
