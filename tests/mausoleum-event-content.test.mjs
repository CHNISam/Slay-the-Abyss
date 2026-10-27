import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runLua } from '../scripts/test-lua.mjs';

const source=JSON.parse(readFileSync('tests/fixtures/mausoleum-source-contract.json','utf8'));
test('Mausoleum contract records exact pinned primary-source Git blobs and A0 ordering',()=>{
  assert.equal(source.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
  const event=source.sources.find(s=>s.path==='events/city/TheMausoleum.java');
  assert.equal(event.gitBlobSha,'8e0e1eed6cada5587d376e6a3237d25d57429299');
  assert.equal(event.size,4080);
  assert.equal(source.sources.length,11);
  for(const entry of source.sources){
    assert.match(entry.url,new RegExp(`/blob/${source.sourceCommit}/`));
    assert.match(entry.gitBlobSha,/^[a-f0-9]{40}$/);assert.match(entry.sha256,/^[a-f0-9]{64}$/);
    assert.ok(Number.isSafeInteger(entry.size)&&entry.size>0);
  }
  assert.equal(source.behavior.ascension,0);assert.equal(source.behavior.curseChancePercent,50);
  assert.equal(source.behavior.curseId,'Writhe');
  assert.deepEqual(source.behavior.introChoices,['open','leave']);
  assert.deepEqual(source.behavior.sourceOrder,['miscBoolean','prepareWritheOldOmamoriIfCursed',
    'selectScreenlessRelic','equipRelic','resolveWritheAgainstNewRelicsIfCursed','resultScreen','separateLeave']);
  assert.deepEqual(source.behavior.screenlessRejects,['Bottled Flame','Bottled Lightning','Bottled Tornado','Whetstone']);
  assert.match(source.provenanceBoundary,/not official source or a PC-binary certification/);
  assert.match(source.implementationBoundary,/Darkstone Periapt/);assert.match(source.implementationBoundary,/NOT_RUN/);
  assert.match(source.implementationBoundary,/NodeUI wired with mocked-local/);
  assert.match(source.implementationBoundary,/history producer\/persistence remains UNWIRED/);
});

test('Mausoleum public Nodes commands retain RNG, permanent hook, rollback and pool boundaries',()=>{
  const result=runLua('tests/lua/mausoleum_event_content.lua');
  assert.equal(result.status,0,result.stderr||result.stdout);
  assert.match(result.stdout,/MAUSOLEUM_EVENT_CONTENT 18 passed/);
});
