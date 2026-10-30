import test from'node:test';import assert from'node:assert/strict';import{readFileSync}from'node:fs';import{createHash}from'node:crypto';
import{fixtureConstructionSourceProof as proof,preFixtureConstructionSource as project}from'./helpers/fixture-construction-source.mjs';
import{preCurrentEntrySource}from'./helpers/current-entry-source.mjs';import{prePhaseFourRunnerSource}from'./helpers/phase-four-runner-source.mjs';
import{preDeliveryTargetSource}from'./helpers/delivery-source-composition.mjs';import{preIntegrationSource}from'./helpers/pr372-integration-source.mjs';
import{verifiedHistoricalMonsterSources}from'./helpers/historical-monster-ui-materialize.mjs';
const p='tests/lua/support/game_ui_fixture.lua',read=p=>readFileSync(p,'utf8'),sha=s=>createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
test('one exact F construction-order change retreats bidirectionally without accepting partial or same-length foreign bytes',()=>{
 const raw=read(p).replaceAll('\r\n','\n'),b=proof.files[p],old=project(p,raw);assert.equal(raw.length,b.afterUtf16Length);assert.equal(sha(raw),b.afterSha256);assert.equal(sha(old),b.beforeSha256);assert.equal(project(p,old),old);assert.equal(project(p,raw.replaceAll('\n','\r\n')),old);
 for(const bad of [raw+'\n',raw.slice(1),raw+raw,'界'+raw.slice(1),'🙂'+raw.slice(2)])assert.equal(project(p,bad),bad);
 for(const h of b.hunks)for(const replacement of [[],h.before,[...h.after,...h.after],['-- unknown']]){const lines=raw.split('\n');lines.splice(h.at,h.after.length,...replacement);const bad=lines.join('\n');if(bad!==raw)assert.equal(project(p,bad),bad);}
 assert.equal(project('wrong',raw),raw);
});
test('warm direct F and runner public projections re-read the caller-owned F on every invocation',()=>{
 for(const[host,call]of [[p,project],['scripts/test-lua.mjs',preCurrentEntrySource],['scripts/test-lua.mjs',prePhaseFourRunnerSource],[p,(p,s,o)=>preDeliveryTargetSource(p,s,'legacyUiSupport',o)],['scripts/test-lua.mjs',(p,s,o)=>preIntegrationSource(p,s,'base',o)]]){
  const raw=read(host);call(host,raw,{readSource:read});
  for(const bad of [undefined,read(p)+'\n-- changed']){const reader=q=>q===p?bad:read(q);assert.throws(()=>call(host,raw,{readSource:reader}),/linked source/);}
 }
 const historical=new Map(verifiedHistoricalMonsterSources());const expected=JSON.parse(read('tests/fixtures/historical-monster-ui-support.json')).files[p];assert.equal(sha(historical.get(p)),expected.beforeSha256);
});
