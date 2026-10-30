import test from'node:test';import assert from'node:assert/strict';import{readFileSync}from'node:fs';import{createHash}from'node:crypto';
import{rawBindingSourceProof as proof,rawBindingSourcePaths as paths,preRawBindingSource as project}from'./helpers/raw-binding-source.mjs';
import{preCurrentEntrySource}from'./helpers/current-entry-source.mjs';import{preSelectorCurrentSource}from'./helpers/selector-current-source.mjs';import{preDeliveryTargetSource}from'./helpers/delivery-source-composition.mjs';import{preIntegrationSource}from'./helpers/pr372-integration-source.mjs';
const read=p=>readFileSync(p,'utf8'),sha=s=>createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
test('five current raw-binding inputs restore exact complete pre-change sources and reject partial or same-length mutations',()=>{
 assert.equal(paths.length,5);assert.equal(Object.keys(proof.linkedSources).length,5);
 for(const p of paths){const raw=read(p).replaceAll('\r\n','\n'),b=proof.files[p],old=project(p,raw);assert.equal(raw.length,b.afterUtf16Length);assert.equal(sha(raw),b.afterSha256);assert.equal(sha(old),b.beforeSha256);assert.equal(project(p,old),old);assert.equal(project(p,raw.replaceAll('\n','\r\n')),old);assert.equal(project('foreign',raw),raw);
 for(const bad of [raw+'\n',raw.slice(1),raw+raw,'界'+raw.slice(1),'🙂'+raw.slice(2)])assert.equal(project(p,bad),bad);
 for(const h of b.hunks)for(const replacement of [[],h.before,[...h.after,...h.after],['-- unknown']]){const lines=raw.split('\n');lines.splice(h.at,h.after.length,...replacement);const bad=lines.join('\n');if(bad!==raw)assert.equal(project(p,bad),bad);}
 }
});
test('new helper JSON producer and F owners stay live and caller-owned through all public runner selector and historical entries',()=>{
 const owners=[...paths,...Object.keys(proof.linkedSources)];
 for(const[host,call]of [['scripts/test-lua.mjs',project],['scripts/test-lua.mjs',preCurrentEntrySource],['scripts/test-affected.mjs',preSelectorCurrentSource],['scripts/test-lua.mjs',(p,s,o)=>preDeliveryTargetSource(p,s,'legacyMulti',o)],['scripts/test-affected.mjs',(p,s,o)=>preIntegrationSource(p,s,'base',o)]]){
  const raw=read(host);call(host,raw,{readSource:read});for(const owner of owners)for(const bad of [undefined,read(owner)+'\n-- drift'])assert.throws(()=>call(host,raw,{readSource:p=>p===owner?bad:read(p)}),/linked source|UTF|strictly equal/);
 }
});
