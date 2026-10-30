import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runLua} from '../scripts/test-lua.mjs';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
test('live-round AI history acknowledges every completed presentation batch in-place',()=>{
 const source=read('tests/lua/jaw_worm_ai.lua');
 assert.equal(source.split('consumeEvents(s) -- acknowledge').length,2);
 const result=runLua('tests/lua/jaw_event_consumer_equivalence.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/LUA_JAW_EVENT_CONSUMER_EQUIVALENCE_PASS 2 seeds 4 rounds all fields and events/);
});
import {preJawEventConsumerSource,jawEventConsumerProof as proof} from './helpers/jaw-event-consumer-source.mjs';
test('event consumption has an exact inverse and rejects partial or foreign fixture changes',()=>{
 assert.equal(proof.base,'5fc58cc4767fea595e397d15fd10784b8d2b2714');
 assert.equal(proof.path,'tests/lua/jaw_worm_ai.lua');
 assert.deepEqual(proof.insertions,[
  '    local consumeEvents=dofile("tests/lua/support/jaw_event_consumer.lua").consume\n',
  '            consumeEvents(s) -- acknowledge the complete observed batch, as the UI does\n',
 ]);
 assert.equal(proof.beforeSha256,'a08bb7702e8f43c1b7e2eff75922d4c7c70ab0a884a5609ac77d971d4a8c7082');
 const raw=read(proof.path),old=preJawEventConsumerSource(raw);
 assert.equal(preJawEventConsumerSource(raw.replaceAll('\n','\r\n')),old);
 assert.equal(preJawEventConsumerSource(old),old);
 for(const bad of [raw+'\n',raw.slice(1),'x'+raw.slice(1),...proof.insertions.map(s=>raw.replace(s,''))])assert.throws(()=>preJawEventConsumerSource(bad),/exact current/);
 assert.equal(proof.insertions.reduce((s,line)=>s.replace(line,''),raw),old);
});
