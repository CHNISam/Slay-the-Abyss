import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runLua } from '../scripts/test-lua.mjs';
const source=JSON.parse(readFileSync('tests/fixtures/ghosts-source-contract.json','utf8'));
test('Ghosts source locks cached A0 cost, mutation order, five fresh Ghostly obtains and separate Leave',()=>{
 assert.equal(source.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(source.sources.find(s=>s.path==='events/city/Ghosts.java').gitBlobSha,'b5ec62ff7a5fa6b72223ee7036b2df606cbcb186');
 assert.equal(source.sources.find(s=>s.path==='cards/colorless/Apparition.java').gitBlobSha,'9f01ad7014d6c702b0d1245cefc73c2c67bb8cd6');
 for(const row of source.sources){assert.match(row.gitBlobSha,/^[a-f0-9]{40}$/);assert.match(row.sha256,/^[a-f0-9]{64}$/);assert.ok(row.url.includes(`/blob/${source.sourceCommit}/`));}
 assert.equal(source.behavior.count,5);assert.equal(source.behavior.cardSourceId,'Ghostly');assert.equal(source.behavior.cardId,'apparition');
 assert.deepEqual(source.behavior.order,['decreaseCurrentMaxHpByCachedLoss','fiveFreshPermanentObtains','result','separateLeave']);
 assert.deepEqual(source.behavior.cache80_thenFruitJuice5,{cachedLoss:40,currentMaxHp:85,resultMaxHp:45});
 assert.equal(source.behavior.seededActionRngDraws,0);assert.match(source.boundaries,/Toxic Egg/);assert.match(source.boundaries,/Native acceptance NOT_RUN/);
});
for(const [file,marker,count]of [['ghosts_event.lua','GHOSTS_EVENT',12],['ghosts_event_ui.lua','GHOSTS_EVENT_UI',8]]){
 test(`Ghosts public commands and generated NodeUI: ${file}`,()=>{
  const result=runLua(`tests/lua/${file}`);assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,new RegExp(`${marker} ${count} passed`));
 });
}
