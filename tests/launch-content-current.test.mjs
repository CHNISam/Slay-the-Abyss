import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validateLaunchContent} from '../scripts/verify-launch-content.mjs';

test('current launch ledger validates all production relics and Calling Bell curse without historical projection',()=>{
 const manifest=JSON.parse(readFileSync('data/release/launch-content.json','utf8'));
 const definitions=JSON.parse(readFileSync('data/relics.json','utf8')).relics;
 assert.equal(definitions.length,142);
 assert.deepEqual(manifest.relics.map(row=>row.id).sort(),definitions.map(row=>row.id).sort());
 assert.equal(manifest.generatedCards.find(row=>row.id==='curse_of_the_bell').sourceId,'CurseOfTheBell');
 assert.deepEqual(validateLaunchContent(manifest,{root:process.cwd()}),[]);
});

test('Calling Bell ledger rejects ordinary transformation channels, wrong identity and removability',()=>{
 for(const mutate of [
  row=>{row.channels=['explicit_event:transmogrifier:change','explicit:Run.obtainCard'];},
  row=>{row.channels=['explicit_event:living_wall:change','explicit:Run.obtainCard'];},
  row=>{row.sourceId='Regret';},
  row=>{row.unremovable=false;},
 ]){
  const manifest=JSON.parse(readFileSync('data/release/launch-content.json','utf8'));
  mutate(manifest.generatedCards.find(row=>row.id==='curse_of_the_bell'));
  assert.ok(validateLaunchContent(manifest,{runtime:false}).some(error=>error.includes('generatedCards/curse_of_the_bell')));
 }
});
