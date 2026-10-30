import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runLua } from '../scripts/test-lua.mjs';
const contract=JSON.parse(readFileSync('tests/fixtures/vampires-source-contract.json','utf8'));
test('Vampires records exact independently inspected source identities',()=>{
 assert.equal(contract.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(contract.sources.find(s=>s.path==='events/city/Vampires.java').gitBlobSha,'93701f68f89eb014c0331c25f5c966c847dc37ff');
 assert.equal(contract.sources.find(s=>s.path==='relics/BloodVial.java').gitBlobSha,'48dfb0b6941453061f940a93bd97040a27788c9c');
 for(const source of contract.sources){assert.match(source.gitBlobSha,/^[a-f0-9]{40}$/);assert.ok(source.url.endsWith(`/${contract.sourceCommit}/${source.path}`));}
});
for(const [file,marker] of [['vampires_event.lua','VAMPIRES_EVENT 11 passed'],['vampires_event_ui.lua','ACT2_EVENT_UI_PASS 5']]){
 test(`Vampires real command/native-control behavior: ${file}`,()=>{
  const result=runLua(`tests/lua/${file}`);assert.equal(result.status,0,result.stdout+result.stderr);assert.ok(result.stdout.includes(marker));
 });
}
