import test from 'node:test';import assert from'node:assert/strict';import{readFileSync}from'node:fs';import{createHash}from'node:crypto';
import{finalUiSourceProof as proof,finalUiSourcePaths as paths,preFinalUiSource}from'./helpers/final-ui-source.mjs';
import{preDeliveryTargetSource}from'./helpers/delivery-source-composition.mjs';
import{preDeckDeliverySource}from'./helpers/deck-delivery-source-composition.mjs';
import{preIntegrationSource}from'./helpers/pr372-integration-source.mjs';
const read=p=>readFileSync(p,'utf8'),hash=s=>createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
test('all seven final UI inputs retreat exactly and preserve every frozen before byte, including CRLF',()=>{
 assert.equal(paths.length,8);
 for(const p of paths){const raw=read(p).replaceAll('\r\n','\n'),b=proof.files[p],before=preFinalUiSource(p,raw);assert.equal(raw.length,b.afterUtf16Length);assert.equal(hash(raw),b.afterSha256);assert.equal(hash(before),b.beforeSha256);assert.equal(preFinalUiSource(p,raw.replaceAll('\n','\r\n')),before);assert.equal(preFinalUiSource(p,before),before);
 for(const bad of [raw+'\n',raw.slice(1),raw+raw,'界'+raw.slice(1)])assert.equal(preFinalUiSource(p,bad),bad);
 for(const h of b.hunks)for(const replacement of [[],h.before,[...h.after,...h.after],['-- unknown']]){const lines=raw.split('\n');lines.splice(h.at,h.after.length,...replacement);const bad=lines.join('\n');if(bad!==raw)assert.equal(preFinalUiSource(p,bad),bad);}
 assert.equal(preFinalUiSource('foreign',raw),raw);
 }});
test('direct deck delivery and PR372 projections preserve caller-owned fresh identity after warming',()=>{
 const projections=[preFinalUiSource,(p,s,o)=>preDeliveryTargetSource(p,s,'legacyMulti',o),(p,s,o)=>preDeckDeliverySource(p,s,'delivery',o),preIntegrationSource];
 for(const project of projections){const host='src/lua/abyss_game_ui.lua',raw=read(host);const call=(p,s,o)=>project===preIntegrationSource?project(p,s,'base',o):project(p,s,o);call(host,raw,{readSource:read});
  for(const owner of paths)for(const bad of [undefined,read(owner)+'\n-- drift']){const readSource=p=>p===owner?bad:read(p);assert.throws(()=>call(host,raw,{readSource}),/linked source/);}
 }
});

import {verifiedHistoricalMonsterSources} from './helpers/historical-monster-ui-materialize.mjs';
test('historical UI restores the guide together with the old theme instead of leaving the current guide',()=>{
 const output=new Map(verifiedHistoricalMonsterSources());
 const p='scripts/controls-guide-layout.mjs';assert.ok(output.has(p));
 assert.equal(hash(output.get(p)),proof.files[p].beforeSha256);assert.notEqual(output.get(p),read(p));
});
