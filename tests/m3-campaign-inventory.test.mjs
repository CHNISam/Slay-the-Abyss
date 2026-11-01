import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
import {runLua} from '../scripts/test-lua.mjs';
test('current two-act ledger contains actual Act2 weighted bindings, definitions and all source Boss bindings',()=>{
 const result=runLua('scripts/m3-content-inventory.lua');assert.equal(result.status,0,result.stderr);
 const runtime=JSON.parse(result.stdout.split('M3_CONTENT ')[1]);
 const ledger=JSON.parse(readFileSync('data/release/m3-campaign.json'));
 assert.deepEqual(ledger.acts.find(a=>a.act===2).runtimeInventory,runtime.act2);
 assert.deepEqual(ledger.currentReleaseScope.act1Bosses,runtime.act1Bosses);
 assert.deepEqual(ledger.currentReleaseScope.characters,['ironclad']);assert.deepEqual(ledger.currentReleaseScope.acts,[1,2]);
 assert.equal(runtime.act2.queueSources.length,16);assert.equal(runtime.act2.enemyDefinitions.length,20);
 assert.equal(runtime.act2.bosses.length,3);assert.equal(runtime.act1Bosses.length,3);
 assert.equal(ledger.officialImport,'NOT_RUN');assert.equal(ledger.platformStatus,'NOT_RUN');
});
