import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runLua} from '../scripts/test-lua.mjs';
test('formal ending admission source reward order and late failures preserve all mutable owners',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/ending_route_contracts.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/ENDING_ROUTE_CONTRACTS_PASS 5 groups/);
});
test('ending source provenance pins final rooms reward exclusion and last-card defeat contract',()=>{
 const lock=JSON.parse(readFileSync('tests/fixtures/ending-route-source.json','utf8'));
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.files['rooms/AbstractRoom.java'].sha256,'020f4a0fc3a564f6e45604e5dba582a773a5b9fdb471f8488a2bf8c2354d3a05');
 assert.equal(Object.keys(lock.files).length,11);
 assert.deepEqual(lock.contracts,{camp:52,shop:53,elite:54,heart:55,rewardOrder:['gold','relic','potion','cards'],
  heartVisibleRewards:false,heartHiddenMiscDraws:1,endingRequiresProceed:true,
  simultaneousDeath:'defeat unless real fatal-interception survives',lizardTailImplemented:false});
});
