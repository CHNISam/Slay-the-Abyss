import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runLua } from '../scripts/test-lua.mjs';
const source=JSON.parse(readFileSync('tests/fixtures/back-to-basics-source-contract.json','utf8'));
test('BackToBasics source fixes eight starter tags, free purge, four-argument grid, empty success and separate Leave',()=>{
 assert.equal(source.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');assert.equal(source.sources.length,16);
 const event=source.sources.find(s=>s.path==='events/city/BackToBasics.java');
 assert.equal(event.gitBlobSha,'cbbf9f5782b73485ba90911a32d6c55126f653b6');assert.equal(event.sha256,'dc72fc035a26934da7882a8c533edc6930f17ee458315ff64459115e8ca5eb42');
 for(const s of source.sources){assert.match(s.gitBlobSha,/^[a-f0-9]{40}$/);assert.match(s.sha256,/^[a-f0-9]{64}$/);assert.ok(s.size>0);assert.ok(s.url.includes(`/blob/${source.sourceCommit}/`));}
 assert.equal(source.behavior.goldCost,0);assert.deepEqual(source.behavior.introChoices,['elegance','simplicity']);
 assert.deepEqual(source.behavior.purge,{count:1,forUpgrade:false,forTransform:false,canCancel:true,forPurge:false,anyNumber:false});
 assert.deepEqual(source.behavior.simplicitySourceIds,['Strike_R','Defend_R','Strike_G','Defend_G','Strike_B','Defend_B','Strike_P','Defend_P']);
 assert.deepEqual(source.behavior.outcomes,['resultScreen','separateLeave','openMap']);
 assert.match(source.implementationBoundary,/not a source class restriction/);assert.match(source.implementationBoundary,/Elegance remains supported/);assert.match(source.implementationBoundary,/Native acceptance NOT_RUN/);
});
for(const [file,marker,count]of [['back_to_basics_event.lua','BACK_TO_BASICS_EVENT',17],['back_to_basics_ui.lua','BACK_TO_BASICS_UI',9]]){
 test(`BackToBasics source-faithful public commands and generated NodeUI: ${file}`,()=>{
  const result=runLua(`tests/fixtures/js-owned/tests/lua/${file}`);assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,new RegExp(`${marker} ${count} passed`));
 });
}
