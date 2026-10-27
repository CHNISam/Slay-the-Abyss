import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runLua } from '../scripts/test-lua.mjs';
const source=JSON.parse(readFileSync('tests/fixtures/addict-source-contract.json','utf8'));
test('Addict pins original source price, Shame, screenless queue and distinct acquire/equip lifecycle',()=>{
  assert.equal(source.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
  const event=source.sources.find(s=>s.path==='events/city/Addict.java');
  assert.equal(event.gitBlobSha,'be0299d90e2736c21a559f9cdfe81fa4d5baabef');
  assert.equal(source.sources.length,14);
  for(const s of source.sources){assert.match(s.gitBlobSha,/^[a-f0-9]{40}$/);assert.match(s.sha256,/^[a-f0-9]{64}$/);assert.ok(s.size>0);assert.ok(s.url.includes(`/blob/${source.sourceCommit}/`));}
  assert.equal(source.behavior.goldCost,85);assert.equal(source.behavior.curseId,'Shame');
  assert.deepEqual(source.behavior.introChoices,['buy','steal','leave']);
  assert.deepEqual(source.behavior.buyOrder,['selectScreenlessRelic','lose85Gold','acquireRelicOwnership','resultScreen','separateLeave']);
  assert.deepEqual(source.behavior.stealOrder,['selectScreenlessRelic','prepareShameOldOmamori','acquireRelicOwnership','resultScreen']);
  assert.deepEqual(source.behavior.delayedCardOrder,['currentRelicOnObtainHooks','masterDeckInsertion']);
  assert.match(source.behavior.sourceScreenTiming,/immediately/);assert.match(source.behavior.sourceScreenTiming,/atomically settle/);
  assert.deepEqual(source.behavior.screenlessRejects,['Bottled Flame','Bottled Lightning','Bottled Tornado','Whetstone']);
  assert.match(source.behavior.nativeLifecycle,/does not call onEquip/);assert.match(source.behavior.nativeLifecycle,/No native onEquip-before-card timing claim/);
  assert.match(source.implementationBoundary,/NodeUI wired with mocked-local/);
  assert.match(source.implementationBoundary,/history producer\/persistence UNWIRED/);assert.match(source.implementationBoundary,/NOT_RUN/);
});
test('Addict uses the already implemented exact Shame definition, without new card mechanics',()=>{
  const cards=JSON.parse(readFileSync('data/cards.json','utf8')).cards;
  const shame=cards.find(c=>c.id==='shame');
  assert.equal(shame.sts_name,'Shame');assert.equal(shame.type,'curse');assert.equal(shame.rarity,'curse');assert.equal(shame.cost,-2);
  assert.equal(shame.endTurnStatusAmount,1);assert.deepEqual(shame.effects,[]);assert.equal(shame.upgrade,undefined);
});
test('Addict public Nodes commands preserve original rewards, screens, old/new relic hooks and rollback',()=>{
  const result=runLua('tests/lua/addict_event_content.lua');
  assert.equal(result.status,0,result.stderr||result.stdout);assert.match(result.stdout,/ADDICT_EVENT_CONTENT 23 passed/);
});
