import {preDeckBrowseSource} from './helpers/deck-browse-source-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {integrationSources,preIntegrationSource as prior} from './helpers/pr372-integration-source.mjs';
const read=p=>preDeckBrowseSource(p,readFileSync(p,'utf8')).replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
test('combined presentation projection recovers exact individual and base identities only',()=>{
 for(const [path,b] of Object.entries(integrationSources)){
  const live=read(path);assert.equal(hash(live),b.sha256,path);
  for(const [target,t] of Object.entries(b.targets)){
   const old=prior(path,live,target);
   assert.equal(old===null?null:hash(old),t.sha256,path+' '+target);
   assert.equal(prior(path,live+'\n-- drift',target),live+'\n-- drift');
   assert.equal(prior('unregistered/'+path,live,target),live);
  }
 }
});
test('combined host identity cannot authorize changed or missing added Lua responsibilities',()=>{
 const path='src/lua/abyss_battle_card_view.lua',live=read(path);
 for(const [linked,b] of Object.entries(integrationSources)){
  if(!linked.startsWith('src/lua/')||!b.targets.base?.absent)continue;
  assert.throws(()=>prior(path,live,'base',{readSource:p=>p===linked?read(p)+'\n-- drift':read(p)}),/unreviewed combined linked module/);
  assert.throws(()=>prior(path,live,'base',{readSource:p=>{if(p===linked)throw Error('missing linked module');return read(p);}}),/missing linked module/);
 }
});
