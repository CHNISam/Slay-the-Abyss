import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runLua} from '../scripts/test-lua.mjs';
const source=JSON.parse(readFileSync('tests/fixtures/act2-event-relics-source-contract.json','utf8'));
test('five direct Act2 relic dependencies pin genuine hooks, special curse, full RNG pools and shared end-turn order',()=>{
 assert.equal(source.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');assert.equal(source.sources.length,15);
 for(const row of source.sources){assert.match(row.gitBlobSha,/^[a-f0-9]{40}$/);assert.match(row.sha256,/^[a-f0-9]{64}$/);assert.ok(row.size>0);assert.ok(row.url.includes(`/blob/${source.sourceCommit}/`));}
 assert.match(source.contracts.MutagenicStrength,/BEFORE strength/);assert.match(source.contracts.Necronomicurse,/WITHOUT obtain hooks/);
 assert.match(source.contracts.NilrysCodex,/no retrieval redraw/);assert.match(source.contracts.sharedEndTurn,/pause\/resume remainder/);
 assert.match(source.boundaries,/not natural acquisition or native/);
});
for(const [suffix,count]of [['acquisition',8],['opening',5],['necronomicon',7],['codex',9],['bloody',7],['codex_ui',2]]){
 test(`Act2 real relics ${suffix}: real command boundaries and source timing`,()=>{
  const result=runLua(`tests/lua/act2_event_relic_${suffix}.lua`);
  assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,new RegExp(`ACT2_EVENT_RELIC_${suffix.toUpperCase()} ${count} passed`));
 });
}
