import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preFixtureGridSource as pre,fixtureGridSourceProof as proof} from './helpers/fixture-grid-source.mjs';
import {preFixtureConstructionSource} from './helpers/fixture-construction-source.mjs';
import {preRawBindingSource} from './helpers/raw-binding-source.mjs';
import {preCurrentEntrySource} from './helpers/current-entry-source.mjs';
import {preDeliveryTargetSource} from './helpers/delivery-source-composition.mjs';
import {preIntegrationSource} from './helpers/pr372-integration-source.mjs';
const path='tests/lua/support/game_ui_fixture.lua',norm=s=>s.replaceAll('\r\n','\n'),read=p=>readFileSync(p,'utf8');
test('grid initialization order has an exact independent inverse without rewriting the accepted constructor proof',()=>{
 const live=norm(read(path)),prior=pre(path,live);
 assert.equal(createHash('sha256').update(prior).digest('hex'),proof.files[path].beforeSha256);
 assert.equal(pre(path,live.replaceAll('\n','\r\n')),prior);
 assert.equal(preFixtureConstructionSource(path,live),preFixtureConstructionSource(path,prior));
 for(const bad of [live+' ',live.slice(1),live.replace('local','Local'),live+'😀'])assert.equal(pre(path,bad),bad);
 assert.equal(pre('foreign/'+path,live),live);
});
test('new grid owner stays caller-owned and fresh through F raw runner and historical chains after warm success',()=>{
 const calls=[[path,pre],[path,preFixtureConstructionSource],['scripts/test-lua.mjs',preRawBindingSource],['scripts/test-lua.mjs',preCurrentEntrySource],[path,(p,s,o)=>preDeliveryTargetSource(p,s,'legacyUiSupport',o)],['scripts/test-lua.mjs',(p,s,o)=>preIntegrationSource(p,s,'base',o)]];
 for(const[host,project]of calls){
  const source=read(host);let current=read(path),reads=0;const readSource=p=>{if(p===path){reads++;return current;}return read(p);};
  project(host,source,{readSource});const warm=reads;assert(warm>0);
  for(const bad of [current+' ',current.replace('local','Local'),undefined]){current=bad;assert.throws(()=>project(host,source,{readSource}),/linked source/);}
  assert(reads>warm);current=read(path);project(host,source,{readSource});
  assert.throws(()=>project(host,source,{readSource:p=>{if(p===path)throw Error('missing');return read(p);}}),/linked source/);
 }
});
