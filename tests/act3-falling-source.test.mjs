import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const lock=JSON.parse(readFileSync('tests/fixtures/act3-falling-source.json','utf8'));
const manifest=JSON.parse(readFileSync('data/release/launch-content.json','utf8'));
test('Falling locks the audited raw ZIP members and independent typed-RNG oracle',()=>{
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.deepEqual(Object.fromEntries(Object.entries(lock.files).map(([name,row])=>[name,row.sha256])),{
  'events/beyond/Falling.java':'ae6ed951929324894a0bba6de04d0360337db3b47bd73f2b678ec06e1def2d56',
  'helpers/CardHelper.java':'a3ded368496bb998dc80fc5c9d6ca6bf10a958aad679644786fb325ecc5ce4fc',
  'cards/CardGroup.java':'03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8',
  'random/Random.java':'476be7d8af2080b6b52f6cecc78c35f01904c18dbacc7ea795a361e600f05172',
  'dungeons/TheBeyond.java':'dbc559c7a80e98197f0d9d61e76cffa737dab9a9f21981bc535671523152d46b'});
 for(const [name,row]of Object.entries(lock.files))assert.equal(row.member,`sts-${lock.sourceCommit}/${name}`);
 assert.deepEqual(lock.contracts.sampleOrder,['attack','skill','power']);
 assert.deepEqual(lock.contracts.displayOrder,['skill','power','attack']);
 assert.equal(lock.contracts.singleCategoryAutoSelect,false);assert.equal(lock.contracts.escapeOnlyWhenNoCandidates,true);
 assert.deepEqual(lock.oracle,{roomSeed:'77',bounds:[2,2,2],indices:[0,1,1],uids:[101,202,302],words:['58ecdcb139ff8c6b','4654e3216996cb9f'],counter:3});
});
test('Falling release mapping records the limited campaign evidence and all three dedicated boundaries',()=>{
 const event=manifest.events.find(row=>row.originalId==='Falling');assert.equal(event.id,'falling');assert.equal(event.act,3);
 assert.equal(event.source,'src/lua/abyss_act3_events.lua');assert.equal(event.poolMode,'explicit-only');
 assert.deepEqual(event.channels,['explicit:Nodes.enter']);assert.match(event.naturalAcquisitionLimitation,/Act 3 development campaign seed8/);
 const p=manifest.profiles[event.profile];assert.deepEqual(p.local.testFiles.filter(f=>f.endsWith('.lua')),['tests/lua/act3_falling_event.lua','tests/lua/act3_falling_ui.lua','tests/lua/act3_falling_natural.lua']);
 assert.equal(p.platform.evidence.length,0);assert.equal(p.live.evidence.length,0);
});
