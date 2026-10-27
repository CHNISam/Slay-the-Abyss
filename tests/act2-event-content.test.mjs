import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { toLua } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';

const source=JSON.parse(readFileSync('tests/fixtures/beggar-source-contract.json','utf8'));
test('Beggar contract is pinned to the exact primary source and mandatory seven-argument purge overload',()=>{
  assert.equal(source.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
  assert.deepEqual(source.sources.map(s=>s.path),['events/city/Beggar.java','screens/select/GridCardSelectScreen.java']);
  for(const entry of source.sources){
    assert.match(entry.url,new RegExp(`/blob/${source.sourceCommit}/`));
    assert.match(entry.normalizedRetrievedTextSha256,/^[a-f0-9]{64}$/);
  }
  assert.equal(source.behavior.goldCost,75);
  assert.deepEqual(source.behavior.introChoices,['donate','leave']);
  assert.deepEqual(source.behavior.purge,{count:1,forUpgrade:false,forTransform:false,canCancel:false,forPurge:true,anyNumber:false});
  assert.match(source.behavior.emptyGroupBoundary,/UNPROVEN/);
  assert.match(source.provenanceBoundary,/not canonical byte attestations/);
  assert.match(source.implementationBoundary,/NodeUI wired with mocked-local/);
  assert.match(source.implementationBoundary,/Empty purge-group.*UNPROVEN and pending/);
  assert.match(source.implementationBoundary,/Native-client acceptance NOT_RUN/);
  assert.match(source.implementationBoundary,/history producer\/persistence.*pending/);
});

test('Beggar actual Nodes commands preserve source stages, mandatory choice, paid-state rollback and full-pool gates',()=>{
  const dir=mkdtempSync(join(tmpdir(),'abyss-beggar-'));
  try{
    const path=join(dir,'source-contract.lua');
    writeFileSync(path,`BEGGAR_SOURCE_CONTRACT=${toLua(source.behavior)}\ndofile('tests/lua/act2_event_content.lua')\n`);
    const result=runLua(path);
    assert.equal(result.status,0,result.stderr||result.stdout);
    assert.match(result.stdout,/ACT2_EVENT_CONTENT 15 passed/);
  }finally{rmSync(dir,{recursive:true,force:true});}
});
