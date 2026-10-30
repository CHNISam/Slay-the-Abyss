import test from 'node:test';import assert from'node:assert/strict';import{readFileSync}from'node:fs';import{createHash}from'node:crypto';
import{p0UiSourceProof as proof,p0UiSourcePaths as paths,preP0UiSource}from'./helpers/p0-ui-source.mjs';
import{preDeliveryTargetSource}from'./helpers/delivery-source-composition.mjs';
import{preDeckDeliverySource}from'./helpers/deck-delivery-source-composition.mjs';
import{preIntegrationSource}from'./helpers/pr372-integration-source.mjs';
const read=p=>readFileSync(p,'utf8'),hash=s=>createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
test('all seven P0 inputs retreat exactly and preserve every frozen before byte, including CRLF',()=>{
 assert.equal(paths.length,7);
 for(const p of paths){const raw=read(p),b=proof.files[p],before=preP0UiSource(p,raw);assert.equal(hash(raw),b.afterSha256);assert.equal(hash(before),b.beforeSha256);assert.equal(preP0UiSource(p,raw.replaceAll('\n','\r\n')),before);assert.equal(preP0UiSource(p,before),before);
 for(const bad of [raw+'\n',raw.slice(1),raw+raw,'界'+raw.slice(1)])assert.equal(preP0UiSource(p,bad),bad);
 for(const h of b.hunks)for(const replacement of [[],h.before,[...h.after,...h.after],['-- unknown']]){const lines=raw.split('\n');lines.splice(h.at,h.after.length,...replacement);const bad=lines.join('\n');if(bad!==raw)assert.equal(preP0UiSource(p,bad),bad);}
 assert.equal(preP0UiSource('foreign',raw),raw);
 }});
test('direct deck delivery and PR372 projections preserve caller-owned fresh identity after warming',()=>{
 const projections=[preP0UiSource,(p,s,o)=>preDeliveryTargetSource(p,s,'legacyMulti',o),(p,s,o)=>preDeckDeliverySource(p,s,'delivery',o),preIntegrationSource];
 for(const project of projections){const host='src/lua/abyss_game_ui.lua',raw=read(host);const call=(p,s,o)=>project===preIntegrationSource?project(p,s,'base',o):project(p,s,o);call(host,raw,{readSource:read});
  for(const owner of paths)for(const bad of [undefined,read(owner)+'\n-- drift']){const readSource=p=>p===owner?bad:read(p);assert.throws(()=>call(host,raw,{readSource}),/linked source/);}
 }
});
