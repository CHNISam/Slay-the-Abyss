import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runLua} from '../scripts/test-lua.mjs';
test('three event ports retain fixed original source identities',()=>{
 const lock=JSON.parse(readFileSync('tests/fixtures/m3-relic-choice-events-source-lock.json','utf8'));
 assert.equal(lock.sourceRepository,'aeubanks/sts');
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.deepEqual(lock.sources.map(s=>[s.path,s.gitBlobSha]),[
  ['events/shrines/Designer.java','c032e8026abd9a75f69d7dee52f0a705cf165805'],
  ['events/city/KnowingSkull.java','1b182b2f7bc5c9839a42f58e19969c045b7fa1ed'],
  ['events/shrines/Nloth.java','face63ecc18f19a118d172b50db886ff177508c2'],
  ['relics/NlothsGift.java','544ae415be6e8fe10243406c4dca8dcaa31bbf53'],
 ]);
 for(const s of lock.sources){assert.match(s.sha256,/^[a-f0-9]{64}$/);assert.equal(s.url,`https://github.com/aeubanks/sts/blob/${lock.sourceCommit}/${s.path}`);}
});
test('Designer, Skull and Nloth source commands and all130 current relic sacrifices',()=>{
 const r=runLua('tests/lua/m3_relic_choice_events.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/M3_RELIC_CHOICE_EVENTS 18 passed/);
});
